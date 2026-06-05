import Foundation
import Observation

/// Single source of truth for app-wide state.
/// Downstream slices add usage data properties here.
@Observable
@MainActor
public final class AppState {
    // MARK: - Organization State

    /// All organizations the authenticated user belongs to.
    public var organizations: [Organization] = []

    /// Whether organizations are currently being fetched.
    public var isLoadingOrganizations: Bool = false

    // MARK: - Menu Bar Display

    /// Current cost text shown in the menu bar label.
    /// Updated automatically from usageStore.formattedTodayCost.
    public var displayCost: String = "$0.00"

    /// Currently selected usage scope for the popover view.
    public var selectedScope: UsageScope = .individual

    /// Currently selected individual API key ID (when scope is .individual).
    public var selectedKeyId: String?

    /// Formatted today token count for menu bar display (e.g., "12.3K", "1.2M").
    /// Sum of input + output tokens, compact notation.
    public var formattedTodayTokens: String {
        let total = usageStore.todayTokensIn + usageStore.todayTokensOut
        guard total > 0 else { return "0" }

        if total >= 1_000_000 {
            let millions = Double(total) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if total >= 1_000 {
            let thousands = Double(total) / 1_000.0
            return String(format: "%.1fK", thousands)
        } else {
            return "\(total)"
        }
    }

    /// Text for the menu bar label based on current display mode.
    /// Returns empty string for `.iconOnly`.
    public var displayText: String {
        switch preferencesStore.displayMode {
        case .iconOnly:
            return ""
        case .iconAndCost:
            return displayCost
        case .iconAndTokens:
            return formattedTodayTokens
        }
    }

    // MARK: - Connection State

    /// Whether the app has a valid connection to the OpenAI API (S02).
    public var isConnected: Bool = false

    /// Whether the displayed cost data is stale / outdated (S03).
    public var isStale: Bool = false

    /// Whether the user has configured an API key (S02).
    public var hasAPIKey: Bool = false

    // MARK: - Usage Store

    /// Owns the fetch → cache → display → stale pipeline for CAST AI usage data.
    public let usageStore = UsageStore()

    // MARK: - Preferences Store

    /// User-configurable preferences: refresh interval, display mode, launch-at-login.
    public let preferencesStore = PreferencesStore()

    // MARK: - Initialization

    /// Check config file on launch to restore persisted API key state.
    public init() {
        let configProvider = ConfigFileCredentialProvider()
        if configProvider.read() != nil {
            hasAPIKey = true
            isConnected = true
            // Load cached data from disk immediately (before any network call)
            usageStore.loadCachedData()
            // Fetch organizations for the org selector
            Task {
                await fetchOrganizations()
            }
            if let cached = usageStore.cachedData {
                displayCost = usageStore.formattedTodayCost
                isStale = usageStore.isStale
                #if DEBUG
                print("[AppState] init — restored API key + loaded cached data (todayCost=\(cached.todayCost))")
                #endif
            } else {
                #if DEBUG
                print("[AppState] init — restored API key from config file, no cache on disk")
                #endif
            }
            // Trigger initial data refresh
            Task {
                await refreshUsageData()
            }
        } else {
            #if DEBUG
            print("[AppState] init — no API key found in config file")
            #endif
        }
    }

    // MARK: - Organizations

    /// Fetches the list of organizations the user belongs to.
    /// Requires an API key to be present in the config file.
    public func fetchOrganizations() async {
        guard let apiKey = ConfigFileCredentialProvider().read() else {
            #if DEBUG
            print("[AppState] fetchOrganizations — no API key in config file, skipping")
            #endif
            return
        }

        isLoadingOrganizations = true
        defer { isLoadingOrganizations = false }

        do {
            let response = try await CastAPIClient.fetchOrganizations(apiKey: apiKey)
            self.organizations = response.organizations
            #if DEBUG
            print("[AppState] fetchOrganizations — loaded \(response.organizations.count) organizations")
            #endif
        } catch {
            #if DEBUG
            print("[AppState] fetchOrganizations — error: \(error)")
            #endif
        }
    }

    /// Sets the currently selected organization and persists the choice.
    /// TODO: Wire this to usageStore.refresh(apiKey:organizationId:) once UsageStore
    /// supports organizationId filtering (Phase 3).
    public func selectOrganization(id: String?) {
        preferencesStore.selectedOrganizationId = id
        #if DEBUG
        print("[AppState] selectOrganization — selected \(id ?? "nil")")
        #endif
    }

    // MARK: - Usage Data Refresh

    /// Read the API key from config file and refresh usage data.
    /// Updates displayCost and isStale from UsageStore state after refresh.
    public func refreshUsageData() async {
        guard let apiKey = ConfigFileCredentialProvider().read() else {
            #if DEBUG
            print("[AppState] refreshUsageData — no API key in config file, skipping")
            #endif
            return
        }

        await usageStore.refresh(
            apiKey: apiKey,
            organizationId: preferencesStore.selectedOrganizationId,
            isUserScoped: preferencesStore.overviewTab == .you
        )
        syncFromUsageStore()
    }

    /// Sync AppState display properties from UsageStore.
    /// When a key is selected (individual scope), menu bar shows that key's cost.
    private func syncFromUsageStore() {
        // Compute individual key cost for menu bar label
        let keyCost = individualKeyCost()
        displayCost = keyCost ?? usageStore.formattedTodayCost
        isStale = usageStore.isStale
    }

    /// Cost of the currently selected individual API key.
    /// Returns nil if no key data available.
    private func individualKeyCost() -> String? {
        guard selectedScope == .individual else { return nil }
        let keys = usageStore.cachedData?.keyBreakdown ?? []
        guard !keys.isEmpty else { return nil }

        // Use selectedKeyId if set, otherwise first key
        let id = selectedKeyId ?? keys.first?.id
        guard let keyId = id,
              let key = keys.first(where: { $0.id == keyId }) else {
            return keys.first?.cost
        }
        return key.cost
    }
}
