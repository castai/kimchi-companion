import Foundation
import Testing

@testable import KimchiCompanionCore

// MARK: - Test Helpers

/// Returns a fresh UserDefaults suite for test isolation.
/// Each call uses a unique name so tests don't pollute each other.
private func makeTestDefaults() -> UserDefaults {
    let suiteName = "com.kimchicompanion.tests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
}

/// Remove all keys from a test suite to prevent leaking state.
private func cleanUp(_ defaults: UserDefaults) {
    defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
    // Remove the specific keys we use
    for key in [
        "com.kimchicompanion.refreshInterval",
        "com.kimchicompanion.displayMode",
        "com.kimchicompanion.launchAtLogin",
    ] {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - PreferencesStore Tests

@Suite("PreferencesStore")
struct PreferencesStoreTests {

    @MainActor
    @Test("Default values are correct for a fresh store")
    func testDefaultValues() {
        let defaults = makeTestDefaults()
        let store = PreferencesStore(defaults: defaults)

        #expect(store.refreshInterval == .fiveMinutes)
        #expect(store.displayMode == .iconAndCost)
        #expect(store.launchAtLogin == false)

        cleanUp(defaults)
    }

    @MainActor
    @Test("Refresh interval persists to UserDefaults and survives re-instantiation")
    func testRefreshIntervalPersistence() {
        let defaults = makeTestDefaults()

        let store1 = PreferencesStore(defaults: defaults)
        store1.refreshInterval = .oneMinute

        // A new store reading the same defaults should pick up the persisted value
        let store2 = PreferencesStore(defaults: defaults)
        #expect(store2.refreshInterval == .oneMinute)

        cleanUp(defaults)
    }

    @MainActor
    @Test("Display mode persists to UserDefaults and survives re-instantiation")
    func testDisplayModePersistence() {
        let defaults = makeTestDefaults()

        let store1 = PreferencesStore(defaults: defaults)
        store1.displayMode = .iconOnly

        let store2 = PreferencesStore(defaults: defaults)
        #expect(store2.displayMode == .iconOnly)

        cleanUp(defaults)
    }

    @MainActor
    @Test("Launch at login persists to UserDefaults")
    func testLaunchAtLoginPersistence() {
        let defaults = makeTestDefaults()

        let store1 = PreferencesStore(defaults: defaults)
        store1.launchAtLogin = true

        let store2 = PreferencesStore(defaults: defaults)
        #expect(store2.launchAtLogin == true)

        cleanUp(defaults)
    }

    @Test("RefreshInterval raw values match expected seconds")
    func testRefreshIntervalRawValues() {
        #expect(RefreshInterval.oneMinute.rawValue == 60)
        #expect(RefreshInterval.twoMinutes.rawValue == 120)
        #expect(RefreshInterval.fiveMinutes.rawValue == 300)
        #expect(RefreshInterval.fifteenMinutes.rawValue == 900)
    }

    @Test("RefreshInterval display names are human-readable")
    func testRefreshIntervalDisplayNames() {
        #expect(RefreshInterval.oneMinute.displayName == "1 min")
        #expect(RefreshInterval.twoMinutes.displayName == "2 min")
        #expect(RefreshInterval.fiveMinutes.displayName == "5 min")
        #expect(RefreshInterval.fifteenMinutes.displayName == "15 min")
    }

    @Test("DisplayMode allCases returns all three modes")
    func testDisplayModeAllCases() {
        let allCases = DisplayMode.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.iconOnly))
        #expect(allCases.contains(.iconAndCost))
        #expect(allCases.contains(.iconAndTokens))
    }

    @Test("DisplayMode display names are human-readable")
    func testDisplayModeDisplayNames() {
        #expect(DisplayMode.iconOnly.displayName == "Icon Only")
        #expect(DisplayMode.iconAndCost.displayName == "Icon + Cost")
        #expect(DisplayMode.iconAndTokens.displayName == "Icon + Tokens")
    }

    @Test("RefreshInterval round-trips through raw value")
    func testRefreshIntervalRoundTrip() {
        for interval in RefreshInterval.allCases {
            let restored = RefreshInterval(rawValue: interval.rawValue)
            #expect(restored == interval)
        }
    }

    @Test("DisplayMode round-trips through raw value")
    func testDisplayModeRoundTrip() {
        for mode in DisplayMode.allCases {
            let restored = DisplayMode(rawValue: mode.rawValue)
            #expect(restored == mode)
        }
    }

    @MainActor
    @Test("Invalid UserDefaults values fall back to defaults")
    func testInvalidDefaultsFallback() {
        let defaults = makeTestDefaults()

        // Write garbage values that won't map to valid enum cases
        defaults.set(9999, forKey: "com.kimchicompanion.refreshInterval")
        defaults.set("nonexistent", forKey: "com.kimchicompanion.displayMode")

        let store = PreferencesStore(defaults: defaults)
        #expect(store.refreshInterval == .fiveMinutes)
        #expect(store.displayMode == .iconAndCost)

        cleanUp(defaults)
    }
}
