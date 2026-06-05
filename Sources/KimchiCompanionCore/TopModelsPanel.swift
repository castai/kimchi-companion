import SwiftUI

/// Panel showing top models by request count with percentage progress bars.
struct TopModelsPanel: View {
    let models: [TopModelRow]
    let totalRequests: Int

    // MARK: - Provider name mapping

    private func providerName(for model: String) -> String {
        let lower = model.lowercased()
        if lower.contains("claude") { return "Anthropic" }
        if lower.contains("kimi") { return "Moonshot AI" }
        if lower.contains("gpt") || lower.contains("o1") || lower.contains("o3") { return "OpenAI" }
        if lower.contains("gemini") { return "Google" }
        if lower.contains("deepseek") { return "DeepSeek" }
        if lower.contains("mistral") { return "Mistral AI" }
        if lower.contains("llama") { return "Meta" }
        if lower.contains("qwen") { return "Alibaba" }
        return ""
    }

    private var topModels: [TopModelRow] {
        Array(models.prefix(5))
    }

    private var averageTokensPerRequest: Int {
        guard totalRequests > 0 else { return 0 }
        let totalTokens = models.reduce(0) { $0 + $1.tokens }
        return totalTokens / totalRequests
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Top models")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("By request count, last 7 days.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if models.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(topModels, id: \.name) { row in
                        modelRow(row)
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                summaryRow
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No model data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }

    private func modelRow(_ row: TopModelRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if !providerName(for: row.name).isEmpty {
                        Text(providerName(for: row.name))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(formatPercent(row.sharePct))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: max(0, geo.size.width * CGFloat(row.sharePct / 100.0)), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            summaryItem(label: "Requests", value: formatNumber(totalRequests))
            summaryItem(label: "Avg tokens", value: formatNumber(averageTokensPerRequest))
            summaryItem(label: "Models", value: "\(models.count)")
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000.0)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000.0)
        } else {
            return "\(value)"
        }
    }
}