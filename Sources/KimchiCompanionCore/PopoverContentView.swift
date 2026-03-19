import SwiftUI

/// Root view for the MenuBarExtra popover window.
/// Shows SetupView when no API key is configured,
/// or a minimal usage summary when connected.
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
                usageSummaryView
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

    // MARK: - Connected State — Usage Summary

    private var usageSummaryView: some View {
        VStack(spacing: 12) {
            // Stale indicator banner
            if appState.isStale {
                staleBanner
            }

            // Today's cost — the main metric
            VStack(spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.displayCost)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            // Loading indicator
            if appState.usageStore.isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            // Trigger refresh when popover appears
            await appState.refreshUsageData()
        }
    }

    // MARK: - Stale Banner

    private var staleBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Group {
                if let lastUpdated = appState.usageStore.lastUpdated {
                    Text("Data may be outdated · Last updated: \(lastUpdated, style: .relative)")
                } else {
                    Text("Data may be outdated")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}
