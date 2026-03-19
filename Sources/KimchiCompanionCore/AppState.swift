import Foundation
import Observation

/// Single source of truth for app-wide state.
/// Downstream slices add usage data properties here.
@Observable
@MainActor
public final class AppState {
    // MARK: - Menu Bar Display

    /// Current cost text shown in the menu bar label.
    /// Updated automatically from usageStore.formattedTodayCost.
    public var displayCost: String = "$0.00"

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

    /// Check Keychain on launch to restore persisted API key state.
    public init() {
        if KeychainManager().retrieve() != nil {
            hasAPIKey = true
            isConnected = true
            // Load cached data from disk immediately (before any network call)
            usageStore.loadCachedData()
            if let cached = usageStore.cachedData {
                displayCost = usageStore.formattedTodayCost
                isStale = usageStore.isStale
                #if DEBUG
                print("[AppState] init — restored API key + loaded cached data (todayCost=\(cached.todayCost))")
                #endif
            } else {
                #if DEBUG
                print("[AppState] init — restored API key from Keychain, no cache on disk")
                #endif
            }
        } else {
            #if DEBUG
            print("[AppState] init — no API key found in Keychain")
            #endif
        }
    }

    // MARK: - Usage Data Refresh

    /// Read the API key from Keychain and refresh usage data.
    /// Updates displayCost and isStale from UsageStore state after refresh.
    public func refreshUsageData() async {
        guard let apiKey = KeychainManager().retrieve() else {
            #if DEBUG
            print("[AppState] refreshUsageData — no API key in Keychain, skipping")
            #endif
            return
        }

        await usageStore.refresh(apiKey: apiKey)
        syncFromUsageStore()
    }

    /// Sync AppState display properties from UsageStore.
    private func syncFromUsageStore() {
        displayCost = usageStore.formattedTodayCost
        isStale = usageStore.isStale
    }
}
