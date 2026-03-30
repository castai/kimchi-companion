import SwiftUI

/// Displays the savings summary: achieved savings, potential additional savings.
/// Shows a compact banner when savings data is available.
public struct SavingsView: View {
    public let savings: CachedSavingsSummary

    public init(savings: CachedSavingsSummary) {
        self.savings = savings
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text("Savings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Achieved savings
            if savings.achievedSavingsDecimal > .zero {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Saved \(Self.formatCurrency(savings.achievedSavingsDecimal))")
                        .font(.caption)
                        .fontWeight(.medium)

                    if let pct = Double(savings.achievedSavingsPercentage), pct > 0 {
                        Text("(\(Int(pct.rounded()))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            // Potential additional savings
            if savings.potentialSavingsDecimal > .zero {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Could save \(Self.formatCurrency(savings.potentialSavingsDecimal)) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            // Cost comparison bar
            if savings.originalCostDecimal > .zero {
                costComparisonBar
            }
        }
    }

    // MARK: - Cost Comparison

    private var costComparisonBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Original")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(Self.formatCurrency(savings.originalCostDecimal))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 4) {
                Text("Actual")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.formatCurrency(savings.actualCostDecimal))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if savings.potentialSavingsDecimal > .zero {
                HStack(spacing: 4) {
                    Text("Recommended")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Spacer()
                    Text(Self.formatCurrency(savings.recommendedCostDecimal))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
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
}
