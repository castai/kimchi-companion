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

    /// Main fetch orchestrator: calls both API endpoints concurrently, merges results,
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

        // Fetch both endpoints concurrently
        var usageReport: UsageReportResponse?
        var savingsReport: SavingsReportResponse?
        var fetchError: Error?

        // Use async let for concurrent execution
        do {
            async let usageTask = CastAPIClient.fetchUsageReport(
                apiKey: apiKey, from: todayStart, to: now
            )
            async let savingsTask = CastAPIClient.fetchSavingsReport(
                apiKey: apiKey, from: weekStart, to: now
            )

            // Await both — if one fails we still want the other
            do {
                usageReport = try await usageTask
            } catch {
                fetchError = error
                #if DEBUG
                print("[UsageStore] usage report fetch failed: \(error.localizedDescription)")
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
        }

        // If both failed, mark stale and bail
        if usageReport == nil && savingsReport == nil {
            isStale = true
            lastError = fetchError?.localizedDescription ?? "Both API calls failed"
            #if DEBUG
            print("[UsageStore] fetch failure — both endpoints failed, isStale=true")
            #endif
            return
        }

        // Merge responses into CachedUsageData
        let data = mergeResponses(
            usage: usageReport,
            savings: savingsReport,
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
        print("[UsageStore] fetch success — todayCost=\(data.todayCost), weekCost=\(data.weekCost), items=\(data.modelBreakdown.count)")
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

    /// Merge usage and savings reports into the unified cached structure.
    private func mergeResponses(
        usage: UsageReportResponse?,
        savings: SavingsReportResponse?,
        now: Date
    ) -> CachedUsageData {
        // Today's cost from usage report: sum of all items' daily costs
        let todayCostDecimal = usage?.items.reduce(Decimal.zero) { $0 + $1.dailyCostDecimal } ?? .zero

        // Week cost: sum all savings items' total costs (covers the week window)
        let weekCostDecimal = savings?.items.reduce(Decimal.zero) { $0 + $1.costs.totalDecimal } ?? .zero

        // Token counts from savings report (aggregated across all keys)
        let todayTokensIn = savings?.items.reduce(0) { $0 + $1.tokenCount.in } ?? 0
        let todayTokensOut = savings?.items.reduce(0) { $0 + $1.tokenCount.out } ?? 0
        let todayRequests = savings?.items.reduce(0) { $0 + $1.requestCount } ?? 0

        // For week tokens, we use the same savings data (it covers the week window)
        let weekTokensIn = todayTokensIn
        let weekTokensOut = todayTokensOut
        let weekRequests = todayRequests

        // Model breakdown from usage report's per-category breakdown or savings per-key
        var breakdown: [ModelCostEntry] = []
        if let categories = usage?.items.first?.costPerCategory {
            breakdown = categories.map { ModelCostEntry(name: $0.key, cost: $0.value) }
                .sorted { ($0.costDecimal) > ($1.costDecimal) }
        } else if let items = savings?.items, !items.isEmpty {
            breakdown = items.map {
                ModelCostEntry(name: $0.alias ?? $0.id, cost: $0.costs.total)
            }.sorted { $0.costDecimal > $1.costDecimal }
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
            lastUpdated: now
        )
    }
}
