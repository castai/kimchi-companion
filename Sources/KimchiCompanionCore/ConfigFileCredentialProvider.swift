import Foundation

// MARK: - ConfigFileCredentialProviderError

/// Errors for config file credential reading, all non-fatal.
public enum ConfigFileCredentialProviderError: LocalizedError, Sendable {
    case fileNotFound
    case parseError

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Config file does not exist."
        case .parseError:
            return "Config file is not valid JSON."
        }
    }
}

// MARK: - ConfigFileCredentialProvider

/// Reads CAST AI API key from the kimchi-harness config file.
///
/// The kimchi CLI stores the API key at `~/.config/kimchi/config.json` as
/// `{ "apiKey": "<token>" }`. This provider reads that file as a fallback
/// when the Keychain has no stored credential.
///
/// Config resolution order (first existing file wins):
///   1. `~/.config/kimchi-companion/config.json` (companion override — for testing)
///   2. `~/.config/kimchi/config.json` (kimchi-harness primary config)
///   3. no file → returns nil silently
///
/// All failures (missing file, corrupt JSON, empty/missing apiKey field) are
/// silent no-ops — this provider never throws to the caller. The caller treats
/// nil as "no credential found in config file".
///
/// This type is Sendable and stateless — safe to call from any thread.
public struct ConfigFileCredentialProvider {

    /// Candidate (path, fileManager) pairs tried in order; first non-nil result wins.
    /// Stored as a property so tests can inject controlled paths.
    let pathProviders: [() -> (path: String, fileManager: FileManager)]

    /// Default production initializer.
    public init() {
        let fm: FileManager = .default
        self.pathProviders = [{
            let home = fm.homeDirectoryForCurrentUser.path
            return ("\(home)/.config/kimchi-companion/config.json", fm)
        }, {
            let home = fm.homeDirectoryForCurrentUser.path
            return ("\(home)/.config/kimchi/config.json", fm)
        }]
    }

    /// Test-only initializer allowing explicit path overrides.
    /// Each `(path, fileManager)` pair is tried in order; the first non-nil result wins.
    init(pathProviders: [() -> (path: String, fileManager: FileManager)]) {
        self.pathProviders = pathProviders
    }

    // MARK: - Public API

    /// Attempt to read an API key from the kimchi config file.
    ///
    /// - Returns: The API key string, or `nil` if the file does not exist,
    ///   cannot be parsed, or contains no non-empty `apiKey` field.
    ///
    /// This method never throws. All error conditions return `nil` so callers
    /// can use a simple `if let` without try/catch.
    public func read() -> String? {
        for provider in pathProviders {
            let (path, fm) = provider()
            if let key = extractApiKey(from: path, fileManager: fm) {
                return key
            }
        }
        return nil
    }

    // MARK: - Write / Clear

    /// Write the API key to the primary config file (~/.config/kimchi/config.json).
    /// Creates the directory if needed. Overwrites existing file.
    public func write(apiKey: String) {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dir = "\(home)/.config/kimchi"
        let path = "\(dir)/config.json"

        // Create directory if needed
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Write JSON
        let json: [String: String] = ["apiKey": apiKey]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            fm.createFile(atPath: path, contents: data)
            #if DEBUG
            print("[ConfigFileCredentialProvider] wrote apiKey to \(path)")
            #endif
        }
    }

    /// Remove the API key from the primary config file by deleting it.
    public func clear() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/kimchi/config.json"
        try? fm.removeItem(atPath: path)
        #if DEBUG
        print("[ConfigFileCredentialProvider] removed \(path)")
        #endif
    }

    // MARK: - Private

    /// Read and parse a single config file, returning the apiKey if present.
    /// Returns nil for any error (file missing, parse failure, empty field).
    private func extractApiKey(from path: String, fileManager: FileManager = .default) -> String? {
        guard fileManager.fileExists(atPath: path) else {
            #if DEBUG
            print("[ConfigFileCredentialProvider] file not found: \(path)")
            #endif
            return nil
        }

        guard let data = fileManager.contents(atPath: path) else {
            #if DEBUG
            print("[ConfigFileCredentialProvider] could not read: \(path)")
            #endif
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            #if DEBUG
            print("[ConfigFileCredentialProvider] parse error: \(path)")
            #endif
            return nil
        }

        // Support both camelCase (apiKey) and snake_case (api_key) for compat
        // with kimchi-harness which writes camelCase but may have legacy snake_case.
        if let key = (json["apiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            #if DEBUG
            print("[ConfigFileCredentialProvider] read apiKey from: \(path)")
            #endif
            return key
        }

        if let key = (json["api_key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            #if DEBUG
            print("[ConfigFileCredentialProvider] read apiKey from: \(path)")
            #endif
            return key
        }

        #if DEBUG
        print("[ConfigFileCredentialProvider] apiKey field missing or empty: \(path)")
        #endif
        return nil
    }
}