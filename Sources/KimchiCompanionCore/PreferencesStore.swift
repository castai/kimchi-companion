import Foundation
import Observation
import LaunchAtLogin

// MARK: - RefreshInterval

/// Available polling intervals for background usage data refresh.
public enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case fifteenMinutes = 900

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .oneMinute: "1 min"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        }
    }
}

// MARK: - DisplayMode

/// Controls what the menu bar label shows alongside the icon.
public enum DisplayMode: String, CaseIterable, Identifiable, Sendable {
    case iconOnly
    case iconAndCost
    case iconAndTokens

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iconOnly: "Icon Only"
        case .iconAndCost: "Icon + Cost"
        case .iconAndTokens: "Icon + Tokens"
        }
    }
}

// MARK: - UsageScope

/// Controls the data scope shown in the popover: org-wide, all API keys, or a single key.
public enum UsageScope: String, CaseIterable, Identifiable, Sendable {
    case global
    case team
    case individual

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .global: "Global"
        case .team: "Team"
        case .individual: "Individual"
        }
    }
}

// MARK: - PreferencesStore

/// Persists user preferences to UserDefaults. Uses manual read/write instead of
/// `@AppStorage` because `@AppStorage` doesn't compose with `@Observable`.
///
/// ## Observability
/// - Debug prints use the `[PreferencesStore]` prefix, gated behind `#if DEBUG`.
/// - Inspect persisted values: `defaults read` with keys prefixed `com.kimchicompanion.`.
/// - LaunchAtLogin errors logged (non-bundled builds can't register with SMAppService).
@Observable
@MainActor
public final class PreferencesStore {

    // MARK: - OverviewTab

    /// Controls the active tab in the overview popover: personal or org-wide.
    public enum OverviewTab: String, CaseIterable, Identifiable, Sendable {
        case you
        case org

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .you: return "You"
            case .org: return "Org"
            }
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let refreshInterval = "com.kimchicompanion.refreshInterval"
        static let displayMode = "com.kimchicompanion.displayMode"
        static let launchAtLogin = "com.kimchicompanion.launchAtLogin"
        static let selectedOrganizationId = "com.kimchicompanion.selectedOrganizationId"
        static let overviewTab = "com.kimchicompanion.overviewTab"
    }

    // MARK: - Backing Storage

    private let defaults: UserDefaults

    // MARK: - Properties

    public var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
            #if DEBUG
            print("[PreferencesStore] refreshInterval changed to \(refreshInterval.displayName)")
            #endif
        }
    }

    public var displayMode: DisplayMode {
        didSet {
            defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
            #if DEBUG
            print("[PreferencesStore] displayMode changed to \(displayMode.displayName)")
            #endif
        }
    }

    public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            #if DEBUG
            print("[PreferencesStore] launchAtLogin changed to \(launchAtLogin)")
            #endif
            // SMAppService requires a proper .app bundle — errors logged by LaunchAtLogin
            LaunchAtLogin.isEnabled = launchAtLogin
        }
    }

    /// Currently selected organization ID for org-scoped overview.
    public var selectedOrganizationId: String? {
        didSet {
            defaults.set(selectedOrganizationId, forKey: Keys.selectedOrganizationId)
            #if DEBUG
            print("[PreferencesStore] selectedOrganizationId changed to \(selectedOrganizationId ?? "nil")")
            #endif
        }
    }

    /// Active overview tab (You vs Org) in the popover.
    public var overviewTab: OverviewTab {
        didSet {
            defaults.set(overviewTab.rawValue, forKey: Keys.overviewTab)
            #if DEBUG
            print("[PreferencesStore] overviewTab changed to \(overviewTab.displayName)")
            #endif
        }
    }

    // MARK: - Initialization

    /// Creates a PreferencesStore backed by the given UserDefaults suite.
    /// - Parameter defaults: UserDefaults instance. Pass a custom suite for testing.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Read persisted refresh interval (or use default)
        let storedInterval = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = RefreshInterval(rawValue: storedInterval) ?? .fiveMinutes

        // Read persisted display mode (or use default)
        let storedMode = defaults.string(forKey: Keys.displayMode) ?? ""
        self.displayMode = DisplayMode(rawValue: storedMode) ?? .iconAndCost

        // Read persisted launch-at-login (defaults to false for unset key)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Read persisted selectedOrganizationId (nil if not set)
        self.selectedOrganizationId = defaults.string(forKey: Keys.selectedOrganizationId)

        // Read persisted overview tab (defaults to .you)
        let storedTab = defaults.string(forKey: Keys.overviewTab) ?? ""
        self.overviewTab = OverviewTab(rawValue: storedTab) ?? .you

        #if DEBUG
        print("[PreferencesStore] init — interval=\(refreshInterval.displayName), mode=\(displayMode.displayName), launchAtLogin=\(launchAtLogin), selectedOrganizationId=\(selectedOrganizationId ?? "nil"), overviewTab=\(overviewTab.displayName)")
        #endif
    }
}
