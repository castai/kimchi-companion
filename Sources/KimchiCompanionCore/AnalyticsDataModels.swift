import Foundation

// MARK: - Organization Models

/// A CAST AI organization.
public struct Organization: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

/// Response envelope for the list organizations endpoint.
public struct ListOrganizationsResponse: Codable, Sendable {
    public let organizations: [Organization]

    public init(organizations: [Organization]) {
        self.organizations = organizations
    }

    private enum CodingKeys: String, CodingKey {
        case organizations
    }
}

// MARK: - Generate Analytics Report Models

/// Top-level response from the generate analytics report endpoint.
public struct GenerateAnalyticsResponse: Codable, Sendable {
    public let apiCalls: AnalyticsMetric?
    public let inputTokens: AnalyticsMetric?
    public let outputTokens: AnalyticsMetric?
    public let cost: AnalyticsCostMetric?
    public let comparison: AnalyticsComparison?
    public let mostRecentTime: String?
    public let stepDuration: String

    public init(
        apiCalls: AnalyticsMetric?,
        inputTokens: AnalyticsMetric?,
        outputTokens: AnalyticsMetric?,
        cost: AnalyticsCostMetric?,
        comparison: AnalyticsComparison?,
        mostRecentTime: String?,
        stepDuration: String
    ) {
        self.apiCalls = apiCalls
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cost = cost
        self.comparison = comparison
        self.mostRecentTime = mostRecentTime
        self.stepDuration = stepDuration
    }

    private enum CodingKeys: String, CodingKey {
        case apiCalls
        case inputTokens
        case outputTokens
        case cost
        case comparison
        case mostRecentTime
        case stepDuration
    }
}

/// A metric containing per-model counts over time.
public struct AnalyticsMetric: Codable, Sendable {
    public let items: [AnalyticsMetricItem]

    public init(items: [AnalyticsMetricItem]) {
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

/// A single time-bucketed metric entry with per-model breakdown.
public struct AnalyticsMetricItem: Codable, Sendable {
    public let executionTime: String
    public let models: [AnalyticsModelCount]

    public init(executionTime: String, models: [AnalyticsModelCount]) {
        self.executionTime = executionTime
        self.models = models
    }

    private enum CodingKeys: String, CodingKey {
        case executionTime
        case models
    }
}

/// Count summary for a single model within a metric item.
public struct AnalyticsModelCount: Codable, Sendable {
    public let model: String
    public let totalCount: Int

    public init(model: String, totalCount: Int) {
        self.model = model
        self.totalCount = totalCount
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case totalCount
    }
}

/// A metric containing per-model cost entries over time.
public struct AnalyticsCostMetric: Codable, Sendable {
    public let items: [AnalyticsCostMetricItem]

    public init(items: [AnalyticsCostMetricItem]) {
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

/// A single time-bucketed cost entry with per-model breakdown.
public struct AnalyticsCostMetricItem: Codable, Sendable {
    public let executionTime: String
    public let models: [AnalyticsCostModelMetric]

    public init(executionTime: String, models: [AnalyticsCostModelMetric]) {
        self.executionTime = executionTime
        self.models = models
    }

    private enum CodingKeys: String, CodingKey {
        case executionTime
        case models
    }
}

/// Cost summary for a single model within a cost item.
public struct AnalyticsCostModelMetric: Codable, Sendable {
    public let model: String
    public let totalCost: String

    public init(model: String, totalCost: String) {
        self.model = model
        self.totalCost = totalCost
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case totalCost
    }
}

/// Comparison metrics showing period-over-period change.
public struct AnalyticsComparison: Codable, Sendable {
    public let apiCalls: AnalyticsComparisonItem?
    public let cost: AnalyticsComparisonItem?
    public let tokens: AnalyticsComparisonItem?

    public init(apiCalls: AnalyticsComparisonItem?, cost: AnalyticsComparisonItem?, tokens: AnalyticsComparisonItem?) {
        self.apiCalls = apiCalls
        self.cost = cost
        self.tokens = tokens
    }

    private enum CodingKeys: String, CodingKey {
        case apiCalls
        case cost
        case tokens
    }
}

/// A single comparison metric with its change percentage.
public struct AnalyticsComparisonItem: Codable, Sendable {
    public let changePercentage: Double?

    public init(changePercentage: Double?) {
        self.changePercentage = changePercentage
    }

    private enum CodingKeys: String, CodingKey {
        case changePercentage
    }
}

// MARK: - Token Chart Data

/// A single point in the token usage bar chart.
public struct TokenChartPoint: Codable, Sendable, Equatable, Identifiable {
    public let date: Date
    public let model: String
    public let tokens: Int

    /// Unique ID for Identifiable conformance in Charts — derived from date + model.
    public var id: String { "\(ISO8601DateFormatter().string(from: date))-\(model)" }

    public init(date: Date, model: String, tokens: Int) {
        self.date = date
        self.model = model
        self.tokens = tokens
    }
}

/// A single row in the top-models panel.
public struct TopModelRow: Codable, Sendable, Equatable {
    public let name: String
    public let requestCount: Int
    public let tokens: Int
    public let sharePct: Double

    public init(name: String, requestCount: Int, tokens: Int, sharePct: Double) {
        self.name = name
        self.requestCount = requestCount
        self.tokens = tokens
        self.sharePct = sharePct
    }
}