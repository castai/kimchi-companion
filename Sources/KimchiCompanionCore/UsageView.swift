import SwiftUI

/// Reusable section that displays usage data for a single period (e.g. today or this week).
///
/// Shows a large cost figure, tokens in/out with thousands separators, and a request count.
/// Purely presentational — receives all data as parameters, does not observe stores.
public struct UsageView: View {
    public let title: String
    public let cost: Decimal
    public let tokensIn: Int
    public let tokensOut: Int
    public let requests: Int

    public init(
        title: String,
        cost: Decimal,
        tokensIn: Int,
        tokensOut: Int,
        requests: Int
    ) {
        self.title = title
        self.cost = cost
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.requests = requests
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Section title
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Large cost display
            Text(Self.formatCurrency(cost))
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            // Tokens: "12,847 in · 3,201 out"
            Text("\(Self.formatNumber(tokensIn)) in · \(Self.formatNumber(tokensOut)) out")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Requests: "1,234 requests"
            Text("\(Self.formatNumber(requests)) requests")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Formatters

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

    /// Format a Decimal as USD currency (e.g. "$4.20").
    static func formatCurrency(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    /// Format an integer with thousands separators (e.g. "12,847").
    static func formatNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
