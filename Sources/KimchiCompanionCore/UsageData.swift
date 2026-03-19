import Foundation

// MARK: - Org Usage Report

/// Top-level response from `GET /v1/llm/openai/chat-completions/reports/usage`.
public struct UsageReportResponse: Codable, Sendable {
    /// The time bucket size in seconds (typically 86400 for daily).
    public let stepSeconds: Int?
    /// Daily usage items. Empty array when no usage exists.
    public let items: [UsageReportItem]

    public init(stepSeconds: Int? = nil, items: [UsageReportItem]) {
        self.stepSeconds = stepSeconds
        self.items = items
    }
}

/// A single daily usage bucket in the org usage report.
public struct UsageReportItem: Codable, Sendable {
    /// ISO 8601 timestamp for the start of this bucket.
    public let timestamp: String
    /// Total daily cost as a string (e.g., "3.42").
    public let dailyCost: String
    /// Cost per million tokens as a string.
    public let dailyCostPerMilTokens: String?
    /// Cost breakdown per API key ID. Keys are API key IDs, values are cost strings.
    public let costPerApiKey: [String: String]?
    /// Cost breakdown per category. Keys are category names, values are cost strings.
    public let costPerCategory: [String: String]?

    public init(
        timestamp: String,
        dailyCost: String,
        dailyCostPerMilTokens: String? = nil,
        costPerApiKey: [String: String]? = nil,
        costPerCategory: [String: String]? = nil
    ) {
        self.timestamp = timestamp
        self.dailyCost = dailyCost
        self.dailyCostPerMilTokens = dailyCostPerMilTokens
        self.costPerApiKey = costPerApiKey
        self.costPerCategory = costPerCategory
    }

    /// Parsed daily cost as Decimal for arithmetic. Returns 0 if the string is malformed.
    public var dailyCostDecimal: Decimal {
        Decimal(string: dailyCost) ?? .zero
    }
}

// MARK: - Savings Report

/// Top-level response from `GET /v1/llm/openai/chat-completions/reports/api-keys-savings`.
public struct SavingsReportResponse: Codable, Sendable {
    /// Per-key savings items. Empty array when no usage exists.
    public let items: [SavingsReportItem]

    public init(items: [SavingsReportItem]) {
        self.items = items
    }
}

/// A single API key's savings data.
public struct SavingsReportItem: Codable, Sendable {
    /// The API key ID.
    public let id: String
    /// Human-readable alias for the key.
    public let alias: String?
    /// Total request count in the period.
    public let requestCount: Int
    /// Token counts broken down by direction.
    public let tokenCount: TokenCount
    /// Cost breakdown for this key.
    public let costs: SavingsItemCosts
    /// Recommended model cost data (may be absent).
    public let recommendedModelCosts: RecommendedModelCosts?
    /// LLM provider name (e.g., "openai").
    public let provider: String?
    /// Original cost before savings as a string.
    public let originalCost: String?
    /// Absolute savings amount as a string.
    public let achievedSavings: String?
    /// Savings as a percentage string (e.g., "15.0").
    public let achievedSavingsPercentage: String?
    /// Whether requests were routed through CAST AI.
    public let routed: Bool?

    public init(
        id: String,
        alias: String? = nil,
        requestCount: Int,
        tokenCount: TokenCount,
        costs: SavingsItemCosts,
        recommendedModelCosts: RecommendedModelCosts? = nil,
        provider: String? = nil,
        originalCost: String? = nil,
        achievedSavings: String? = nil,
        achievedSavingsPercentage: String? = nil,
        routed: Bool? = nil
    ) {
        self.id = id
        self.alias = alias
        self.requestCount = requestCount
        self.tokenCount = tokenCount
        self.costs = costs
        self.recommendedModelCosts = recommendedModelCosts
        self.provider = provider
        self.originalCost = originalCost
        self.achievedSavings = achievedSavings
        self.achievedSavingsPercentage = achievedSavingsPercentage
        self.routed = routed
    }
}

/// Token counts by direction (input vs output).
public struct TokenCount: Codable, Sendable, Equatable {
    /// Input (prompt) tokens.
    public let `in`: Int
    /// Output (completion) tokens.
    public let out: Int

    public init(in inTokens: Int, out: Int) {
        self.`in` = inTokens
        self.out = out
    }
}

