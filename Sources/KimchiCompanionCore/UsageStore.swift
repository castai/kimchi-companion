import Foundation
import Observation

/// Orchestrates the fetch → cache → display → stale pipeline for CAST AI usage data.
///
/// Owns the full lifecycle: concurrent API calls to both endpoints, merging responses
/// into `CachedUsageData`, writing to disk cache, and tracking staleness when the API
/// is unreachable. Lives inside `AppState` — not as a separate environment object.
///
/// ## Observability
///
/// - Debug prints use the `[UsageStore]` prefix.
/// - `lastError` holds the last fetch error description.
/// - `lastUpdated` shows when data was last successfully refreshed.
/// - `isStale` drives the UI stale indicator.
/// - Cache file at `~/Library/Application Support/KimchiCompanion/usage-cache.json`.
/// - **The API key is never logged.**
@Observable
@MainActor
public final class UsageStore {

    // MARK: - Published State

    /// The current merged data from both endpoints (may be from disk cache).
    public var cachedData: CachedUsageData?

    /// True during an active fetch.
    public var isLoading: Bool = false

    /// True when the last refresh failed and we're showing cached data.
    public var isStale: Bool = false

    /// Timestamp of last successful fetch.
    public var lastUpdated: Date?

    /// Description of last fetch error (diagnostics only, not shown to users).
    public var lastError: String?

    // MARK: - Computed Properties (for S04 UI)

    public var todayCost: Decimal { cachedData?.todayCostDecimal ?? .zero }
    public var weekCost: Decimal { cachedData?.weekCostDecimal ?? .zero }

    public var todayTokensIn: Int { cachedData?.todayTokensIn ?? 0 }
    public var todayTokensOut: Int { cachedData?.todayTokensOut ?? 0 }
    public var todayRequests: Int { cachedData?.todayRequests ?? 0 }

    public var weekTokensIn: Int { cachedData?.weekTokensIn ?? 0 }
    public var weekTokensOut: Int { cachedData?.weekTokensOut ?? 0 }
    public var weekRequests: Int { cachedData?.weekRequests ?? 0 }

    public var modelBreakdown: [(name: String, cost: Decimal)] {
        (cachedData?.modelBreakdown ?? []).map { ($0.name, $0.costDecimal) }
    }

