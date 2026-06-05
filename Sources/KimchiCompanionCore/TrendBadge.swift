import SwiftUI

/// A compact badge showing a percentage change with directional arrow and color.
/// Hidden when `value` is nil.
struct TrendBadge: View {
    var value: Double?

    var body: some View {
        if let value {
            let isPositive = value >= 0
            let color: Color = isPositive ? .green : .red
            let arrow = isPositive ? "↑" : "↓"
            Text("\(arrow) \(abs(value), specifier: "%.1f")%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}