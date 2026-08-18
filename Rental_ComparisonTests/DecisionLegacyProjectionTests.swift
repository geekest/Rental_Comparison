import XCTest
@testable import Rental_Comparison

final class DecisionLegacyProjectionTests: XCTestCase {
    func testProjectionKeepsLegacyCardsUsableDuringMigration() throws {
        var legacy = Fixtures.initialState
        legacy.task.listings[1].inspections[1].photoIDs = ["noise-photo"]

        let projected = DecisionLegacyProjection.appState(
            from: DecisionModelMigration.migrate(legacy, now: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let jingan = try XCTUnwrap(projected.task.listings.first { $0.id == Fixtures.jinganID })
        let noiseInspection = try XCTUnwrap(jingan.inspections.first { $0.name == "噪音" })

        XCTAssertEqual(projected.privacyAcknowledged, legacy.privacyAcknowledged)
        XCTAssertEqual(projected.task.city, "上海")
        XCTAssertEqual(jingan.city, "上海")
        XCTAssertEqual(jingan.rent, 8_200)
        XCTAssertEqual(noiseInspection.state, .issue)
        XCTAssertEqual(noiseInspection.photoIDs, ["noise-photo"])
    }
}
