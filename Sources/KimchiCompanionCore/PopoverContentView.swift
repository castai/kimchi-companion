import SwiftUI

/// Root view for the MenuBarExtra popover window.
/// Shows SetupView when no API key is configured,
/// or a connected placeholder when a valid key exists.
public struct PopoverContentView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Kimchi Companion")
                .font(.headline)

            Divider()

            if !appState.hasAPIKey {
                SetupView()
            } else {
                connectedPlaceholder
            }

            Spacer()

            Divider()

            // Quit button — essential for no-Dock apps that lack
            // the standard app menu and Cmd+Q shortcut.
            Button("Quit Kimchi Companion") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 300, minHeight: 200)
    }

    // MARK: - Connected State

    private var connectedPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title)
            Text("Connected to CAST AI")
                .font(.subheadline)
            Text("Usage data coming in S03")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
