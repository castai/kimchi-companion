import Foundation
import Observation

/// Single source of truth for app-wide state.
/// Downstream slices add usage data properties here.
@Observable
@MainActor
final class AppState {
    // MARK: - Menu Bar Display
    
    /// Current cost text shown in the menu bar label.
    /// Updated by the usage polling service (S03).
    var displayCost: String = "$0.00"
    
    // MARK: - Connection State
    
    /// Whether the app has a valid connection to the OpenAI API (S02).
    var isConnected: Bool = false
    
    /// Whether the displayed cost data is stale / outdated (S03).
    var isStale: Bool = false
    
    /// Whether the user has configured an API key (S02).
    var hasAPIKey: Bool = false

    // MARK: - Initialization

    /// Check Keychain on launch to restore persisted API key state.
    init() {
        if KeychainManager().retrieve() != nil {
            hasAPIKey = true
            isConnected = true
            #if DEBUG
            print("[AppState] init — restored API key from Keychain")
            #endif
        } else {
            #if DEBUG
            print("[AppState] init — no API key found in Keychain")
            #endif
        }
    }
}
