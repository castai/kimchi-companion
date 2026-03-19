import Foundation
import Testing

@testable import KimchiCompanionCore

// MARK: - JSON Decoder Helper

/// Shared decoder matching CastAPIClient's configuration.
private let apiDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}()

// MARK: - Org Usage Report Tests

@Suite("UsageReportResponse decoding")
struct UsageReportDecodingTests {

    @Test("Decodes normal response with multiple items and costPerApiKey")
    func normalResponse() throws {
        let json = """
        {
            "step_seconds": 86400,
            "items": [
                {
                    "timestamp": "2026-03-18T00:00:00Z",
                    "daily_cost": "5.67",
                    "daily_cost_per_mil_tokens": "0.23",
                    "cost_per_api_key": { "key-id-1": "3.20", "key-id-2": "2.47" },
                    "cost_per_category": { "chat": "4.00", "embeddings": "1.67" }
                },
                {
                    "timestamp": "2026-03-19T00:00:00Z",
                    "daily_cost": "3.42",
                    "daily_cost_per_mil_tokens": "0.15",
                    "cost_per_api_key": { "key-id-1": "2.10", "key-id-2": "1.32" },
                    "cost_per_category": { "chat": "1.50", "embeddings": "1.92" }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(UsageReportResponse.self, from: json)

        #expect(response.stepSeconds == 86400)
        #expect(response.items.count == 2)

        let firstItem = response.items[0]
        #expect(firstItem.timestamp == "2026-03-18T00:00:00Z")
        #expect(firstItem.dailyCost == "5.67")
        #expect(firstItem.dailyCostDecimal == Decimal(string: "5.67"))
        #expect(firstItem.costPerApiKey?["key-id-1"] == "3.20")
        #expect(firstItem.costPerApiKey?["key-id-2"] == "2.47")
        #expect(firstItem.costPerCategory?["chat"] == "4.00")

        let secondItem = response.items[1]
        #expect(secondItem.dailyCost == "3.42")
        #expect(secondItem.dailyCostDecimal == Decimal(string: "3.42"))
    }

    @Test("Decodes empty items array without crash")
    func emptyItems() throws {
        let json = """
        {
            "step_seconds": 86400,
            "items": []
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(UsageReportResponse.self, from: json)

        #expect(response.stepSeconds == 86400)
        #expect(response.items.isEmpty)
    }

    @Test("Decodes response with missing optional fields")
    func missingOptionalFields() throws {
        let json = """
        {
            "items": [
                {
                    "timestamp": "2026-03-19T00:00:00Z",
                    "daily_cost": "1.00"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(UsageReportResponse.self, from: json)

        #expect(response.stepSeconds == nil)
        #expect(response.items.count == 1)

        let item = response.items[0]
        #expect(item.dailyCostPerMilTokens == nil)
        #expect(item.costPerApiKey == nil)
        #expect(item.costPerCategory == nil)
        #expect(item.dailyCostDecimal == Decimal(string: "1.00"))
    }

    @Test("Malformed cost string returns zero Decimal")
    func malformedCostString() throws {
        let json = """
        {
            "items": [
                {
                    "timestamp": "2026-03-19T00:00:00Z",
                    "daily_cost": "not-a-number"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(UsageReportResponse.self, from: json)
        #expect(response.items[0].dailyCostDecimal == .zero)
    }
}

// MARK: - Savings Report Tests

@Suite("SavingsReportResponse decoding")
struct SavingsReportDecodingTests {

    @Test("Decodes normal response with all fields")
    func normalResponse() throws {
        let json = """
        {
            "items": [
                {
                    "id": "key-id-1",
                    "alias": "my-key",
                    "request_count": 150,
                    "token_count": { "in": 50000, "out": 12000 },
                    "costs": {
                        "daily": "1.20",
                        "total": "8.50",
                        "total_per_tokens_in": "0.0001",
                        "total_per_tokens_out": "0.0003",
                        "per_mil_tokens": "0.137",
                        "per_mil_tokens_in": "0.100",
                        "per_mil_tokens_out": "0.250"
                    },
                    "recommended_model_costs": {
                        "daily": "0.80",
                        "total": "5.60"
                    },
                    "provider": "openai",
                    "original_cost": "10.00",
                    "achieved_savings": "1.50",
                    "achieved_savings_percentage": "15.0",
                    "routed": true
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(SavingsReportResponse.self, from: json)

        #expect(response.items.count == 1)

        let item = response.items[0]
        #expect(item.id == "key-id-1")
        #expect(item.alias == "my-key")
        #expect(item.requestCount == 150)
        #expect(item.tokenCount == TokenCount(in: 50000, out: 12000))
        #expect(item.costs.daily == "1.20")
        #expect(item.costs.total == "8.50")
        #expect(item.costs.dailyDecimal == Decimal(string: "1.20"))
        #expect(item.costs.totalDecimal == Decimal(string: "8.50"))
        #expect(item.costs.totalPerTokensIn == "0.0001")
        #expect(item.costs.perMilTokens == "0.137")
        #expect(item.recommendedModelCosts?.daily == "0.80")
        #expect(item.recommendedModelCosts?.total == "5.60")
        #expect(item.provider == "openai")
        #expect(item.originalCost == "10.00")
        #expect(item.achievedSavings == "1.50")
        #expect(item.achievedSavingsPercentage == "15.0")
        #expect(item.routed == true)
    }

    @Test("Decodes empty items array")
    func emptyItems() throws {
        let json = """
        { "items": [] }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(SavingsReportResponse.self, from: json)
        #expect(response.items.isEmpty)
    }

    @Test("Decodes response with missing optional fields")
    func missingOptionalFields() throws {
        let json = """
        {
            "items": [
                {
                    "id": "key-id-2",
                    "request_count": 0,
                    "token_count": { "in": 0, "out": 0 },
                    "costs": {
                        "daily": "0.00",
                        "total": "0.00"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try apiDecoder.decode(SavingsReportResponse.self, from: json)

        #expect(response.items.count == 1)

        let item = response.items[0]
        #expect(item.id == "key-id-2")
        #expect(item.alias == nil)
        #expect(item.requestCount == 0)
        #expect(item.tokenCount == TokenCount(in: 0, out: 0))
        #expect(item.costs.daily == "0.00")
        #expect(item.costs.totalPerTokensIn == nil)
        #expect(item.costs.perMilTokens == nil)
        #expect(item.recommendedModelCosts == nil)
        #expect(item.provider == nil)
        #expect(item.originalCost == nil)
        #expect(item.achievedSavings == nil)
        #expect(item.routed == nil)
    }
}

// MARK: - CachedUsageData Round-Trip Tests

@Suite("CachedUsageData encoding/decoding")
struct CachedUsageDataTests {

    @Test("Round-trips through JSON encode/decode")
    func roundTrip() throws {
        let original = CachedUsageData(
            todayCost: "4.56",
            weekCost: "27.89",
            todayTokensIn: 100_000,
            todayTokensOut: 25_000,
            todayRequests: 350,
            weekTokensIn: 700_000,
            weekTokensOut: 175_000,
            weekRequests: 2400,
            modelBreakdown: [
                ModelCostEntry(name: "openai", cost: "3.00"),
                ModelCostEntry(name: "anthropic", cost: "1.56"),
            ],
            lastUpdated: Date(timeIntervalSince1970: 1_742_400_000) // fixed timestamp
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CachedUsageData.self, from: data)

        #expect(decoded == original)
        #expect(decoded.todayCost == "4.56")
        #expect(decoded.weekCost == "27.89")
        #expect(decoded.todayTokensIn == 100_000)
        #expect(decoded.todayTokensOut == 25_000)
        #expect(decoded.todayRequests == 350)
        #expect(decoded.weekTokensIn == 700_000)
        #expect(decoded.weekTokensOut == 175_000)
        #expect(decoded.weekRequests == 2400)
        #expect(decoded.modelBreakdown.count == 2)
        #expect(decoded.modelBreakdown[0].name == "openai")
        #expect(decoded.modelBreakdown[0].cost == "3.00")
        #expect(decoded.modelBreakdown[1].costDecimal == Decimal(string: "1.56"))
    }

    @Test("Computed Decimal properties work correctly")
    func decimalProperties() {
        let data = CachedUsageData(
            todayCost: "12.34",
            weekCost: "56.78",
            todayTokensIn: 0,
            todayTokensOut: 0,
            todayRequests: 0,
            weekTokensIn: 0,
            weekTokensOut: 0,
            weekRequests: 0,
            modelBreakdown: [],
            lastUpdated: Date()
        )

        #expect(data.todayCostDecimal == Decimal(string: "12.34"))
        #expect(data.weekCostDecimal == Decimal(string: "56.78"))
    }

    @Test("Malformed cost strings return zero Decimal")
    func malformedCosts() {
        let data = CachedUsageData(
            todayCost: "abc",
            weekCost: "",
            todayTokensIn: 0,
            todayTokensOut: 0,
            todayRequests: 0,
            weekTokensIn: 0,
            weekTokensOut: 0,
            weekRequests: 0,
            modelBreakdown: [ModelCostEntry(name: "test", cost: "xyz")],
            lastUpdated: Date()
        )

        #expect(data.todayCostDecimal == .zero)
        #expect(data.weekCostDecimal == .zero)
        #expect(data.modelBreakdown[0].costDecimal == .zero)
    }
}

// MARK: - CastAPIClient Error Type Tests

@Suite("APIClientError descriptions")
struct APIClientErrorTests {

    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let networkErr = APIClientError.networkError("timeout")
        #expect(networkErr.errorDescription?.contains("timeout") == true)

        let authErr = APIClientError.unauthorized
        #expect(authErr.errorDescription?.contains("API key") == true)

        let serverErr = APIClientError.serverError(500)
        #expect(serverErr.errorDescription?.contains("500") == true)

        let decodeErr = APIClientError.decodingError("missing field")
        #expect(decodeErr.errorDescription?.contains("missing field") == true)
    }
}
