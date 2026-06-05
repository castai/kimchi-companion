import Foundation

// MARK: - API Client Errors

/// Typed errors for CAST AI API operations.
public enum APIClientError: LocalizedError, Sendable {
    /// A network-level error occurred (no connectivity, DNS failure, timeout, etc.).
    case networkError(String)
    /// The API key was rejected (HTTP 401 or 403).
    case unauthorized
    /// The server returned an unexpected HTTP status code.
    case serverError(Int)
    /// The response body could not be decoded.
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .unauthorized:
            return "Unauthorized. Check your API key."
        case .serverError(let code):
            return "Server error (HTTP \(code))."
        case .decodingError(let detail):
            return "Failed to decode response: \(detail)"
        }
    }
}

// MARK: - CastAPIClient

/// HTTP client for CAST AI usage and savings report APIs.
///
/// Stateless and `Sendable` — all state lives in the arguments and return values.
/// Uses `URLSession.shared` for requests. API key is accepted per-call, never stored.
///
/// Debug prints use the `[CastAPIClient]` prefix for grep-ability.
/// **The API key value is never logged.**
public struct CastAPIClient: Sendable {

    /// Base URL for the CAST AI API.
    private static let baseURL = "https://api.cast.ai"

    /// Shared JSON decoder configured for the CAST AI response format.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// JSON decoder for endpoints that use camelCase keys (analytics report).
    /// Unlike the main decoder, this does NOT apply snake_case conversion so
    /// camelCase keys like `changePercentage` and `totalCost` decode correctly.
    private static let camelCaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    /// Request timeout in seconds.
    private static let timeoutInterval: TimeInterval = 30

    // MARK: - Public API

