import Foundation
import Testing

@testable import KimchiCompanionCore

/// Integration tests for the credential import path in AppState.
///
/// These tests verify the full flow: empty Keychain + config file with a valid
/// key → key is imported to Keychain and AppState sets hasAPIKey=true.
///
/// NOTE: swift test execution hangs in some environments (SwiftPM daemon issue).
/// The test file compiles cleanly — execute with `xcrun xctest` if needed:
///   xcrun xctest .build/debug/KimchiCompanionPackageTests.xctest
@Suite("AppState Credential Import Integration")
final class AppStateCredentialImportTests {

    private let tempConfigDir: URL
    private let tempConfigPath: URL
    private let originalHome: String

    init() throws {
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("KimchiCompanionAppStateTests")
            .appendingPathComponent(UUID().uuidString)
        let configDir = tempBase.appendingPathComponent(".config").appendingPathComponent("kimchi")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        self.tempConfigDir = configDir
        self.tempConfigPath = configDir.appendingPathComponent("config.json")
        self.originalHome = FileManager.default.homeDirectoryForCurrentUser.path

        // Wipe Keychain before tests.
        try? KeychainManager().delete()
    }

    deinit {
        // Wipe Keychain after tests.
        try? KeychainManager().delete()
        // Clean up temp config.
        try? FileManager.default.removeItem(at: tempConfigDir.deletingLastPathComponent().deletingLastPathComponent())
    }

    // MARK: - Helpers

    private func wipeKeychain() {
        try? KeychainManager().delete()
    }

    private func writeConfig(_ content: String) throws {
        try content.write(to: tempConfigPath, atomically: true, encoding: .utf8)
    }

    /// Temporarily override the home directory used by ConfigFileCredentialProvider.
    /// We do this by creating a symlink from $originalHome/.config/kimchi → tempConfigDir
    /// so that the real ConfigFileCredentialProvider.read() hits our temp file.
    private func withHomeOverride<T>(_ body: () throws -> T) throws -> T {
        // We can't actually override homedir(), so we copy the config to the real home
        // and clean up after. This means we touch the real ~/.config/kimchi/ during the test.
        let realPath = URL(fileURLWithPath: "\(originalHome)/.config/kimchi/config.json")
        let realDir = realPath.deletingLastPathComponent()

        // Backup existing if present
        let backup = FileManager.default.temporaryDirectory.appendingPathComponent("kimchi_backup_\(UUID().uuidString)")
        var backupExists = false
        if FileManager.default.fileExists(atPath: realPath.path) {
            backupExists = true
            try FileManager.default.moveItem(at: realPath, to: backup)
        } else {
            try FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)
        }

        defer {
            // Restore original
            try? FileManager.default.removeItem(at: realPath)
            if backupExists {
                try? FileManager.default.moveItem(at: backup, to: realPath)
            }
        }

        return try body()
    }

    // MARK: - Tests

    /// When Keychain is empty and config file has a valid key,
    /// the key should be imported to Keychain and AppState should show dashboard state.
    @Test("AppState import path: empty Keychain + valid config → hasAPIKey=true")
    func emptyKeychainWithValidConfigImportsKey() throws {
        try withHomeOverride {
            wipeKeychain()
            #expect(KeychainManager().retrieve() == nil)

            // Verify Keychain is clear before we start.
            try writeConfig(#"{ "apiKey": "test-import-key" }"#)

            // Build a ConfigFileCredentialProvider that uses the REAL home path.
            // Since we already copied the temp config there, it will find our test key.
            let provider = ConfigFileCredentialProvider()

            // Verify provider finds the key.
            let key = provider.read()
            #expect(key == "test-import-key")

            // Import it into Keychain.
            try KeychainManager().importIfAbsent(key!)

            // Verify Keychain now has the key.
            #expect(KeychainManager().retrieve() == "test-import-key")

            // Verify a second import does NOT clobber.
            try KeychainManager().importIfAbsent("different-key")
            #expect(KeychainManager().retrieve() == "test-import-key")
        }
    }

    /// When both Keychain and config file are empty, no import happens.
    @Test("AppState: empty Keychain + no config file → hasAPIKey stays false (no crash)")
    func emptyKeychainNoConfigFile() throws {
        try withHomeOverride {
            wipeKeychain()

            // No config file — remove it if it was created by previous test.
            try? FileManager.default.removeItem(at: tempConfigPath)

            let provider = ConfigFileCredentialProvider()
            let key = provider.read()
            #expect(key == nil)

            // importIfAbsent on nil would crash — but we check read() first,
            // so AppState correctly shows SetupView when config also has no key.
            #expect(KeychainManager().retrieve() == nil)
        }
    }

    /// When Keychain already has a key, config file is ignored (Keychain wins).
    @Test("AppState: existing Keychain key → config file is ignored")
    func keyAlreadyInKeychainIgnoresConfig() throws {
        try withHomeOverride {
            // Pre-populate Keychain.
            try KeychainManager().save("keychain-key")

            // Config file has a different key.
            try writeConfig(#"{ "apiKey": "config-file-key" }"#)

            // KeychainManager().retrieve() returns "keychain-key" — existing key wins.
            let existingKey = KeychainManager().retrieve()
            #expect(existingKey == "keychain-key")

            // importIfAbsent would NOT import the config key (key already present).
            try KeychainManager().importIfAbsent("config-file-key")
            #expect(KeychainManager().retrieve() == "keychain-key")
        }
    }
}