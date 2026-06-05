import SwiftUI

/// First-launch view for entering and validating a CAST AI API key.
///
/// Reads `AppState` from the environment and sets `hasAPIKey` / `isConnected`
/// on successful validation + Keychain save.
public struct SetupView: View {
    @Environment(AppState.self) private var appState

    @State private var apiKeyText: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Enter your CAST AI API key")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Paste API key here", text: $apiKeyText)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await validateAndSave() }
            } label: {
                HStack(spacing: 6) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Validate & Save")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyText.isEmpty || isValidating)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Link("Get an API key →", destination: URL(string: "https://kimchi.console.cast.ai/")!)
                .font(.caption)
        }
    }

    // MARK: - Validation Flow

    private func validateAndSave() async {
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }

        let trimmedKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await APIKeyValidator.validate(apiKey: trimmedKey)

        switch result {
        case .success:
            ConfigFileCredentialProvider().write(apiKey: trimmedKey)
            appState.hasAPIKey = true
            appState.isConnected = true
        case .failure(let validationError):
            switch validationError {
            case .invalidKey:
                errorMessage = "Invalid API key. Check that you copied the full key."
            case .networkError(let msg):
                errorMessage = "Network error: \(msg)"
            case .serverError(let code):
                errorMessage = "Server error (HTTP \(code)). Try again later."
            }
        }
    }
}
