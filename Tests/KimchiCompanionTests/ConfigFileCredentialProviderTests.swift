import Foundation
import Testing

@testable import KimchiCompanionCore

@Suite("ConfigFileCredentialProvider")
struct ConfigFileCredentialProviderTests {

    // MARK: - Temp File Helpers

    /// Creates a ConfigFileCredentialProvider backed by a temp directory that
    /// will never contain a real kimchi config file. Uses a path far away from
    /// ~/.config to ensure the provider reads the controlled temp file only.
    private func providerInTempDir(content: String?) throws -> ConfigFileCredentialProvider {
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("KimchiCompanionProviderTests")
            .appendingPathComponent(UUID().uuidString)

        let configDir = tempBase.appendingPathComponent(".config").appendingPathComponent("kimchi")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        let configPath = configDir.appendingPathComponent("config.json")

        if let content = content {
            try content.write(toFile: configPath.path, atomically: true, encoding: .utf8)
        }

        // Keep tempBase alive for the closure's lifetime.
        _ = tempBase

        return ConfigFileCredentialProvider(pathProviders: [{
            let home = tempBase.path
            let p = "\(home)/.config/kimchi/config.json"
            return (p, FileManager.default)
        }])
    }

    // MARK: - File Not Found

    @Test("read() returns nil when file does not exist")
    func fileMissing() throws {
        let provider = try providerInTempDir(content: nil)
        let result = provider.read()
        #expect(result == nil)
    }

    @Test("read() returns nil when file is empty")
    func fileEmpty() throws {
        let provider = try providerInTempDir(content: "")
        let result = provider.read()
        #expect(result == nil)
    }

    @Test("read() returns nil for corrupt (non-JSON) content")
    func corruptJSON() throws {
        let provider = try providerInTempDir(content: "this is not json { [")
        let result = provider.read()
        #expect(result == nil)
    }

    @Test("read() returns nil when apiKey field is missing from valid JSON")
    func missingApiKeyField() throws {
        let provider = try providerInTempDir(
            content: #"{ "other_field": "value", "version": 1 }"#
        )
        let result = provider.read()
        #expect(result == nil)
    }

    @Test("read() returns nil when apiKey field is empty string")
    func emptyApiKeyField() throws {
        let provider = try providerInTempDir(content: #"{ "apiKey": "" }"#)
        let result = provider.read()
        #expect(result == nil)
    }

    @Test("read() returns nil when apiKey field is whitespace-only")
    func whitespaceApiKeyField() throws {
        let provider = try providerInTempDir(content: #"{ "apiKey": "   \n  " }"#)
        let result = provider.read()
        #expect(result == nil)
    }

    // MARK: - Valid Key

    @Test("read() returns the key when apiKey field is valid (camelCase)")
    func validApiKeyCamelCase() throws {
        let provider = try providerInTempDir(
            content: #"{ "apiKey": "sk-castai-test-key-12345" }"#
        )
        let result = provider.read()
        #expect(result == "sk-castai-test-key-12345")
    }

    @Test("read() returns the key when api_key field is valid (snake_case legacy)")
    func validApiKeySnakeCase() throws {
        let provider = try providerInTempDir(
            content: #"{ "api_key": "sk-castai-snake-case-key" }"#
        )
        let result = provider.read()
        #expect(result == "sk-castai-snake-case-key")
    }

    @Test("read() prefers camelCase over snake_case when both are present")
    func prefersCamelCaseOverSnakeCase() throws {
        let provider = try providerInTempDir(
            content: #"{ "apiKey": "camel-key", "api_key": "snake-key" }"#
        )
        let result = provider.read()
        #expect(result == "camel-key")
    }

    @Test("read() returns key with surrounding whitespace trimmed")
    func whitespaceTrimmed() throws {
        let provider = try providerInTempDir(
            content: #"{ "apiKey": "  sk-castai-whitespace-key  \n" }"#
        )
        let result = provider.read()
        #expect(result == "sk-castai-whitespace-key")
    }


}