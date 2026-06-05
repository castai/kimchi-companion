import SwiftUI

/// A row of 4 KPI cards showing requests, tokens, cost, and active model count
/// with optional trend badges.
struct OverviewKPIStrip: View {
    var requests: Int
    var tokens: Int
    var cost: Decimal
    var activeModels: Int
    var requestsTrend: Double?
    var costTrend: Double?
    var tokensTrend: Double?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                KPICard(
                    title: "Requests",
                    value: compactNumber(requests),
                    trend: requestsTrend
                )
                KPICard(
                    title: "Cost",
                    value: formatCost(cost),
                    trend: costTrend
                )
            }
            HStack(spacing: 8) {
                KPICard(
                    title: "Tokens",
                    value: compactNumber(tokens),
                    trend: tokensTrend
                )
                KPICard(
                    title: "Models",
                    value: "\(activeModels)",
                    trend: nil
                )
            }
        }
    }

    private func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: "%.1fK", thousands)
        } else {
            return "\(value)"
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        let number = NSDecimalNumber(decimal: cost)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: number) ?? "$0.00"
    }
}

/// A single KPI card with label, value, and optional trend badge.
struct KPICard: View {
    var title: String
    var value: String
    var trend: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let trend {
                    TrendBadge(value: trend)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}