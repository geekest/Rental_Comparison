import XCTest
@testable import Rental_Comparison

final class DecisionEngineTests: XCTestCase {
    func testRefundableDepositOnlyEntersFirstCash() {
        let listing = Fixtures.initialState.task.listings[1]
        let result = DecisionEngine.calculateCosts(for: listing, expectedMonths: 12)
        XCTAssertEqual(result.monthlyHousing, 8_380, accuracy: 0.01)
        XCTAssertEqual(result.firstCash, 8_200, accuracy: 0.01)
    }

    func testUnknownCostIsNotTreatedAsZero() {
        let listing = Fixtures.initialState.task.listings[2]
        let result = DecisionEngine.calculateCosts(for: listing, expectedMonths: 12)
        XCTAssertTrue(result.unknowns.contains("押金"))
    }

    func testPeriodicCostsNormalizeToMonthlyAmount() {
        var listing = Fixtures.initialState.task.listings[0]
        listing.costs = [
            .init(name: "每日", amount: 10, cadence: .daily, refundable: false, confirmed: true),
            .init(name: "季度", amount: 300, cadence: .quarterly, refundable: false, confirmed: true),
            .init(name: "半年", amount: 600, cadence: .semiAnnual, refundable: false, confirmed: true),
            .init(name: "年度", amount: 1_200, cadence: .annual, refundable: false, confirmed: true)
        ]
        XCTAssertEqual(DecisionEngine.calculateCosts(for: listing, expectedMonths: 12).monthlyFees, 600, accuracy: 0.01)
    }

    func testEliminatedListingLeavesComparisonAndBaseline() {
        var task = Fixtures.initialState.task
        task.listings[0].status = .eliminated
        DecisionEngine.normalize(&task)
        XCTAssertFalse(task.comparisonIDs.contains(Fixtures.xuhuiID))
        XCTAssertEqual(task.baselineID, Fixtures.jinganID)
    }

    func testComparisonIsLimitedToFive() {
        var task = Fixtures.initialState.task
        task.listings = (0..<6).map { index in
            Listing(id: UUID(), name: "房源 \(index)", city: "上海", rentalType: .entire, rent: 1_000)
        }
        task.comparisonIDs = task.listings.map(\.id)
        DecisionEngine.normalize(&task)
        XCTAssertEqual(task.comparisonIDs.count, 5)
    }

    func testReportDoesNotContainImageFields() {
        var state = Fixtures.initialState
        state.task.finalListingID = Fixtures.xuhuiID
        let report = ReportBuilder.html(for: state)
        XCTAssertFalse(report.contains("photoIDs"))
        XCTAssertFalse(report.contains("bundledImageName"))
        XCTAssertTrue(report.contains("徐汇 · 一室一厅"))
    }

    func testPersistenceRoundTrip() throws {
        var savedData = Data()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let client = PersistenceClient(
            load: { savedData.isEmpty ? nil : try decoder.decode(AppState.self, from: savedData) },
            save: { savedData = try encoder.encode($0) }
        )
        var state = Fixtures.initialState
        state.privacyAcknowledged = true
        try client.save(state)
        XCTAssertEqual(try client.load(), state)
    }
}
