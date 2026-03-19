import SwiftUI

/// Displays a per-model cost breakdown with percentages of total spend.
///
/// Accepts `[ModelCostEntry]` from UsageData and computes percentages internally.
/// Renders nothing when the model list is empty. Handles zero total cost gracefully.
public struct ModelBreakdownView: View {
    public let models: [ModelCostEntry]

    public init(models: [ModelCostEntry]) {
        self.models = models
    }

    public var body: some View {
        if models.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                // Section header
                Text("Models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Model rows sorted by cost descending
                ForEach(sortedModels, id: \.name) { entry in
                    modelRow(entry)
                }
            }
        }
    }

    // MARK: - Computed

    private var totalCost: Decimal {
        models.reduce(Decimal.zero) { $0 + $1.costDecimal }
    }

    private var sortedModels: [ModelCostEntry] {
        models.sorted { $0.costDecimal > $1.costDecimal }
    }

    // MARK: - Row View

    private func modelRow(_ entry: ModelCostEntry) -> some View {
        HStack {
            Text(entry.name)
                .font(.caption)
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

    /// Format a Decimal as USD currency (e.g. "$1.50").
    static func formatCurrency(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    /// Format a model's cost as percentage of total (e.g. "75%").
    /// Returns "—" when total cost is zero.
    private func formatPercent(_ cost: Decimal) -> String {
        guard totalCost > .zero else { return "—" }
        // Compute percentage as integer: (cost / total) * 100
        let ratio = (cost as NSDecimalNumber).doubleValue / (totalCost as NSDecimalNumber).doubleValue
        let percent = Int((ratio * 100).rounded())
        return "\(percent)%"
    }
}
