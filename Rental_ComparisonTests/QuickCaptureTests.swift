import XCTest
@testable import Rental_Comparison

@MainActor
final class QuickCaptureTests: XCTestCase {
    func testQuickCaptureAllowsNameAndPhotoWithoutRent() {
        var savedState: DecisionAppState?
        let store = AppStore(
            persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { savedState = $0 }),
            useFixtures: true
        )

        let optionID = store.captureOption(name: "仅有截图的候选", monthlyRent: nil, photoIDs: ["capture-photo"])

        XCTAssertEqual(store.state.options.first { $0.id == optionID }?.displayName, "仅有截图的候选")
        XCTAssertTrue(store.state.evidence.contains { $0.optionID == optionID && $0.mediaID == "capture-photo" })
        XCTAssertFalse(store.state.facts.contains { $0.optionID == optionID && $0.key == FactKey.monthlyRent })
        XCTAssertEqual(savedState?.events.last?.type, .captured)
    }

    func testLegacyZeroRentDoesNotBecomeMonthlyRentFact() {
        var legacy = Fixtures.initialState
        legacy.task.listings[0].rent = 0

        let migrated = DecisionModelMigration.migrate(legacy)

        XCTAssertFalse(migrated.facts.contains { $0.optionID == Fixtures.xuhuiID && $0.key == FactKey.monthlyRent })
    }
}
