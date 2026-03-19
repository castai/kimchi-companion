import SwiftUI

/// Root view for the MenuBarExtra popover window.
/// Shows SetupView when no API key is configured,
/// or the full usage dashboard when connected: stale banner, today/week sections,
/// model breakdown, Open Dashboard link, and quit button.
public struct PopoverContentView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Kimchi Companion")
                .font(.headline)
                .padding(.bottom, 12)

            Divider()

            if !appState.hasAPIKey {
                SetupView()
                    .padding(.top, 12)
                Spacer()
            } else {
                usageDashboardView
            }

            Divider()

            // Quit button — essential for no-Dock apps that lack
            // the standard app menu and Cmd+Q shortcut.
            Button("Quit Kimchi Companion") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 300)
    }

    // MARK: - Connected State — Full Usage Dashboard

    private var usageDashboardView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Stale indicator banner
                if appState.isStale {
                    staleBanner
                }

                // Today section
                UsageView(
                    title: "Today",
                    cost: appState.usageStore.todayCost,
                    tokensIn: appState.usageStore.todayTokensIn,
                    tokensOut: appState.usageStore.todayTokensOut,
                    requests: appState.usageStore.todayRequests
                )

                Divider()

                // This Week section
                UsageView(
                    title: "This Week",
                    cost: appState.usageStore.weekCost,
                    tokensIn: appState.usageStore.weekTokensIn,
                    tokensOut: appState.usageStore.weekTokensOut,
                    requests: appState.usageStore.weekRequests
                )

                Divider()

                // Per-model cost breakdown (renders nothing when empty)
                ModelBreakdownView(
                    models: appState.usageStore.cachedData?.modelBreakdown ?? []
                )

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

                // Last updated timestamp
                if let lastUpdated = appState.usageStore.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Open Dashboard link
                Button {
                    NSWorkspace.shared.open(URL(string: "https://inference.cast.ai")!)
                } label: {
                    HStack(spacing: 4) {
                        Text("Open Dashboard")
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)

                Divider()

                // Inline settings section
                SettingsView()
            }
            .padding(.vertical, 12)
        }
        .task {
            // Trigger refresh when popover appears, then start polling
            await appState.refreshUsageData()
            if let apiKey = KeychainManager().retrieve() {
                appState.usageStore.startPolling(
                    intervalSeconds: appState.preferencesStore.refreshInterval.rawValue,
                    apiKey: apiKey
                )
            }
        }
        .onChange(of: appState.preferencesStore.refreshInterval) { _, newInterval in
            // Restart polling with the new interval
            if let apiKey = KeychainManager().retrieve() {
                appState.usageStore.startPolling(
                    intervalSeconds: newInterval.rawValue,
                    apiKey: apiKey
                )
            }
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
