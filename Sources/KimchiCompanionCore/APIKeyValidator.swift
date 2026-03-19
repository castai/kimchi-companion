import Foundation

// MARK: - ValidationError

/// Typed errors for API key validation against CAST AI.
public enum ValidationError: LocalizedError, Sendable {
    /// The API key was rejected (HTTP 401 or 403).
    case invalidKey
    /// A network-level error occurred (no connectivity, DNS failure, timeout, etc.).
    case networkError(String)
    /// The server returned an unexpected HTTP status code.
    case serverError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid API key. Please check the key and try again."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please try again later."
        }
    }
}

// MARK: - APIKeyValidator

/// Validates a CAST AI API key by hitting a lightweight authenticated endpoint.
///
/// Uses `GET /v1/llm/openai/supported-providers` with the `X-API-Key` header (D006).
/// A 200 response means the key is valid. 401/403 means invalid. Other errors are surfaced
/// as typed `ValidationError` values.
///
/// This is a stateless utility — all state lives in the arguments and return value.
public struct APIKeyValidator: Sendable {

    /// The endpoint used to validate the API key.
    private static let validationURL = URL(
        string: "https://api.cast.ai/v1/llm/openai/supported-providers"
    )!

    /// Validate an API key against the CAST AI API.
    ///
    /// - Parameter apiKey: The key to validate. Never logged or included in error messages.
    /// - Returns: `.success(())` if the key is valid, `.failure(ValidationError)` otherwise.
    public static func validate(apiKey: String) async -> Result<Void, ValidationError> {
        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        // Short timeout — this is a validation probe, not a data fetch.
        request.timeoutInterval = 15

        let response: URLResponse

        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[APIKeyValidator] network error: \(error.localizedDescription)")
            #endif
            return .failure(.networkError(error.localizedDescription))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.networkError("Unexpected response type"))
        }

        let statusCode = httpResponse.statusCode

        #if DEBUG
        print("[APIKeyValidator] response status: \(statusCode)")
        #endif

        switch statusCode {
        case 200:
            return .success(())
        case 401, 403:
            return .failure(.invalidKey)
        default:
            return .failure(.serverError(statusCode))
        }
    }
}
