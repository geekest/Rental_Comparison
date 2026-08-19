import XCTest
@testable import Rental_Comparison

@MainActor
final class RentalDecisionScenarioTests: XCTestCase {
    func testABCDecisionScenarioCompletesAndCanBeWithdrawn() throws {
        var state = DecisionModelMigration.migrate(Fixtures.initialState)
        let commute = try XCTUnwrap(state.criteria.first { $0.key == "commute" })
        let pet = try XCTUnwrap(state.criteria.first { $0.key == "pet" })
        state.criteria = [
            Criterion(id: commute.id, huntID: state.hunt.id, key: commute.key, title: "通勤不超过 45 分钟", importance: .required, source: "user"),
            Criterion(id: pet.id, huntID: state.hunt.id, key: pet.key, title: "允许宠物", importance: .required, source: "user")
        ]
        state.hunt.criterionIDs = state.criteria.map(\.id)
        state.hunt.comparisonOptionIDs = [Fixtures.xuhuiID, Fixtures.jinganID, Fixtures.putuoID]

        setDecimal(FactKey.monthlyRent, to: 7_500, optionID: Fixtures.xuhuiID, in: &state)
        setDecimal(FactKey.commuteMinutes, to: 45, optionID: Fixtures.xuhuiID, in: &state)
        setDecimal(FactKey.monthlyRent, to: 8_200, optionID: Fixtures.jinganID, in: &state)
        setDecimal(FactKey.commuteMinutes, to: 25, optionID: Fixtures.jinganID, in: &state)
        setDecimal(FactKey.monthlyRent, to: 6_900, optionID: Fixtures.putuoID, in: &state)
        setDecimal(FactKey.commuteMinutes, to: 60, optionID: Fixtures.putuoID, in: &state)
        setCriterion("commute", result: .met, optionID: Fixtures.xuhuiID, in: &state)
        setCriterion("pet", result: .met, optionID: Fixtures.xuhuiID, in: &state)
        setCriterion("commute", result: .met, optionID: Fixtures.jinganID, in: &state)
        setCriterion("pet", result: .met, optionID: Fixtures.jinganID, in: &state)
        setCriterion("commute", result: .conflict, optionID: Fixtures.putuoID, in: &state)
        setCriterion("pet", result: .conflict, optionID: Fixtures.putuoID, in: &state)
        state.facts.append(.init(
            id: UUID(), optionID: Fixtures.xuhuiID, key: "\(FactKey.costPrefix)utilities",
            value: .cost(.init(name: "水电", amount: nil, currency: "CNY", cadence: .monthly, refundable: false)),
            sourceType: .manual, sourceRef: nil, verificationState: .unknown, evidenceIDs: [], capturedAt: .now, updatedAt: .now
        ))
        let jinganIndex = try XCTUnwrap(state.options.firstIndex { $0.id == Fixtures.jinganID })
        state.options[jinganIndex].searchStage = .viewingPlanned
        UnknownEngine.refresh(in: &state)
        VerificationTaskEngine.sync(in: &state)

        let store = AppStore(
            persistence: .init(loadV2: { state }, loadV1: { nil }, saveV2: { _ in }),
            useFixtures: false
        )

        XCTAssertFalse(DecisionEngine.requiredConflicts(in: store.task, listing: try XCTUnwrap(store.task.listings.first { $0.id == Fixtures.putuoID })).isEmpty)
        XCTAssertTrue(store.state.unknowns.contains { $0.optionID == Fixtures.xuhuiID && $0.reason.contains("水电") && $0.impactLevel == .high })
        let noiseTask = try XCTUnwrap(store.state.verificationTasks.first { $0.optionID == Fixtures.jinganID && $0.type == .observe })
        XCTAssertEqual(noiseTask.instruction, "看房时关闭窗户静听 30 秒，再记录是否存在持续噪音。")

        store.completeVerificationTask(noiseTask.id, state: .issue, result: "关窗后仍有车流声", photoIDs: ["noise-evidence"])
        XCTAssertEqual(store.state.unknowns.first { $0.id == noiseTask.unknownID }?.status, .resolved)
        XCTAssertTrue(store.state.facts.contains {
            $0.optionID == Fixtures.jinganID && $0.key == FactKey.noise && $0.verificationState == .observed
        })

        store.updateTask { task in
            guard let index = task.listings.firstIndex(where: { $0.id == Fixtures.xuhuiID }),
                  let costIndex = task.listings[index].costs.firstIndex(where: { $0.name == "水电" }) else { return }
            task.listings[index].costs[costIndex].amount = 300
            task.listings[index].costs[costIndex].confirmed = true
        }
        XCTAssertFalse(store.state.unknowns.contains { $0.optionID == Fixtures.xuhuiID && $0.reason.contains("水电") && $0.status == .open })

        let listings = store.task.listings
        let a = try XCTUnwrap(listings.first { $0.id == Fixtures.xuhuiID })
        let b = try XCTUnwrap(listings.first { $0.id == Fixtures.jinganID })
        XCTAssertEqual(b.rent - a.rent, 700, accuracy: 0.01)
        XCTAssertEqual(a.commuteMinutes! - b.commuteMinutes!, 20)

        store.confirmFinal(Fixtures.xuhuiID, reason: "月租更低，已确认水电")
        XCTAssertEqual(store.state.hunt.status, .completed)
        XCTAssertEqual(store.state.hunt.finalOptionID, Fixtures.xuhuiID)

        store.withdrawFinal()
        XCTAssertEqual(store.state.hunt.status, .active)
        XCTAssertNil(store.state.hunt.finalOptionID)
    }

    private func setDecimal(_ key: String, to value: Double, optionID: UUID, in state: inout DecisionAppState) {
        if let index = state.facts.firstIndex(where: { $0.optionID == optionID && $0.key == key }) {
            state.facts[index].value = .decimal(value)
            state.facts[index].verificationState = .userConfirmed
        } else {
            state.facts.append(.init(id: UUID(), optionID: optionID, key: key, value: .decimal(value), sourceType: .manual, sourceRef: nil, verificationState: .userConfirmed, evidenceIDs: [], capturedAt: .now, updatedAt: .now))
        }
    }

    private func setCriterion(_ key: String, result: ConditionResult, optionID: UUID, in state: inout DecisionAppState) {
        let factKey = "\(FactKey.criterionResultPrefix)\(key)"
        state.facts.removeAll { $0.optionID == optionID && $0.key == factKey }
        state.facts.append(.init(id: UUID(), optionID: optionID, key: factKey, value: .text(result.rawValue), sourceType: .manual, sourceRef: nil, verificationState: .userConfirmed, evidenceIDs: [], capturedAt: .now, updatedAt: .now))
    }
}
