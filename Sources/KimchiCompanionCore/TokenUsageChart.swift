import SwiftUI

/// Bar chart showing daily token usage broken down by model.
/// Pure SwiftUI implementation to avoid Charts framework Metal shader initialization delay.
struct TokenUsageChart: View {
    var data: [TokenChartPoint]
    
    var body: some View {
        // Group by date, take last 7 unique dates
        let grouped = groupedByDate(data)
        let modelNames = Set(data.map { $0.model }).sorted()
        let maxTokens = data.map { $0.tokens }.max() ?? 1
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Token usage")
                .font(.headline)
            Text("Last \(grouped.count) days, broken down by model.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if grouped.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(grouped) { day in
                        VStack(spacing: 2) {
                            // Stacked bar
                            VStack(spacing: 1) {
                                ForEach(modelNames, id: \.self) { model in
                                    let tokens = day.tokensByModel[model] ?? 0
                                    if tokens > 0 {
                                        Rectangle()
                                            .fill(colorForModel(model))
                                            .frame(height: CGFloat(tokens) / CGFloat(max(maxTokens, 1)) * 80)
                                    }
                                }
                            }
                            .frame(width: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            
                            Text(shortDate(day.date))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(height: 120)
                
                // Legend
                HStack(spacing: 8) {
                    ForEach(modelNames.prefix(3), id: \.self) { model in
                        HStack(spacing: 2) {
                            Circle().fill(colorForModel(model)).frame(width: 6, height: 6)
                            Text(model)
                                .font(.system(size: 8))
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let tokensByModel: [String: Int]
    }
    
    private func groupedByDate(_ points: [TokenChartPoint]) -> [DayData] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        var dict: [String: [String: Int]] = [:]
        for point in points {
            let key = formatter.string(from: point.date)
            dict[key, default: [:]][point.model, default: 0] += point.tokens
        }
        
        let sortedKeys = dict.keys.sorted()
        let last7 = sortedKeys.suffix(7)
        
        return last7.map { key in
            let date = formatter.date(from: key) ?? Date()
            return DayData(date: date, tokensByModel: dict[key]!)
        }
    }
    
    private func colorForModel(_ model: String) -> Color {
        let colors: [Color] = [.orange, .yellow, .cyan, .purple, .green, .pink]
        var hash = 0
        for char in model { hash = char.hashValue }
        return colors[abs(hash) % colors.count]
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}