import XCTest
@testable import Rental_Comparison

final class DecisionModelMigrationTests: XCTestCase {
    private let migratedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testMigrationPreservesFactsMediaAndDecisionHistory() throws {
        var legacy = Fixtures.initialState
        legacy.task.events = [.init(type: .eliminated, listingID: Fixtures.putuoID, reason: "通勤过长")]
        legacy.task.listings[0].photoIDs = ["photo-a"]

        let migrated = DecisionModelMigration.migrate(legacy, now: migratedAt)
        let xuhui = try XCTUnwrap(migrated.options.first { $0.id == Fixtures.xuhuiID })

        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.hunt.optionIDs.count, legacy.task.listings.count)
        XCTAssertEqual(xuhui.displayName, "徐汇 · 一室一厅")
        XCTAssertTrue(migrated.evidence.contains { $0.mediaID == "photo-a" })
        XCTAssertEqual(migrated.events.first?.type, .eliminated)
        XCTAssertEqual(migrated.events.first?.reason, "通勤过长")
    }

    func testUnknownCostIsNotMigratedToZero() {
        let migrated = DecisionModelMigration.migrate(Fixtures.initialState, now: migratedAt)
        let unknownDeposit = migrated.facts.first {
            $0.optionID == Fixtures.putuoID
                && $0.key.hasPrefix(FactKey.costPrefix)
                && $0.value == .cost(.init(name: "押金", amount: nil, currency: "CNY", cadence: .oneTime, refundable: true))
        }

        XCTAssertNotNil(unknownDeposit)
        XCTAssertEqual(unknownDeposit?.verificationState, .unknown)
    }

    func testInspectionStateAndPhotoRemainAvailableAsVerificationEvidence() {
        var legacy = Fixtures.initialState
        legacy.task.listings[1].inspections[1].photoIDs = ["noise-photo"]

        let migrated = DecisionModelMigration.migrate(legacy, now: migratedAt)
        let noiseTask = migrated.verificationTasks.first { $0.optionID == Fixtures.jinganID && $0.title == "噪音" }

        XCTAssertEqual(noiseTask?.state, .issue)
        XCTAssertEqual(noiseTask?.result, "临街，关窗后仍能听到车流声。")
        XCTAssertTrue(migrated.evidence.contains { $0.mediaID == "noise-photo" })
    }

    func testRepeatedLoadUsesPersistedV2InsteadOfMigratingAgain() throws {
        var savedState: DecisionAppState?
        let client = DecisionPersistenceClient(
            loadV2: { savedState },
            loadV1: { Fixtures.initialState },
            saveV2: { savedState = $0 }
        )

        let first = try XCTUnwrap(DecisionPersistenceClient.loadOrMigrate(using: client, now: migratedAt))
        let second = try XCTUnwrap(DecisionPersistenceClient.loadOrMigrate(using: client, now: migratedAt))

        XCTAssertEqual(first.source, .migratedV1)
        XCTAssertEqual(second.source, .v2)
        XCTAssertEqual(first.state, second.state)
    }

    func testLoadFallsBackToV1MemoryWhenV2SaveFails() throws {
        let client = DecisionPersistenceClient(
            loadV2: { nil },
            loadV1: { Fixtures.initialState },
            saveV2: { _ in throw CocoaError(.fileWriteNoPermission) }
        )

        let result = try XCTUnwrap(try DecisionPersistenceClient.loadOrMigrate(using: client, now: migratedAt))

        XCTAssertEqual(result.source, .v1Fallback(CocoaError(.fileWriteNoPermission).localizedDescription))
        XCTAssertEqual(result.state.version, 2)
    }

    func testLegacyFormUpdateKeepsV2UnknownTasksAndObservationFacts() throws {
        var current = DecisionModelMigration.migrate(Fixtures.initialState, now: migratedAt)
        let unknown = DecisionUnknown(
            id: UUID(), optionID: Fixtures.jinganID, factKey: "user.\(FactKey.noise)", impactLevel: .high,
            reason: "确认夜间噪音", status: .open, createdAt: migratedAt, resolvedAt: nil
        )
        let observation = Fact(
            id: UUID(), optionID: Fixtures.jinganID, key: FactKey.noise, value: .text("关窗后仍有车流声"),
            sourceType: .userObservation, sourceRef: nil, verificationState: .observed,
            evidenceIDs: [], capturedAt: migratedAt, updatedAt: migratedAt
        )
        let task = VerificationTask(
            id: UUID(), optionID: Fixtures.jinganID, unknownID: unknown.id, type: .observe,
            title: unknown.reason, instruction: "现场确认", state: .pending, result: nil, evidenceIDs: []
        )
        current.unknowns = [unknown]
        current.facts.append(observation)
        current.verificationTasks.append(task)

        var legacy = Fixtures.initialState
        legacy.task.listings[1].rent = 8_300
        let merged = DecisionModelMigration.mergeLegacyUpdate(
            DecisionModelMigration.migrate(legacy, now: migratedAt), preserving: current
        )

        XCTAssertEqual(merged.facts.first { $0.optionID == Fixtures.jinganID && $0.key == FactKey.monthlyRent }?.value, .decimal(8_300))
        XCTAssertTrue(merged.unknowns.contains { $0.id == unknown.id })
        XCTAssertTrue(merged.verificationTasks.contains { $0.id == task.id })
        XCTAssertTrue(merged.facts.contains { $0.id == observation.id })
    }
}
