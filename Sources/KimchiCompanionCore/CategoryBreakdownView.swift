import SwiftUI

/// Displays a per-category cost breakdown (e.g. code-generation, summarization).
/// These are the "modules" — prompt categories identified by the AI Optimizer.
public struct CategoryBreakdownView: View {
    public let categories: [CategoryCostEntry]

    public init(categories: [CategoryCostEntry]) {
        self.categories = categories
    }

    public var body: some View {
        if categories.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                Text("Categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(sortedCategories, id: \.name) { entry in
                    categoryRow(entry)
                }
            }
        }
    }

    // MARK: - Computed

    private var totalCost: Decimal {
        categories.reduce(Decimal.zero) { $0 + $1.costDecimal }
    }

    private var sortedCategories: [CategoryCostEntry] {
        categories.sorted { $0.costDecimal > $1.costDecimal }
    }

    // MARK: - Row View

    private func categoryRow(_ entry: CategoryCostEntry) -> some View {
        HStack {
            Text(entry.name.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

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

    static func formatCurrency(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    private func formatPercent(_ cost: Decimal) -> String {
        guard totalCost > .zero else { return "—" }
        let ratio = (cost as NSDecimalNumber).doubleValue / (totalCost as NSDecimalNumber).doubleValue
        let percent = Int((ratio * 100).rounded())
        return "\(percent)%"
    }
}