    /// Fetch the org usage report for a time range.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - from: Start of the reporting period (inclusive).
    ///   - to: End of the reporting period (exclusive).
    /// - Returns: Decoded usage report response.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchUsageReport(
        apiKey: String,
        from: Date,
        to: Date
    ) async throws -> UsageReportResponse {
        let path = "/v1/llm/openai/chat-completions/reports/usage"
        let queryItems = timeRangeQueryItems(from: from, to: to)
        return try await performRequest(path: path, queryItems: queryItems, apiKey: apiKey)
    }

    /// Fetch the per-key savings report for a time range.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - from: Start of the reporting period (inclusive).
    ///   - to: End of the reporting period (exclusive).
    /// - Returns: Decoded savings report response.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchSavingsReport(
        apiKey: String,
        from: Date,
        to: Date
    ) async throws -> SavingsReportResponse {
        let path = "/v1/llm/openai/chat-completions/reports/api-keys-savings"
        let queryItems = timeRangeQueryItems(from: from, to: to)
        return try await performRequest(path: path, queryItems: queryItems, apiKey: apiKey)
    }

    /// Fetch the recommendations report for a time range.
    ///
    /// Returns achieved savings, potential savings, and per-model recommendations.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - from: Start of the reporting period (inclusive).
    ///   - to: End of the reporting period (exclusive).
    /// - Returns: Decoded recommendations report response.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchRecommendationsReport(
        apiKey: String,
        from: Date,
        to: Date
    ) async throws -> RecommendationsReportResponse {
        let path = "/v1/llm/openai/chat-completions/reports/recommendations"
        let queryItems = timeRangeQueryItems(from: from, to: to)
        return try await performRequest(path: path, queryItems: queryItems, apiKey: apiKey)
    }

    /// Fetch usage detail for a specific API key.
    ///
    /// Returns time-series usage data including token counts and request counts.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key for authentication. Never logged.
    ///   - apiKeyId: The specific API key ID to fetch usage for.
    ///   - from: Start of the reporting period (inclusive).
    ///   - to: End of the reporting period (exclusive).
    /// - Returns: Decoded per-key usage report response.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchAPIKeyUsage(
        apiKey: String,
        apiKeyId: String,
        from: Date,
        to: Date
    ) async throws -> APIKeyUsageReportResponse {
        let path = "/v1/llm/openai/chat-completions/reports/api-keys/\(apiKeyId)/usage"
        let queryItems = timeRangeQueryItems(from: from, to: to)
        return try await performRequest(path: path, queryItems: queryItems, apiKey: apiKey)
    }

    /// Fetch all organizations accessible with the given API key.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    /// - Returns: Decoded list of organizations.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchOrganizations(apiKey: String) async throws -> ListOrganizationsResponse {
        let path = "/v1/organizations"
        return try await performRequest(
            path: path,
            queryItems: [],
            apiKey: apiKey,
            decoder: decoder
        )
    }

    /// Fetch analytics report for a specific organization.
    ///
    /// When `isUserScoped` is true, adds `inferUserFromApiKey=true` so the report
    /// is scoped to the user identified by the API key rather than the org as a whole.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - orgId: The target organization ID.
    ///   - startTime: Start of the reporting period (inclusive).
    ///   - endTime: End of the reporting period (exclusive).
    ///   - isUserScoped: If true, scope the report to the API key's user.
    /// - Returns: Decoded analytics report for the organization.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchOrganizationAnalytics(
        apiKey: String,
        orgId: String,
        startTime: Date,
        endTime: Date,
        isUserScoped: Bool
    ) async throws -> GenerateAnalyticsResponse {
        let path = "/ai-optimizer/v1beta/organizations/\(orgId):generateAnalyticsReport"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "startTime", value: iso8601String(from: startTime)),
            URLQueryItem(name: "endTime", value: iso8601String(from: endTime)),
        ]
        if isUserScoped {
            queryItems.append(URLQueryItem(name: "inferUserFromApiKey", value: "true"))
        }
        return try await performRequest(
            path: path,
            queryItems: queryItems,
            apiKey: apiKey,
            decoder: camelCaseDecoder
        )
    }

    /// Fetch analytics data for the authenticated user.
    ///
    /// Uses `inferUserFromApiKey=true` so data is scoped to the user who owns
    /// the API key — matching kimchi-harness behavior.
    ///
    /// Replaces the deprecated `/v1/llm/.../reports/*` endpoints.
    ///
    /// - Parameters:
    ///   - apiKey: CAST AI API key. Never logged.
    ///   - startTime: Start of the reporting period (inclusive).
    ///   - endTime: End of the reporting period (exclusive).
    /// - Returns: Decoded analytics response scoped to the authenticated user.
    /// - Throws: `APIClientError` on network, auth, server, or decoding failure.
    public static func fetchAnalytics(
        apiKey: String,
        startTime: Date,
        endTime: Date
    ) async throws -> AnalyticsResponse {
        let path = "/ai-optimizer/v1beta/analytics"
        let queryItems = [
            URLQueryItem(name: "startTime", value: iso8601String(from: startTime)),
            URLQueryItem(name: "endTime", value: iso8601String(from: endTime)),
            URLQueryItem(name: "inferUserFromApiKey", value: "true"),
        ]
        return try await performRequest(path: path, queryItems: queryItems, apiKey: apiKey)
    }

    // MARK: - Helpers

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    // MARK: - Internal

    /// Build ISO 8601 query items for the time range parameters.
    private static func timeRangeQueryItems(from: Date, to: Date) -> [URLQueryItem] {
        return [
            URLQueryItem(name: "fromTime", value: iso8601String(from: from)),
            URLQueryItem(name: "toTime", value: iso8601String(from: to)),
        ]
    }

    /// Generic request handler that builds, executes, and decodes a GET request.
    private static func performRequest<T: Decodable & Sendable>(
        path: String,
        queryItems: [URLQueryItem],
        apiKey: String,
        decoder: JSONDecoder = decoder
    ) async throws -> T {
        // Build URL with query parameters
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIClientError.networkError("Invalid URL: \(baseURL + path)")
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIClientError.networkError("Failed to construct URL from components")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutInterval

        #if DEBUG
        print("[CastAPIClient] GET \(url.absoluteString)")
        #endif

        // Execute request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[CastAPIClient] network error: \(error.localizedDescription)")
            #endif
            throw APIClientError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkError("Unexpected response type")
        }

        let statusCode = httpResponse.statusCode

        #if DEBUG
        print("[CastAPIClient] status: \(statusCode), bytes: \(data.count)")
        #endif

        // Check HTTP status
        switch statusCode {
        case 200:
            break
        case 401, 403:
            throw APIClientError.unauthorized
        default:
            throw APIClientError.serverError(statusCode)
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[CastAPIClient] decoding error: \(error)")
            #endif
            throw APIClientError.decodingError(error.localizedDescription)
        }
    }
}
