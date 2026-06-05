import SwiftUI

/// Root view for the MenuBarExtra popover window.
/// Shows SetupView when no API key is configured,
/// or the full usage dashboard when connected: org selector, KPI strip,
/// module breakdown, per-key breakdown, Open Dashboard link, and quit button.
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
        .frame(minWidth: 320, maxWidth: 500)
    }

    // MARK: - Connected State — Full Usage Dashboard

    private var usageDashboardView: some View {
        VStack(spacing: 12) {
            // Stale indicator banner
            if appState.isStale {
                staleBanner
            }

            // Organization picker
            OrganizationPicker(
                selectedId: appState.preferencesStore.selectedOrganizationId,
                organizations: appState.organizations,
                isLoading: appState.isLoadingOrganizations,
                onSelect: { id in
                    appState.selectOrganization(id: id)
                }
            )

            // You / Org toggle (shown only when an org is selected)
            if appState.preferencesStore.selectedOrganizationId != nil {
                OverviewTabToggle(
                    tab: appState.preferencesStore.overviewTab,
                    onChange: { tab in
                        appState.preferencesStore.overviewTab = tab
                        Task { await appState.refreshUsageData() }
                    }
                )

                // KPI strip (org-scoped data from analytics API)
                OverviewKPIStrip(
                    requests: appState.usageStore.cachedData?.totalRequests ?? 0,
                    tokens: appState.usageStore.cachedData?.totalTokens ?? 0,
                    cost: appState.usageStore.todayCost,
                    activeModels: appState.usageStore.cachedData?.activeModels ?? 0,
                    requestsTrend: appState.usageStore.cachedData?.requestsTrend,
                    costTrend: appState.usageStore.cachedData?.costTrend,
                    tokensTrend: appState.usageStore.cachedData?.tokensTrend
                )

                // Token usage chart + Top models (org-scoped)
                HStack(alignment: .top, spacing: 12) {
                    TokenUsageChart(data: appState.usageStore.cachedData?.tokenChartData ?? [])
                        .frame(maxWidth: .infinity)
                    TopModelsPanel(
                        models: Array((appState.usageStore.cachedData?.topModels ?? []).prefix(5)),
                        totalRequests: appState.usageStore.cachedData?.totalRequests ?? 0
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Personal scope — show the classic scoped dashboard
                scopePicker

                switch appState.selectedScope {
                case .global:
                    globalScopeView
                case .team:
                    teamScopeView
                case .individual:
                    individualScopeView
                }
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

            // Last updated timestamp
            if let lastUpdated = appState.usageStore.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Open Dashboard link
            Button {
                NSWorkspace.shared.open(URL(string: "https://kimchi.console.cast.ai")!)
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
        .task {
            // Trigger refresh when popover appears, then start polling
            await appState.refreshUsageData()
            if let apiKey = ConfigFileCredentialProvider().read() {
                appState.usageStore.startPolling(
                    intervalSeconds: appState.preferencesStore.refreshInterval.rawValue,
                    apiKey: apiKey
                )
            }
        }
        .onChange(of: appState.preferencesStore.refreshInterval) { _, newInterval in
            // Restart polling with the new interval
            if let apiKey = ConfigFileCredentialProvider().read() {
                appState.usageStore.startPolling(
                    intervalSeconds: newInterval.rawValue,
                    apiKey: apiKey
                )
            }
        }
    }

    // MARK: - Overview Tab Toggle

    private func OverviewTabToggle(tab: PreferencesStore.OverviewTab, onChange: @escaping (PreferencesStore.OverviewTab) -> Void) -> some View {
        Picker("Tab", selection: Binding(
            get: { tab },
            set: { onChange($0) }
        )) {
            Text("You").tag(PreferencesStore.OverviewTab.you)
            Text("Org").tag(PreferencesStore.OverviewTab.org)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - Scope Picker

    private var scopePicker: some View {
        @Bindable var state = appState
        return Picker("Scope", selection: $state.selectedScope) {
            ForEach(UsageScope.allCases) { scope in
                Text(scope.displayName).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - Global Scope (Org-wide)

    private var globalScopeView: some View {
        VStack(spacing: 12) {
            // Savings summary banner
            if let savings = appState.usageStore.cachedData?.savingsSummary {
                SavingsView(savings: savings)
                Divider()
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

            // Per-category cost breakdown (modules)
            CategoryBreakdownView(
                categories: appState.usageStore.cachedData?.categoryBreakdown ?? []
            )

            // Per-model cost breakdown
            ModelBreakdownView(
                models: appState.usageStore.cachedData?.modelBreakdown ?? []
            )
        }
    }

    // MARK: - Team Scope (All API Keys)

    private var teamScopeView: some View {
        let keys = appState.usageStore.cachedData?.keyBreakdown ?? []

        return VStack(spacing: 12) {
            // Aggregated team totals (same as global)
            UsageView(
                title: "Team Total",
                cost: appState.usageStore.weekCost,
                tokensIn: appState.usageStore.weekTokensIn,
                tokensOut: appState.usageStore.weekTokensOut,
                requests: appState.usageStore.weekRequests
            )

            Divider()

            // Per-key breakdown
            if keys.isEmpty {
                Text("No API key data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                KeyBreakdownView(keys: keys)
            }
        }
    }

    // MARK: - Individual Scope (Single Key)

    private var individualScopeView: some View {
        let keys = appState.usageStore.cachedData?.keyBreakdown ?? []

        return VStack(spacing: 12) {
            if keys.isEmpty {
                Text("No API key data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Key selector
                keyPicker(keys: keys)

                // Show selected key's data
                if let selectedKey = selectedKeyEntry(from: keys) {
                    UsageView(
                        title: selectedKey.displayName,
                        cost: selectedKey.costDecimal,
                        tokensIn: selectedKey.tokensIn,
                        tokensOut: selectedKey.tokensOut,
                        requests: selectedKey.requests
                    )
                } else {
                    Text("Select an API key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func keyPicker(keys: [APIKeyUsageEntry]) -> some View {
        @Bindable var state = appState
        return Picker("API Key", selection: $state.selectedKeyId) {
            Text("Select key…").tag(nil as String?)
            ForEach(keys, id: \.id) { key in
                Text(key.displayName).tag(key.id as String?)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .onAppear {
            // Auto-select first key if none selected
            if appState.selectedKeyId == nil, let first = keys.first {
                appState.selectedKeyId = first.id
            }
        }
    }

    private func selectedKeyEntry(from keys: [APIKeyUsageEntry]) -> APIKeyUsageEntry? {
        guard let id = appState.selectedKeyId else { return keys.first }
        return keys.first { $0.id == id } ?? keys.first
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