/// Cost breakdown for a single savings report item.
public struct SavingsItemCosts: Codable, Sendable {
    /// Daily cost as a string.
    public let daily: String
    /// Total cost as a string.
    public let total: String
    /// Total cost per input token as a string.
    public let totalPerTokensIn: String?
    /// Total cost per output token as a string.
    public let totalPerTokensOut: String?
    /// Cost per million tokens as a string.
    public let perMilTokens: String?
    /// Cost per million input tokens as a string.
    public let perMilTokensIn: String?
    /// Cost per million output tokens as a string.
    public let perMilTokensOut: String?

    public init(
        daily: String,
        total: String,
        totalPerTokensIn: String? = nil,
        totalPerTokensOut: String? = nil,
        perMilTokens: String? = nil,
        perMilTokensIn: String? = nil,
        perMilTokensOut: String? = nil
    ) {
        self.daily = daily
        self.total = total
        self.totalPerTokensIn = totalPerTokensIn
        self.totalPerTokensOut = totalPerTokensOut
        self.perMilTokens = perMilTokens
        self.perMilTokensIn = perMilTokensIn
        self.perMilTokensOut = perMilTokensOut
    }

    /// Parsed daily cost as Decimal for arithmetic. Returns 0 if the string is malformed.
    public var dailyDecimal: Decimal {
        Decimal(string: daily) ?? .zero
    }

    /// Parsed total cost as Decimal for arithmetic. Returns 0 if the string is malformed.
    public var totalDecimal: Decimal {
        Decimal(string: total) ?? .zero
    }
}

/// Recommended model cost suggestion from CAST AI.
public struct RecommendedModelCosts: Codable, Sendable {
    /// Recommended daily cost as a string.
    public let daily: String
    /// Recommended total cost as a string.
    public let total: String

    public init(daily: String, total: String) {
        self.daily = daily
        self.total = total
    }
}

// MARK: - Cached Usage Data

/// Combined usage data from both API endpoints, shaped for UI display and cache persistence.
///
/// This is the single struct that gets written to `usage-cache.json` and read by the UI layer.
/// All cost fields are strings with computed Decimal properties for arithmetic.
public struct CachedUsageData: Codable, Sendable, Equatable {
    /// Today's total cost as a string (e.g., "3.42").
    public let todayCost: String
    /// This week's total cost as a string.
    public let weekCost: String

    /// Today's total input tokens.
    public let todayTokensIn: Int
    /// Today's total output tokens.
    public let todayTokensOut: Int
    /// Today's total request count.
    public let todayRequests: Int

    /// This week's total input tokens.
    public let weekTokensIn: Int
    /// This week's total output tokens.
    public let weekTokensOut: Int
    /// This week's total request count.
    public let weekRequests: Int

    /// Per-model cost breakdown for the period.
    public let modelBreakdown: [ModelCostEntry]

    /// When this data was last successfully fetched from the API.
    public let lastUpdated: Date

    public init(
        todayCost: String,
        weekCost: String,
        todayTokensIn: Int,
        todayTokensOut: Int,
        todayRequests: Int,
        weekTokensIn: Int,
        weekTokensOut: Int,
        weekRequests: Int,
        modelBreakdown: [ModelCostEntry],
        lastUpdated: Date
    ) {
        self.todayCost = todayCost
        self.weekCost = weekCost
        self.todayTokensIn = todayTokensIn
        self.todayTokensOut = todayTokensOut
        self.todayRequests = todayRequests
        self.weekTokensIn = weekTokensIn
        self.weekTokensOut = weekTokensOut
        self.weekRequests = weekRequests
        self.modelBreakdown = modelBreakdown
        self.lastUpdated = lastUpdated
    }

    // MARK: - Computed Decimal Properties

    /// Parsed today cost as Decimal. Returns 0 if the string is malformed.
    public var todayCostDecimal: Decimal {
        Decimal(string: todayCost) ?? .zero
    }

    /// Parsed week cost as Decimal. Returns 0 if the string is malformed.
    public var weekCostDecimal: Decimal {
        Decimal(string: weekCost) ?? .zero
    }
}

/// A single entry in the model cost breakdown.
public struct ModelCostEntry: Codable, Sendable, Equatable {
    /// Model or provider name (e.g., "openai", key alias, or key ID).
    public let name: String
    /// Cost attributed to this model as a string.
    public let cost: String

    public init(name: String, cost: String) {
        self.name = name
        self.cost = cost
    }

    /// Parsed cost as Decimal. Returns 0 if the string is malformed.
    public var costDecimal: Decimal {
        Decimal(string: cost) ?? .zero
    }
}
