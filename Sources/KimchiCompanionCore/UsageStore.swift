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
    /// - Parameter apiKey: CAST AI API key. Never logged.
    public func refresh(apiKey: String) async {
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

        // Fetch all endpoints concurrently
        // Usage report is called twice: once for today, once for the week
        var todayUsageReport: UsageReportResponse?
        var weekUsageReport: UsageReportResponse?
        var savingsReport: SavingsReportResponse?
        var recommendationsReport: RecommendationsReportResponse?
        var fetchError: Error?

        do {
            async let todayUsageTask = CastAPIClient.fetchUsageReport(
                apiKey: apiKey, from: todayStart, to: now
            )
            async let weekUsageTask = CastAPIClient.fetchUsageReport(
                apiKey: apiKey, from: weekStart, to: now
            )
            async let savingsTask = CastAPIClient.fetchSavingsReport(
                apiKey: apiKey, from: weekStart, to: now
            )
            async let recsTask = CastAPIClient.fetchRecommendationsReport(
                apiKey: apiKey, from: weekStart, to: now
            )

            do {
                todayUsageReport = try await todayUsageTask
            } catch {
                fetchError = error
                #if DEBUG
                print("[UsageStore] today usage report fetch failed: \(error.localizedDescription)")
                #endif
            }

            do {
                weekUsageReport = try await weekUsageTask
            } catch {
                fetchError = error
                #if DEBUG
                print("[UsageStore] week usage report fetch failed: \(error.localizedDescription)")
                #endif
            }

            do {
                savingsReport = try await savingsTask
            } catch {
                fetchError = error
                #if DEBUG
                print("[UsageStore] savings report fetch failed: \(error.localizedDescription)")
                #endif
            }

            do {
                recommendationsReport = try await recsTask
            } catch {
                // Recommendations is non-critical
                #if DEBUG
                print("[UsageStore] recommendations fetch failed: \(error.localizedDescription)")
                #endif
            }
        }

        // If both usage reports failed, mark stale and bail
        if todayUsageReport == nil && weekUsageReport == nil {
            isStale = true
            lastError = fetchError?.localizedDescription ?? "Usage API calls failed"
            #if DEBUG
            print("[UsageStore] fetch failure — usage endpoints failed, isStale=true")
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

    /// Merge today usage, week usage, savings, recommendations, and per-key data into cached structure.
    private func mergeResponses(
        todayUsage: UsageReportResponse?,
        weekUsage: UsageReportResponse?,
        savings: SavingsReportResponse?,
        recommendations: RecommendationsReportResponse?,
        perKeyUsage: [String: APIKeyUsageReportResponse],
        now: Date
    ) -> CachedUsageData {
        // Today's cost from today's usage report: sum of all items' daily costs
        let todayCostDecimal = todayUsage?.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal } ?? .zero

        // Week cost from week's usage report: sum of all items' daily costs
        let weekCostDecimal = weekUsage?.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal } ?? .zero

        // Token counts: aggregate from per-key usage reports (most accurate source)
        // Falls back to savings report if per-key data is empty
        var weekTokensIn = 0
        var weekTokensOut = 0
        var weekRequests = 0

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

        // Today's tokens: sum per-key usage items that fall on today only
        var todayTokensIn = 0
        var todayTokensOut = 0
        var todayRequests = 0

        let todayDatePrefix = Self.todayDatePrefix(now)
        if !perKeyUsage.isEmpty {
            for (_, report) in perKeyUsage {
                for item in report.items {
                    if item.timestamp.hasPrefix(todayDatePrefix) {
                        todayTokensIn += item.tokenCount?.in ?? 0
                        todayTokensOut += item.tokenCount?.out ?? 0
                        todayRequests += item.requestCount ?? 0
                    }
                }
            }
        } else {
            // Fallback: use week totals (same as before)
            todayTokensIn = weekTokensIn
            todayTokensOut = weekTokensOut
            todayRequests = weekRequests
        }

        // Model breakdown from today's usage report's per-category or per-key data
        var breakdown: [ModelCostEntry] = []
        if let categories = todayUsage?.items.first?.costPerCategory {
            breakdown = categories.map { ModelCostEntry(name: $0.key, cost: $0.value) }
                .sorted { ($0.costDecimal) > ($1.costDecimal) }
        } else if let items = savings?.items, !items.isEmpty {
            breakdown = items.map {
                ModelCostEntry(name: $0.alias ?? $0.id, cost: $0.costs.total)
            }.sorted { $0.costDecimal > $1.costDecimal }
        }

        // Per-API-key breakdown: prefer per-key usage data, fall back to savings report
        var keyBreakdown: [APIKeyUsageEntry] = []
        if !perKeyUsage.isEmpty {
            // Build from per-key usage + costPerApiKey for display names
            // Get key aliases from savings report if available
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
                    id: keyId,
                    displayName: displayName,
                    cost: "\(totalCost)",
                    tokensIn: totalTokensIn,
                    tokensOut: totalTokensOut,
                    requests: totalRequests
                ))
            }
            keyBreakdown.sort { $0.costDecimal > $1.costDecimal }
        } else if let items = savings?.items, !items.isEmpty {
            keyBreakdown = items.map { item in
                let displayName = item.alias ?? String(item.id.prefix(12))
                return APIKeyUsageEntry(
                    id: item.id,
                    displayName: displayName,
                    cost: item.costs.total,
                    tokensIn: item.tokenCount.in,
                    tokensOut: item.tokenCount.out,
                    requests: item.requestCount
                )
            }.sorted { $0.costDecimal > $1.costDecimal }
        }

        // Category breakdown from week's usage report (aggregated across all daily items)
        var categoryBreakdown: [CategoryCostEntry] = []
        if let items = weekUsage?.items {
            var categoryTotals: [String: Decimal] = [:]
            for item in items {
                for (category, costStr) in (item.costPerCategory ?? [:]) {
                    let cost = Decimal(string: costStr) ?? .zero
                    categoryTotals[category, default: .zero] += cost
                }
            }
            categoryBreakdown = categoryTotals.map { CategoryCostEntry(name: $0.key, cost: "\($0.value)") }
                .sorted { $0.costDecimal > $1.costDecimal }
        }

        // Savings summary from recommendations report
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
                actualCost: actualCost,
                originalCost: originalCost,
                achievedSavings: achievedSavings,
                achievedSavingsPercentage: achievedPct,
                recommendedCost: recommendedCost,
                potentialSavings: "\(potentialSavings)"
            )
        }

        return CachedUsageData(
            todayCost: "\(todayCostDecimal)",
            weekCost: "\(weekCostDecimal)",
            todayTokensIn: todayTokensIn,
            todayTokensOut: todayTokensOut,
            todayRequests: todayRequests,
            weekTokensIn: weekTokensIn,
            weekTokensOut: weekTokensOut,
            weekRequests: weekRequests,
            modelBreakdown: breakdown,
            keyBreakdown: keyBreakdown,
            categoryBreakdown: categoryBreakdown,
            savingsSummary: savingsSummary,
            lastUpdated: now
        )
    }

    // MARK: - Helpers

    /// Returns the UTC date prefix (e.g. "2026-03-20") for filtering today's items from time-series data.
    private static func todayDatePrefix(_ now: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: now)  // "2026-03-20"
    }
}
