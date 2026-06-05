import Foundation
import Security

// MARK: - KeychainError

/// Typed errors for Keychain operations, preserving OSStatus for diagnostics.
public enum KeychainError: LocalizedError, Sendable {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "A keychain item already exists for this service."
        case .itemNotFound:
            return "No keychain item found for this service."
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

// MARK: - KeychainManager

/// Wraps macOS Security.framework for API key CRUD in Keychain.
///
/// All operations are synchronous (Security.framework APIs are sync).
/// Thread-safe — no mutable state; each call builds a fresh query dictionary.
///
/// Keychain entry:
/// - Service: `com.kimchicompanion.api-key`
/// - Account: `castai-api-key`
/// - Accessibility: `kSecAttrAccessibleWhenUnlocked`
///
/// Inspection via CLI:
/// ```
/// security find-generic-password -s "com.kimchicompanion.api-key"
/// security delete-generic-password -s "com.kimchicompanion.api-key"
/// ```
public struct KeychainManager: Sendable {

    public init() {}

    // MARK: - Constants

    private static let service = "com.kimchicompanion.api-key"
    private static let account = "castai-api-key"

    // MARK: - Public API

    /// Save an API key to Keychain. If a key already exists, it is updated in place.
    ///
    /// - Parameter key: The API key string to store.
    /// - Throws: `KeychainError.unexpectedStatus` if both add and update fail.
    public func save(_ key: String) throws {
        let keyData = Data(key.utf8)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: keyData,
        ]

        var status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Item exists — update it instead of failing.
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.service,
                kSecAttrAccount as String: Self.account,
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData,
            ]
            status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            #if DEBUG
            print("[KeychainManager] save failed — status: \(status)")
            #endif
            throw KeychainError.unexpectedStatus(status)
        }

        #if DEBUG
        print("[KeychainManager] save succeeded")
        #endif
    }

    /// Retrieve the stored API key from Keychain.
    ///
    /// - Returns: The API key string, or `nil` if no entry exists.
    public func retrieve() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            #if DEBUG
            if status != errSecItemNotFound {
                print("[KeychainManager] retrieve unexpected status: \(status)")
            }
            #endif
            return nil
        }

        #if DEBUG
        print("[KeychainManager] retrieve succeeded")
        #endif

        return String(data: data, encoding: .utf8)
    }

    /// Import an API key into Keychain only if no entry currently exists.
    ///
    /// This is the one-time import used when the companion discovers a credential
    /// in the kimchi-harness config file but has never stored one in Keychain.
    /// Idempotent — if a key is already present this is a no-op, so callers can
    /// safely invoke it without checking first.
    ///
    /// - Parameter key: The API key string to store.
    public func importIfAbsent(_ key: String) throws {
        // Check if anything exists first.
        if retrieve() != nil {
            #if DEBUG
            print("[KeychainManager] importIfAbsent — key already present, skipping")
            #endif
            return
        }
        try save(key)
    }

    /// Delete the stored API key from Keychain.
    ///
    /// - Throws: `KeychainError.unexpectedStatus` if deletion fails for a reason other than
    ///   the item not being found (which is treated as a no-op).
    public func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            #if DEBUG
            print("[KeychainManager] delete failed — status: \(status)")
            #endif
            throw KeychainError.unexpectedStatus(status)
        }

        #if DEBUG
        print("[KeychainManager] delete succeeded")
        #endif
    }
}
