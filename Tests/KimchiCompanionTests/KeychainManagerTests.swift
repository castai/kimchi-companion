import Foundation
import Security
import Testing

@testable import KimchiCompanionCore

@Suite("KeychainManager")
final class KeychainManagerTests {

    // MARK: - Helper

    /// Wipes the Keychain; used for per-test isolation since tests share the
    /// same macOS Keychain entry and may run in parallel.
    private func wipeKeychain() {
        try? KeychainManager().delete()
    }

    // MARK: - Lifecycle

    init() {
        wipeKeychain()
    }

    deinit {
        wipeKeychain()
    }

    // MARK: - importIfAbsent

    @Test("importIfAbsent saves the key when Keychain is empty")
    func importIfAbsentSavesWhenEmpty() throws {
        wipeKeychain()
        #expect(KeychainManager().retrieve() == nil)

        try KeychainManager().importIfAbsent("test-key-12345")

        let retrieved = KeychainManager().retrieve()
        #expect(retrieved == "test-key-12345")
    }

    @Test("importIfAbsent is a no-op when a key already exists")
    func importIfAbsentNoOpWhenPresent() throws {
        wipeKeychain()
        try KeychainManager().save("existing-key")

        try KeychainManager().importIfAbsent("new-key")

        // Key must NOT be clobbered.
        let retrieved = KeychainManager().retrieve()
        #expect(retrieved == "existing-key")
    }

    @Test("importIfAbsent is safe to call multiple times when empty — first key wins")
    func importIfAbsentIdempotentMultipleCallsWhenEmpty() throws {
        wipeKeychain()
        #expect(KeychainManager().retrieve() == nil)

        try KeychainManager().importIfAbsent("first-key")
        try KeychainManager().importIfAbsent("second-key")

        // Second call must not have over-written the first.
        #expect(KeychainManager().retrieve() == "first-key")
    }

    // MARK: - save / retrieve / delete

    @Test("save persists a key and retrieve returns it")
    func saveAndRetrieve() throws {
        wipeKeychain()
        try KeychainManager().save("save-retrieve-test")
        #expect(KeychainManager().retrieve() == "save-retrieve-test")
    }

    @Test("save overwrites an existing key")
    func saveOverwritesExisting() throws {
        wipeKeychain()
        try KeychainManager().save("original-key")
        try KeychainManager().save("updated-key")
        #expect(KeychainManager().retrieve() == "updated-key")
    }

    @Test("retrieve returns nil when Keychain is empty")
    func retrieveNilWhenEmpty() throws {
        wipeKeychain()
        #expect(KeychainManager().retrieve() == nil)
    }

    @Test("delete removes the key and retrieve returns nil")
    func deleteRemovesKey() throws {
        wipeKeychain()
        try KeychainManager().save("delete-test")
        try KeychainManager().delete()
        #expect(KeychainManager().retrieve() == nil)
    }

    @Test("delete is a no-op when Keychain is already empty")
    func deleteNoOpWhenEmpty() throws {
        wipeKeychain()
        try KeychainManager().delete()
        #expect(KeychainManager().retrieve() == nil)
    }
}