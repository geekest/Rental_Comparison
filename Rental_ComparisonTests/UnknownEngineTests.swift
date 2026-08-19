import XCTest
@testable import Rental_Comparison

final class UnknownEngineTests: XCTestCase {
    func testUnknownCostsAndRequiredCriteriaBecomeHighImpactBlockers() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState)
        let criterion = Criterion(id: UUID(), huntID: state.hunt.id, key: "test-required", title: "测试硬性条件", importance: .required, source: "user")
        state.criteria.append(criterion)
        state.hunt.criterionIDs.append(criterion.id)
        state.facts.append(.init(id: UUID(), optionID: Fixtures.xuhuiID, key: "\(FactKey.costPrefix)test", value: .cost(.init(name: "测试费用", amount: nil, currency: "CNY", cadence: .monthly, refundable: false)), sourceType: .manual, sourceRef: nil, verificationState: .unknown, evidenceIDs: [], capturedAt: .now, updatedAt: .now))

        UnknownEngine.refresh(in: &state)

        XCTAssertTrue(state.unknowns.contains { $0.optionID == Fixtures.xuhuiID && $0.reason.contains("测试费用") && $0.impactLevel == .high })
        XCTAssertTrue(state.unknowns.contains { $0.optionID == Fixtures.xuhuiID && $0.reason.contains("测试硬性条件") && $0.impactLevel == .high })
    }

    func testConfirmedFactResolvesExistingSystemUnknownWithoutDuplication() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState)
        state.facts.removeAll { $0.optionID == Fixtures.xuhuiID && $0.key == FactKey.monthlyRent }
        UnknownEngine.refresh(in: &state)
        let original = try! XCTUnwrap(state.unknowns.first { $0.optionID == Fixtures.xuhuiID && $0.factKey == "system.\(FactKey.monthlyRent)" })

        state.facts.append(.init(id: UUID(), optionID: Fixtures.xuhuiID, key: FactKey.monthlyRent, value: .decimal(7_800), sourceType: .manual, sourceRef: nil, verificationState: .userConfirmed, evidenceIDs: [], capturedAt: .now, updatedAt: .now))
        UnknownEngine.refresh(in: &state)

        let matching = state.unknowns.filter { $0.factKey == "system.\(FactKey.monthlyRent)" && $0.optionID == Fixtures.xuhuiID }
        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.id, original.id)
        XCTAssertEqual(matching.first?.status, .resolved)
    }

    func testPlannedViewingCreatesObservableNoiseUnknown() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState)
        let optionIndex = try! XCTUnwrap(state.options.firstIndex { $0.id == Fixtures.xuhuiID })
        state.options[optionIndex].searchStage = .viewingPlanned

        UnknownEngine.refresh(in: &state)

        let unknown = state.unknowns.first {
            $0.optionID == Fixtures.xuhuiID && $0.factKey == "system.\(FactKey.noise)"
        }
        XCTAssertEqual(unknown?.impactLevel, .high)

        VerificationTaskEngine.sync(in: &state)
        XCTAssertEqual(state.verificationTasks.first { $0.unknownID == unknown?.id }?.type, .observe)
    }
}
