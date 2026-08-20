import XCTest
@testable import Rental_Comparison

final class DecisionReadinessEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testIssueIsVisibleAsKnownRisk() {
        let state = DecisionModelMigration.migrate(Fixtures.initialState, now: now)

        let summary = DecisionReadinessEngine.summary(for: Fixtures.jinganID, in: state)

        XCTAssertEqual(summary.status, .readyWithKnownRisks)
        XCTAssertEqual(summary.knownRiskCount, 1)
    }

    func testHighImpactUnknownBlocksReadinessAndNextAction() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState, now: now)
        state.unknowns = [
            .init(
                id: UUID(),
                optionID: Fixtures.xuhuiID,
                factKey: FactKey.monthlyRent,
                impactLevel: .high,
                reason: "水电费用仍待确认",
                status: .open,
                createdAt: now,
                resolvedAt: nil
            )
        ]

        XCTAssertEqual(DecisionReadinessEngine.summary(for: Fixtures.xuhuiID, in: state).status, .needsVerification)
        XCTAssertEqual(DecisionReadinessEngine.huntBlockerCount(in: state), 1)
        XCTAssertEqual(NextActionEngine.nextAction(in: state).destination, .verify)
    }

    func testTwoCandidatesWithoutComparisonPromptComparison() {
        var state = DecisionModelMigration.migrate(Fixtures.initialState, now: now)
        state.hunt.comparisonOptionIDs = []

        XCTAssertEqual(NextActionEngine.nextAction(in: state).destination, .compare)
    }
}
