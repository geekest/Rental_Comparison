import XCTest
@testable import Rental_Comparison

final class VerificationTaskEngineTests: XCTestCase {
    func testOpenUnknownCreatesOneActionableTaskWithoutDuplicates() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState)
        UnknownEngine.refresh(in: &state)

        VerificationTaskEngine.sync(in: &state)
        VerificationTaskEngine.sync(in: &state)

        let unknown = try! XCTUnwrap(state.unknowns.first { $0.status == .open })
        XCTAssertEqual(state.verificationTasks.filter { $0.unknownID == unknown.id }.count, 1)
        XCTAssertEqual(state.verificationTasks.first { $0.unknownID == unknown.id }?.state, .pending)
    }
}

@MainActor
final class VerificationTaskCompletionTests: XCTestCase {
    func testVerificationClosesUnknownAndRetainsPhotoEvidence() throws {
        var saved: DecisionAppState?
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { saved = $0 }), useFixtures: true)
        let task = try XCTUnwrap(store.state.verificationTasks.first { $0.unknownID != nil })

        store.completeVerificationTask(task.id, state: .issue, result: "晚间有持续车流声", photoIDs: ["noise-photo"])

        XCTAssertEqual(store.state.verificationTasks.first { $0.id == task.id }?.state, .issue)
        XCTAssertEqual(store.state.unknowns.first { $0.id == task.unknownID }?.status, .resolved)
        XCTAssertTrue(store.state.evidence.contains { $0.mediaID == "noise-photo" })
        XCTAssertTrue(store.state.evidence.contains { $0.type == .userObservation && $0.text == "晚间有持续车流声" })
        XCTAssertEqual(saved?.events.last?.type, .verificationCompleted)
    }

    func testUserCreatedUnknownGeneratesVerificationTask() throws {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)

        store.createUnknown(optionID: Fixtures.jinganID, reason: "确认夜间噪音")

        let unknown = try XCTUnwrap(store.state.unknowns.first { $0.optionID == Fixtures.jinganID && $0.reason == "确认夜间噪音" })
        XCTAssertEqual(unknown.impactLevel, .high)
        XCTAssertTrue(store.state.verificationTasks.contains { $0.unknownID == unknown.id && $0.state == .pending })
    }

    func testObservationTaskWritesBackObservedFactAndAvoidsDuplicateUnknown() throws {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)

        store.setSearchStage(.viewingPlanned, for: Fixtures.xuhuiID)
        let task = try XCTUnwrap(store.state.verificationTasks.first {
            $0.optionID == Fixtures.xuhuiID && $0.type == .observe
        })
        store.completeVerificationTask(task.id, state: .issue, result: "关窗后仍有车流声", photoIDs: ["observed-noise"])
        store.createUnknown(optionID: Fixtures.xuhuiID, reason: "确认夜间噪音")

        let fact = try XCTUnwrap(store.state.facts.first {
            $0.optionID == Fixtures.xuhuiID && $0.key == FactKey.noise
        })
        XCTAssertEqual(fact.sourceType, .userObservation)
        XCTAssertEqual(fact.verificationState, .observed)
        XCTAssertTrue(fact.evidenceIDs.contains { id in
            store.state.evidence.contains { $0.id == id && $0.mediaID == "observed-noise" }
        })
        XCTAssertFalse(store.state.unknowns.contains {
            $0.optionID == Fixtures.xuhuiID && $0.status == .open && $0.factKey == "user.\(FactKey.noise)"
        })
    }
}
