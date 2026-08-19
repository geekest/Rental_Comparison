import XCTest
@testable import Rental_Comparison

@MainActor
final class FinalDecisionTests: XCTestCase {
    func testFinalDecisionPreservesDecisionStateAndCanBeWithdrawn() throws {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)
        let verification = try XCTUnwrap(store.state.verificationTasks.first { $0.unknownID != nil })
        store.completeVerificationTask(verification.id, state: .verified, result: "已与中介确认", photoIDs: [])
        let resolvedUnknownID = verification.unknownID

        store.confirmFinal(Fixtures.jinganID, reason: "通勤更短")

        XCTAssertEqual(store.state.hunt.status, .completed)
        XCTAssertEqual(store.state.hunt.finalOptionID, Fixtures.jinganID)
        XCTAssertEqual(store.state.unknowns.first { $0.id == resolvedUnknownID }?.status, .resolved)

        store.withdrawFinal()

        XCTAssertEqual(store.state.hunt.status, .active)
        XCTAssertNil(store.state.hunt.finalOptionID)
    }
}
