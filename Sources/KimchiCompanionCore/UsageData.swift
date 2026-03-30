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
public struct SavingsItemCosts: Codable, Sendable, Equatable {
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
public struct RecommendedModelCosts: Codable, Sendable, Equatable {
    /// Recommended daily cost as a string.
    public let daily: String
    /// Recommended total cost as a string.
    public let total: String

    public init(daily: String, total: String) {
        self.daily = daily
        self.total = total
    }
}

// MARK: - Per-Key Usage Report

/// Top-level response from `GET /v1/llm/openai/chat-completions/reports/api-keys/{id}/usage`.
public struct APIKeyUsageReportResponse: Codable, Sendable {
    /// Time bucket size in seconds.
    public let stepSeconds: Int?
    /// Daily usage items for this key.
    public let items: [APIKeyUsageItem]

    public init(stepSeconds: Int? = nil, items: [APIKeyUsageItem]) {
        self.stepSeconds = stepSeconds
        self.items = items
    }
}

/// A single daily usage bucket for a specific API key.
public struct APIKeyUsageItem: Codable, Sendable {
    /// ISO 8601 timestamp.
    public let timestamp: String
    /// Daily cost as a string.
    public let dailyCost: String
    /// Cost per million tokens.
    public let dailyCostPerMilTokens: String?
    /// Request count.
    public let requestCount: Int?
    /// Token counts.
    public let tokenCount: TokenCount?

    public init(
        timestamp: String,
        dailyCost: String,
        dailyCostPerMilTokens: String? = nil,
        requestCount: Int? = nil,
        tokenCount: TokenCount? = nil
    ) {
        self.timestamp = timestamp
        self.dailyCost = dailyCost
        self.dailyCostPerMilTokens = dailyCostPerMilTokens
        self.requestCount = requestCount
        self.tokenCount = tokenCount
    }

    public var dailyCostDecimal: Decimal {
        Decimal(string: dailyCost) ?? .zero
    }
}

// MARK: - Recommendations Report

/// Top-level response from `GET /v1/llm/openai/chat-completions/reports/recommendations`.
public struct RecommendationsReportResponse: Codable, Sendable {
    /// Whether the organization has completed onboarding.
    public let isOnboarded: Bool?
    /// Aggregated savings summary across all models.
    public let summary: RecommendationsSummary?
    /// Per-model recommendation items.
    public let items: [RecommendationsItem]

    public init(isOnboarded: Bool? = nil, summary: RecommendationsSummary? = nil, items: [RecommendationsItem]) {
        self.isOnboarded = isOnboarded
        self.summary = summary
        self.items = items
    }
}

/// Aggregated savings summary from the recommendations report.
public struct RecommendationsSummary: Codable, Sendable, Equatable {
    /// Current actual costs.
    public let costs: SavingsItemCosts?
    /// What costs would be with recommended models.
    public let recommendedModelCosts: RecommendedModelCosts?
    /// Original cost before any optimization as a string.
    public let originalCost: String?
    /// Absolute savings achieved as a string.
    public let achievedSavings: String?
    /// Savings as a percentage string (e.g., "15.0").
    public let achievedSavingsPercentage: String?

    public init(
        costs: SavingsItemCosts? = nil,
        recommendedModelCosts: RecommendedModelCosts? = nil,
        originalCost: String? = nil,
        achievedSavings: String? = nil,
        achievedSavingsPercentage: String? = nil
    ) {
        self.costs = costs
        self.recommendedModelCosts = recommendedModelCosts
        self.originalCost = originalCost
        self.achievedSavings = achievedSavings
        self.achievedSavingsPercentage = achievedSavingsPercentage
    }
}

/// A single model recommendation item.
public struct RecommendationsItem: Codable, Sendable, Equatable {
    /// Recommendation ID.
    public let id: String
    /// Category name for this recommendation.
    public let category: String?
    /// Request count in the period.
    public let requestCount: Int?
    /// Token counts.
    public let tokenCount: TokenCount?
    /// Actual costs.
    public let costs: SavingsItemCosts?
    /// Recommended model costs.
    public let recommendedModelCosts: RecommendedModelCosts?
    /// Original cost before optimization.
    public let originalCost: String?
    /// Absolute savings achieved.
    public let achievedSavings: String?
    /// Savings percentage.
    public let achievedSavingsPercentage: String?
    /// Whether this model is routed.
    public let routed: Bool?
    /// Original model name.
    public let originalModel: String?