    /// Formatted today cost for menu bar display (e.g., "$4.20").
    public var formattedTodayCost: String {
        let cost = todayCost
        let number = NSDecimalNumber(decimal: cost)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: number) ?? "$0.00"
    }

    // MARK: - Cache File Path

    private static var cacheDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("KimchiCompanion")
    }

    private static var cacheFileURL: URL {
        cacheDirectoryURL.appendingPathComponent("usage-cache.json")
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Background Polling

    /// Active polling task. Cancel before starting a new one or on shutdown.
    private var pollingTask: Task<Void, Never>?

    /// Start background polling that refreshes usage data at the given interval.
    /// Cancels any existing polling task before starting a new one.
    ///
    /// - Parameters:
    ///   - intervalSeconds: Seconds between refresh cycles.
    ///   - apiKey: CAST AI API key. Never logged.
    public func startPolling(intervalSeconds: Int, apiKey: String) {
        stopPolling()

        #if DEBUG
        print("[UsageStore] polling started interval=\(intervalSeconds)s")
        #endif

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(intervalSeconds))
                } catch {
                    // CancellationError — exit cleanly
                    #if DEBUG
                    print("[UsageStore] polling cancelled during sleep")
                    #endif
                    return
                }

                guard let self, !Task.isCancelled else { return }

                #if DEBUG
                print("[UsageStore] poll tick — refreshing")
                #endif

                await self.refresh(apiKey: apiKey)
            }
        }
    }

    /// Stop the current polling task.
    public func stopPolling() {
        guard pollingTask != nil else { return }
        pollingTask?.cancel()
        pollingTask = nil
        #if DEBUG
        print("[UsageStore] polling stopped")
        #endif
    }

    // MARK: - Refresh

    /// Main fetch orchestrator: calls all API endpoints concurrently, merges results,
    /// writes cache to disk, and updates state. On failure, sets stale and preserves
    /// existing cached data.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - organizationId: If set, use org-scoped analytics endpoint; otherwise user-scoped.
    ///   - isUserScoped: When true, scope org-scoped data to the authenticated user.
    public func refresh(apiKey: String, organizationId: String? = nil, isUserScoped: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        print("[UsageStore] fetch start")
        #endif

        let now = Date()
        let calendar = Calendar(identifier: .iso8601)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // "Today" = start of current UTC day to now
        let todayStart = utcCalendar.startOfDay(for: now)

        // "This week" = start of Monday (ISO 8601 week) to now
        let weekComponents = utcCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekStart = utcCalendar.date(from: weekComponents) ?? todayStart

        // Primary: analytics API with user scoping (matches harness behavior).
        // Falls back to deprecated endpoints if analytics fails.
        var analyticsResponse: AnalyticsResponse?
        var todayUsageReport: UsageReportResponse?
        var weekUsageReport: UsageReportResponse?
        var savingsReport: SavingsReportResponse?
        var recommendationsReport: RecommendationsReportResponse?
        var fetchError: Error?

        var orgAnalyticsResponse: GenerateAnalyticsResponse?

        do {
            if let orgId = organizationId {
                // Org-scoped analytics endpoint
                orgAnalyticsResponse = try await CastAPIClient.fetchOrganizationAnalytics(
                    apiKey: apiKey, orgId: orgId, startTime: weekStart, endTime: now,
                    isUserScoped: isUserScoped
                )
                #if DEBUG
                print("[UsageStore] org-scoped analytics API succeeded — orgId=\(orgId.prefix(8))…, isUserScoped=\(isUserScoped)")
                #endif
            } else {
                // User-scoped analytics API
                analyticsResponse = try await CastAPIClient.fetchAnalytics(
                    apiKey: apiKey, startTime: weekStart, endTime: now
                )
                #if DEBUG
                print("[UsageStore] analytics API succeeded — user-scoped data")
                #endif
            }
        } catch {
            fetchError = error
            #if DEBUG
            print("[UsageStore] analytics API failed, falling back to deprecated endpoints: \(error.localizedDescription)")
            #endif

            // Fallback: fetch deprecated endpoints concurrently
            do {
                async let todayTask = CastAPIClient.fetchUsageReport(
                    apiKey: apiKey, from: todayStart, to: now
                )
                async let weekTask = CastAPIClient.fetchUsageReport(
                    apiKey: apiKey, from: weekStart, to: now
                )
                async let savingsTask = CastAPIClient.fetchSavingsReport(
                    apiKey: apiKey, from: weekStart, to: now
                )
                async let recsTask = CastAPIClient.fetchRecommendationsReport(
                    apiKey: apiKey, from: weekStart, to: now
                )

                var localError: Error?
                do { todayUsageReport = try await todayTask } catch { localError = error }
                do { weekUsageReport = try await weekTask } catch { localError = error }
                do { savingsReport = try await savingsTask } catch { localError = error }
                do { recommendationsReport = try await recsTask } catch { /* non-critical */ }
                fetchError = localError
            }
        }

        // If analytics succeeded, we have data. Otherwise check fallback.
        let hasData = analyticsResponse != nil || todayUsageReport != nil || weekUsageReport != nil
        if !hasData {
            isStale = true
            lastError = fetchError?.localizedDescription ?? "All API calls failed"
            #if DEBUG
            print("[UsageStore] fetch failure — all endpoints failed, isStale=true")
            #endif
            return
        }

        // Fetch per-key usage for token counts.
        // Extract key IDs from the week usage report's costPerApiKey field.
        var perKeyUsage: [String: APIKeyUsageReportResponse] = [:]
        if let items = weekUsageReport?.items {
            var allKeyIds: Set<String> = []
            for item in items {
                for keyId in (item.costPerApiKey ?? [:]).keys {
                    allKeyIds.insert(keyId)
                }
            }

            // Fetch each key's usage concurrently (limit to 10 to avoid flooding)
            let keyIds = Array(allKeyIds.prefix(10))
            await withTaskGroup(of: (String, APIKeyUsageReportResponse?).self) { group in
                for keyId in keyIds {
                    group.addTask {
                        do {
                            let report = try await CastAPIClient.fetchAPIKeyUsage(
                                apiKey: apiKey, apiKeyId: keyId, from: weekStart, to: now
                            )
                            return (keyId, report)
                        } catch {
                            #if DEBUG
                            print("[UsageStore] per-key usage fetch failed for \(keyId.prefix(8))…: \(error.localizedDescription)")
                            #endif
                            return (keyId, nil)
                        }
                    }
                }
                for await (keyId, report) in group {
                    if let report { perKeyUsage[keyId] = report }
                }
            }

            #if DEBUG
            print("[UsageStore] fetched per-key usage for \(perKeyUsage.count)/\(keyIds.count) keys")
            #endif
        }

        // Merge responses into CachedUsageData
        let data = mergeResponses(
            analytics: analyticsResponse,
            orgAnalytics: orgAnalyticsResponse,
            todayUsage: todayUsageReport,
            weekUsage: weekUsageReport,
            savings: savingsReport,
            recommendations: recommendationsReport,
            perKeyUsage: perKeyUsage,
            now: now
        )

        // Write cache to disk
        saveCacheToDisk(data)

        // Update state
        cachedData = data
        lastUpdated = data.lastUpdated
        isStale = false
        lastError = nil

        #if DEBUG
        print("[UsageStore] fetch success — todayCost=\(data.todayCost), weekCost=\(data.weekCost), categories=\(data.categoryBreakdown.count), savings=\(data.savingsSummary != nil)")
        #endif
    }

    // MARK: - Cache I/O

    /// Load cached data from disk. Called on init before any network call.
    public func loadCachedData() {
        let url = Self.cacheFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            #if DEBUG
            print("[UsageStore] cache read — no cache file found")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cached = try decoder.decode(CachedUsageData.self, from: data)
            cachedData = cached
            lastUpdated = cached.lastUpdated
            // Mark stale since it's from disk, not fresh
            isStale = true
            #if DEBUG
            print("[UsageStore] cache read — loaded, lastUpdated=\(cached.lastUpdated), todayCost=\(cached.todayCost)")
            #endif
        } catch {
            #if DEBUG
            print("[UsageStore] cache read — decode failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Write cached data atomically to disk. Creates the directory if needed.
    private func saveCacheToDisk(_ cached: CachedUsageData) {
        let directoryURL = Self.cacheDirectoryURL
        let fileURL = Self.cacheFileURL

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(cached)

            try data.write(to: fileURL, options: .atomic)

            #if DEBUG
            print("[UsageStore] cache write — \(data.count) bytes to \(fileURL.path)")
            #endif
        } catch {
            #if DEBUG
            print("[UsageStore] cache write — failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Response Merging

    /// Merge analytics and/or deprecated API responses into cached structure.
    ///
    /// Priority: orgAnalytics (org-scoped) > analytics (user-scoped) > deprecated endpoints.
    /// KPI fields are populated from orgAnalytics when available, otherwise defaults.
    private func mergeResponses(
        analytics: AnalyticsResponse?,
        orgAnalytics: GenerateAnalyticsResponse?,
        todayUsage: UsageReportResponse?,
        weekUsage: UsageReportResponse?,
        savings: SavingsReportResponse?,
        recommendations: RecommendationsReportResponse?,
        perKeyUsage: [String: APIKeyUsageReportResponse],
        now: Date
    ) -> CachedUsageData {
        // ── Costs, model breakdown, key breakdown ─────────────────────────────────
        var todayCostDecimal: Decimal = .zero
        var weekCostDecimal: Decimal = .zero
        var modelBreakdown: [ModelCostEntry] = []
        var keyBreakdown: [APIKeyUsageEntry] = []
        var weekTokensIn = 0
        var weekTokensOut = 0
        var weekRequests = 0

        if let analytics = analytics {
            // Primary path: use analytics API data (user-scoped via inferUserFromApiKey).
            weekCostDecimal = analytics.totalCost
            todayCostDecimal = analytics.totalCost

            let allModels = analytics.cost?.items.first?.models ?? []
            modelBreakdown = allModels.map {
                ModelCostEntry(name: $0.model, cost: $0.totalCost)
            }.sorted { $0.costDecimal > $1.costDecimal }

            // Per-key breakdown from castaiApiKeyMetadata.
            var keyTotals: [String: (cost: Decimal, displayName: String)] = [:]
            for model in allModels {
                let keyId = model.castaiApiKey
                let displayName = model.castaiApiKeyMetadata?.name
                    ?? model.castaiApiKeyMetadata?.ownerEmail
                    ?? keyId
                let modelCost = Decimal(string: model.totalCost) ?? .zero
                if let existing = keyTotals[keyId] {
                    keyTotals[keyId] = (existing.cost + modelCost, displayName)
                } else {
                    keyTotals[keyId] = (modelCost, displayName)
                }
            }
            keyBreakdown = keyTotals.map {
                APIKeyUsageEntry(id: $0.key, displayName: $0.value.displayName,
                                 cost: "\($0.value.cost)", tokensIn: 0, tokensOut: 0, requests: 0)
            }.sorted { $0.costDecimal > $1.costDecimal }

            weekTokensIn = analytics.totalInputTokens
            weekTokensOut = analytics.totalOutputTokens
        } else {
            // Fallback: deprecated endpoints (no user scoping).
            todayCostDecimal = todayUsage?.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal } ?? .zero
            weekCostDecimal = weekUsage?.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal } ?? .zero

            if !perKeyUsage.isEmpty {
                for (_, report) in perKeyUsage {
                    for item in report.items {
                        weekTokensIn += item.tokenCount?.in ?? 0
                        weekTokensOut += item.tokenCount?.out ?? 0
                        weekRequests += item.requestCount ?? 0
                    }
                }
            } else if let savingsItems = savings?.items, !savingsItems.isEmpty {
                weekTokensIn = savingsItems.reduce(0) { $0 + $1.tokenCount.in }
                weekTokensOut = savingsItems.reduce(0) { $0 + $1.tokenCount.out }
                weekRequests = savingsItems.reduce(0) { $0 + $1.requestCount }
            }

            // Model breakdown from deprecated endpoints.
            if let categories = todayUsage?.items.first?.costPerCategory {
                modelBreakdown = categories.map { ModelCostEntry(name: $0.key, cost: $0.value) }
                    .sorted { $0.costDecimal > $1.costDecimal }
            } else if let items = savings?.items, !items.isEmpty {
                modelBreakdown = items.map {
                    ModelCostEntry(name: $0.alias ?? $0.id, cost: $0.costs.total)
                }.sorted { $0.costDecimal > $1.costDecimal }
            }

            // Key breakdown from deprecated endpoints.
            if !perKeyUsage.isEmpty {
                let aliasMap: [String: String] = Dictionary(
                    uniqueKeysWithValues: (savings?.items ?? []).map { ($0.id, $0.alias ?? $0.id) }
                )
                for (keyId, report) in perKeyUsage {
                    let totalCost = report.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal }
                    let totalTokensIn = report.items.reduce(0) { $0 + ($1.tokenCount?.in ?? 0) }
                    let totalTokensOut = report.items.reduce(0) { $0 + ($1.tokenCount?.out ?? 0) }
                    let totalRequests = report.items.reduce(0) { $0 + ($1.requestCount ?? 0) }
                    let displayName = aliasMap[keyId] ?? String(keyId.prefix(12))
                    keyBreakdown.append(APIKeyUsageEntry(
                        id: keyId, displayName: displayName,
                        cost: "\(totalCost)",
                        tokensIn: totalTokensIn, tokensOut: totalTokensOut, requests: totalRequests
                    ))
                }
                keyBreakdown.sort { $0.costDecimal > $1.costDecimal }
            } else if let items = savings?.items, !items.isEmpty {
                keyBreakdown = items.map { item in
                    APIKeyUsageEntry(
                        id: item.id,
                        displayName: item.alias ?? String(item.id.prefix(12)),
                        cost: item.costs.total,
                        tokensIn: item.tokenCount.in, tokensOut: item.tokenCount.out,
                        requests: item.requestCount
                    )
                }.sorted { $0.costDecimal > $1.costDecimal }
            }
        }

        // ── Today's tokens (from per-key reports, filtered to today) ────────────
        var todayTokensIn = 0
        var todayTokensOut = 0
        var todayRequests = 0

        if !perKeyUsage.isEmpty {
            let todayPrefix = Self.todayDatePrefix(now)
            for (_, report) in perKeyUsage {
                for item in report.items {
                    if item.timestamp.hasPrefix(todayPrefix) {
                        todayTokensIn += item.tokenCount?.in ?? 0
                        todayTokensOut += item.tokenCount?.out ?? 0
                        todayRequests += item.requestCount ?? 0
                    }
                }
            }
        } else {
            todayTokensIn = weekTokensIn
            todayTokensOut = weekTokensOut
            todayRequests = weekRequests
        }

        // ── Category breakdown (deprecated endpoints only) ───────────────────────
        var categoryBreakdown: [CategoryCostEntry] = []
        if let items = weekUsage?.items {
            var totals: [String: Decimal] = [:]
            for item in items {
                for (cat, costStr) in (item.costPerCategory ?? [:]) {
                    totals[cat, default: .zero] += Decimal(string: costStr) ?? .zero
                }
            }
            categoryBreakdown = totals.map { CategoryCostEntry(name: $0.key, cost: "\($0.value)") }
                .sorted { $0.costDecimal > $1.costDecimal }
        }

        // ── Savings summary ──────────────────────────────────────────────────────
        var savingsSummary: CachedSavingsSummary?
        if let summary = recommendations?.summary {
            let actualCost = summary.costs?.total ?? "0"
            let originalCost = summary.originalCost ?? "0"
            let achievedSavings = summary.achievedSavings ?? "0"
            let achievedPct = summary.achievedSavingsPercentage ?? "0"
            let recommendedCost = summary.recommendedModelCosts?.total ?? actualCost
            let actualDec = Decimal(string: actualCost) ?? .zero
            let recommendedDec = Decimal(string: recommendedCost) ?? .zero
            let potentialSavings = max(.zero, actualDec - recommendedDec)

            savingsSummary = CachedSavingsSummary(
                actualCost: actualCost, originalCost: originalCost,
                achievedSavings: achievedSavings, achievedSavingsPercentage: achievedPct,
                recommendedCost: recommendedCost, potentialSavings: "\(potentialSavings)"
            )
        }

        // ── KPI extraction from org-scoped analytics ─────────────────────────────
        let kpis: (totalRequests: Int, totalTokens: Int, activeModels: Int,
                   requestsTrend: Double?, costTrend: Double?, tokensTrend: Double?)
        if let org = orgAnalytics {
            kpis = extractKPIs(from: org)
        } else {
            kpis = (totalRequests: 0, totalTokens: 0, activeModels: 0,
                    requestsTrend: nil, costTrend: nil, tokensTrend: nil)
        }

        // ── Token chart + top models (from org-scoped analytics) ───────────────
        let tokenChartData: [TokenChartPoint]
        let topModels: [TopModelRow]
        if let org = orgAnalytics {
            tokenChartData = computeTokenChartData(from: org)
            topModels = computeTopModels(from: org)
        } else {
            tokenChartData = []
            topModels = []
        }

        return CachedUsageData(
            todayCost: "\(todayCostDecimal)", weekCost: "\(weekCostDecimal)",
            todayTokensIn: todayTokensIn, todayTokensOut: todayTokensOut, todayRequests: todayRequests,
            weekTokensIn: weekTokensIn, weekTokensOut: weekTokensOut, weekRequests: weekRequests,
            modelBreakdown: modelBreakdown, keyBreakdown: keyBreakdown,
            categoryBreakdown: categoryBreakdown, savingsSummary: savingsSummary,
            totalRequests: kpis.totalRequests,
            totalTokens: kpis.totalTokens,
            activeModels: kpis.activeModels,
            requestsTrend: kpis.requestsTrend,
            costTrend: kpis.costTrend,
            tokensTrend: kpis.tokensTrend,
            tokenChartData: tokenChartData,
            topModels: topModels,
            lastUpdated: now
        )
    }

    // MARK: - Helpers

    /// Returns the UTC date prefix (e.g. "2026-03-20") for filtering today's items.
    private static func todayDatePrefix(_ now: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: now)
    }

    /// Extract KPI tuple from a `GenerateAnalyticsResponse`.
    ///
    /// - Requests: sum of all `apiCalls.items[].models[].totalCount`
    /// - Tokens: sum of `inputTokens` + `outputTokens` items
    /// - Active models: count of unique model names across apiCalls
    /// - Trends: `comparison.{apiCalls,cost,tokens}.changePercentage`
    private func extractKPIs(from response: GenerateAnalyticsResponse) -> (
        totalRequests: Int,
        totalTokens: Int,
        activeModels: Int,
        requestsTrend: Double?,
        costTrend: Double?,
        tokensTrend: Double?
    ) {
        // Requests: sum of all model totalCount in apiCalls
        var totalRequests = 0
        var allModelNames = Set<String>()
        if let apiCalls = response.apiCalls {
            for item in apiCalls.items {
                for model in item.models {
                    totalRequests += model.totalCount
                    allModelNames.insert(model.model)
                }
            }
        }

        // Tokens: sum of inputTokens + outputTokens
        var totalInputTokens = 0
        var totalOutputTokens = 0
        if let inputTokens = response.inputTokens {
            for item in inputTokens.items {
                for model in item.models {
                    totalInputTokens += model.totalCount
                    allModelNames.insert(model.model)
                }
            }
        }
        if let outputTokens = response.outputTokens {
            for item in outputTokens.items {
                for model in item.models {
                    totalOutputTokens += model.totalCount
                    allModelNames.insert(model.model)
                }
            }
        }

        // Cost: sum of all totalCost strings (for trend only — cost is in weekCostDecimal)
        // Trends from comparison
        let requestsTrend = response.comparison?.apiCalls?.changePercentage
        let costTrend = response.comparison?.cost?.changePercentage
        let tokensTrend = response.comparison?.tokens?.changePercentage

        return (
            totalRequests: totalRequests,
            totalTokens: totalInputTokens + totalOutputTokens,
            activeModels: allModelNames.count,
            requestsTrend: requestsTrend,
            costTrend: costTrend,
            tokensTrend: tokensTrend
        )
    }

    // MARK: - Chart & Top Models Helpers

    /// Compute `TokenChartPoint` array from org-scoped analytics.
    /// Groups inputTokens + outputTokens by date and model, returns last 7 unique dates.
    private func computeTokenChartData(from response: GenerateAnalyticsResponse) -> [TokenChartPoint] {
        var dateModelTokens: [String: [String: Int]] = [:]
        let formatter = ISO8601DateFormatter()

        func processMetric(_ metric: AnalyticsMetric?, multiplier: Int) {
            guard let metric = metric else { return }
            for item in metric.items {
                let dateKey = item.executionTime
                if dateModelTokens[dateKey] == nil {
                    dateModelTokens[dateKey] = [:]
                }
                for modelCount in item.models {
                    dateModelTokens[dateKey]?[modelCount.model, default: 0] += modelCount.totalCount * multiplier
                }
            }
        }

        processMetric(response.inputTokens, multiplier: 1)
        processMetric(response.outputTokens, multiplier: 1)

        // Get last 7 unique dates sorted ascending
        let sortedDateKeys = dateModelTokens.keys.sorted()
        let cutoffIndex = max(0, sortedDateKeys.count - 7)
        let last7Keys = Array(sortedDateKeys[cutoffIndex...])

        var points: [TokenChartPoint] = []
        for dateKey in last7Keys {
            guard let parsedDate = formatter.date(from: dateKey),
                  let models = dateModelTokens[dateKey] else { continue }
            for (model, tokens) in models {
                points.append(TokenChartPoint(date: parsedDate, model: model, tokens: tokens))
            }
        }

        return points.sorted { ($0.date, $0.model) < ($1.date, $1.model) }
    }

    /// Compute `[TopModelRow]` from org-scoped analytics.
    /// Aggregates request counts and token counts per model, sorted descending by requestCount.
    private func computeTopModels(from response: GenerateAnalyticsResponse) -> [TopModelRow] {
        var requestCounts: [String: Int] = [:]
        var tokenCounts: [String: Int] = [:]

        if let apiCalls = response.apiCalls {
            for item in apiCalls.items {
                for modelCount in item.models {
                    requestCounts[modelCount.model, default: 0] += modelCount.totalCount
                }
            }
        }

        func sumTokens(from metric: AnalyticsMetric?) {
            guard let metric = metric else { return }
            for item in metric.items {
                for modelCount in item.models {
                    tokenCounts[modelCount.model, default: 0] += modelCount.totalCount
                }
            }
        }
        sumTokens(from: response.inputTokens)
        sumTokens(from: response.outputTokens)

        let totalRequests = requestCounts.values.reduce(0, +)
        guard totalRequests > 0 else { return [] }

        return requestCounts
            .map { model, count in
                TopModelRow(
                    name: model,
                    requestCount: count,
                    tokens: tokenCounts[model] ?? 0,
                    sharePct: Double(count) / Double(totalRequests) * 100.0
                )
            }
            .sorted { $0.requestCount > $1.requestCount }
    }
}
