import SwiftUI
import LaunchAtLogin

/// Inline settings section displayed in the popover footer.
/// Provides controls for refresh interval, display mode, launch at login,
/// and API key management (change / remove).
///
/// ## Observability
/// - Debug prints use the `[SettingsView]` prefix, gated behind `#if DEBUG`.
/// - "Remove API Key" confirmation action logs success/failure.
/// - API key is never logged.
public struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showRemoveKeyAlert = false

    public init() {}

    public var body: some View {
        @Bindable var prefs = appState.preferencesStore

        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.headline)

            // Refresh interval picker
            Picker("Refresh", selection: $prefs.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            .pickerStyle(.menu)

            // Display mode picker
            Picker("Display", selection: $prefs.displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)

            // Launch at login toggle (uses LaunchAtLogin's built-in view)
            LaunchAtLogin.Toggle()

            Divider()

            // API key management
            HStack(spacing: 12) {
                Button("Change API Key") {
                    appState.hasAPIKey = false
                    #if DEBUG
                    print("[SettingsView] change API key — returning to setup view")
                    #endif
                }
                .buttonStyle(.borderless)

                Button("Remove API Key") {
                    showRemoveKeyAlert = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
        .alert("Remove API Key?", isPresented: $showRemoveKeyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                removeAPIKey()
            }
        } message: {
            Text("This will delete your API key from the config file and return to the setup screen.")
        }
    }

    // MARK: - Actions

    private func removeAPIKey() {
        ConfigFileCredentialProvider().clear()
        #if DEBUG
        print("[SettingsView] remove API key — config file entry cleared")
        #endif

        appState.usageStore.stopPolling()
        appState.usageStore.cachedData = nil
        appState.hasAPIKey = false
        appState.isConnected = false

        #if DEBUG
        print("[SettingsView] remove API key — state cleared, returning to setup view")
        #endif
    }
}