    public init(
        id: String,
        category: String? = nil,
        requestCount: Int? = nil,
        tokenCount: TokenCount? = nil,
        costs: SavingsItemCosts? = nil,
        recommendedModelCosts: RecommendedModelCosts? = nil,
        originalCost: String? = nil,
        achievedSavings: String? = nil,
        achievedSavingsPercentage: String? = nil,
        routed: Bool? = nil,
        originalModel: String? = nil
    ) {
        self.id = id
        self.category = category
        self.requestCount = requestCount
        self.tokenCount = tokenCount
        self.costs = costs
        self.recommendedModelCosts = recommendedModelCosts
        self.originalCost = originalCost
        self.achievedSavings = achievedSavings
        self.achievedSavingsPercentage = achievedSavingsPercentage
        self.routed = routed
        self.originalModel = originalModel
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

    /// Per-API-key usage breakdown for team/individual scope views.
    public let keyBreakdown: [APIKeyUsageEntry]

    /// Per-category cost breakdown from the usage report.
    public let categoryBreakdown: [CategoryCostEntry]

    /// Savings summary: achieved savings, potential savings, percentage.
    public let savingsSummary: CachedSavingsSummary?

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
        keyBreakdown: [APIKeyUsageEntry] = [],
        categoryBreakdown: [CategoryCostEntry] = [],
        savingsSummary: CachedSavingsSummary? = nil,
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
        self.keyBreakdown = keyBreakdown
        self.categoryBreakdown = categoryBreakdown
        self.savingsSummary = savingsSummary
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

/// Per-API-key usage entry for team/individual scope views.
public struct APIKeyUsageEntry: Codable, Sendable, Equatable {
    /// API key ID.
    public let id: String
    /// Human-readable alias (falls back to truncated ID).
    public let displayName: String
    /// Total cost for this key as a string.
    public let cost: String
    /// Input tokens for this key.
    public let tokensIn: Int
    /// Output tokens for this key.
    public let tokensOut: Int
    /// Request count for this key.
    public let requests: Int

    public init(id: String, displayName: String, cost: String, tokensIn: Int, tokensOut: Int, requests: Int) {
        self.id = id
        self.displayName = displayName
        self.cost = cost
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.requests = requests
    }

    /// Parsed cost as Decimal.
    public var costDecimal: Decimal {
        Decimal(string: cost) ?? .zero
    }
}

/// Per-category cost entry from the usage report's costPerCategory field.
public struct CategoryCostEntry: Codable, Sendable, Equatable {
    /// Category name (e.g. "code-generation", "summarization").
    public let name: String
    /// Total cost for this category as a string.
    public let cost: String

    public init(name: String, cost: String) {
        self.name = name
        self.cost = cost
    }

    /// Parsed cost as Decimal.
    public var costDecimal: Decimal {
        Decimal(string: cost) ?? .zero
    }
}

/// Cached savings summary from the recommendations endpoint.
public struct CachedSavingsSummary: Codable, Sendable, Equatable {
    /// Current actual total cost as a string.
    public let actualCost: String
    /// Original cost before optimization as a string.
    public let originalCost: String
    /// Absolute savings achieved as a string.
    public let achievedSavings: String
    /// Savings as a percentage string (e.g., "15.0").
    public let achievedSavingsPercentage: String
    /// What costs would be with recommended models.
    public let recommendedCost: String
    /// Potential additional savings (recommended vs actual).
    public let potentialSavings: String

    public init(
        actualCost: String,
        originalCost: String,
        achievedSavings: String,
        achievedSavingsPercentage: String,
        recommendedCost: String,
        potentialSavings: String
    ) {
        self.actualCost = actualCost
        self.originalCost = originalCost
        self.achievedSavings = achievedSavings
        self.achievedSavingsPercentage = achievedSavingsPercentage
        self.recommendedCost = recommendedCost
        self.potentialSavings = potentialSavings
    }

    public var achievedSavingsDecimal: Decimal { Decimal(string: achievedSavings) ?? .zero }
    public var potentialSavingsDecimal: Decimal { Decimal(string: potentialSavings) ?? .zero }
    public var actualCostDecimal: Decimal { Decimal(string: actualCost) ?? .zero }
    public var originalCostDecimal: Decimal { Decimal(string: originalCost) ?? .zero }
    public var recommendedCostDecimal: Decimal { Decimal(string: recommendedCost) ?? .zero }
}
