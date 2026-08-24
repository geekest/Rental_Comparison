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

    func testLocalMediaRoundTripPreservesBytes() throws {
        let original = Data("local-media-proof".utf8)
        let mediaID = try PersistenceClient.saveMedia(original)
        defer { PersistenceClient.deleteMedia([mediaID]) }

        let url = try XCTUnwrap(PersistenceClient.mediaURL(for: mediaID))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testQuickCapturePreservesScreenshotEvidenceType() {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)

        let optionID = store.captureOption(name: "截图候选", monthlyRent: nil, photoIDs: ["capture-screenshot"], mediaEvidenceType: .screenshot)

        XCTAssertTrue(store.state.evidence.contains {
            $0.optionID == optionID && $0.mediaID == "capture-screenshot" && $0.type == .screenshot
        })
        XCTAssertEqual(store.task.listings.first { $0.id == optionID }?.photoIDs, ["capture-screenshot"])
    }

    func testListingMediaCanAddSelectPrimaryAndRemove() throws {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)
        let optionID = try XCTUnwrap(store.state.options.first?.id)

        try store.addListingMedia([Data("first-photo".utf8), Data("second-photo".utf8)], to: optionID)
        let addedMedia = store.listingMedia(for: optionID)
        XCTAssertGreaterThanOrEqual(addedMedia.count, 2)
        let firstAdded = try XCTUnwrap(addedMedia.first { $0.mediaID != "" })
        let secondAdded = try XCTUnwrap(addedMedia.last)

        store.setPrimaryListingMedia(secondAdded.evidenceID, for: optionID)
        XCTAssertEqual(store.listingMedia(for: optionID).first?.evidenceID, secondAdded.evidenceID)

        let removedURL = try XCTUnwrap(PersistenceClient.mediaURL(for: firstAdded.mediaID))
        XCTAssertTrue(FileManager.default.fileExists(atPath: removedURL.path))
        store.removeListingMedia(firstAdded.evidenceID, from: optionID)

        XCTAssertFalse(store.listingMedia(for: optionID).contains { $0.evidenceID == firstAdded.evidenceID })
        XCTAssertFalse(store.state.evidence.contains { $0.id == firstAdded.evidenceID })
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedURL.path))
    }
}
