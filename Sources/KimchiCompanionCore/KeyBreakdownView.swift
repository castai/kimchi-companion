import SwiftUI

/// Displays a per-API-key usage breakdown with costs, tokens, and percentages.
///
/// Used in the "Team" scope to show how usage is distributed across API keys.
/// Renders nothing when the key list is empty.
public struct KeyBreakdownView: View {
    public let keys: [APIKeyUsageEntry]

    public init(keys: [APIKeyUsageEntry]) {
        self.keys = keys
    }

    public var body: some View {
        if keys.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                // Section header
                Text("API Keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Key rows sorted by cost descending
                ForEach(sortedKeys, id: \.id) { entry in
                    keyRow(entry)
                }
            }
        }
    }

    // MARK: - Computed

    private var totalCost: Decimal {
        keys.reduce(Decimal.zero) { $0 + $1.costDecimal }
    }

    private var sortedKeys: [APIKeyUsageEntry] {
        keys.sorted { $0.costDecimal > $1.costDecimal }
    }

    // MARK: - Row View

    private func keyRow(_ entry: APIKeyUsageEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(Self.formatCurrency(entry.costDecimal))
                    .font(.caption)
                    .monospacedDigit()

                Text(formatPercent(entry.costDecimal))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Text("\(Self.formatNumber(entry.tokensIn)) in · \(Self.formatNumber(entry.tokensOut)) out")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("\(Self.formatNumber(entry.requests)) req")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Cost proportion bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(0.3))
                    .frame(width: barWidth(for: entry.costDecimal, in: geo.size.width))
                    .frame(height: 3)
            }
            .frame(height: 3)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Formatting

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func formatCurrency(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    static func formatNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatPercent(_ cost: Decimal) -> String {
        guard totalCost > .zero else { return "—" }
        let ratio = (cost as NSDecimalNumber).doubleValue / (totalCost as NSDecimalNumber).doubleValue
        let percent = Int((ratio * 100).rounded())
        return "\(percent)%"
    }

    private func barWidth(for cost: Decimal, in totalWidth: CGFloat) -> CGFloat {
        guard totalCost > .zero else { return 0 }
        let ratio = (cost as NSDecimalNumber).doubleValue / (totalCost as NSDecimalNumber).doubleValue
        return max(2, CGFloat(ratio) * totalWidth)
    }
}
