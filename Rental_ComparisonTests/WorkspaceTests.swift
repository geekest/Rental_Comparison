import XCTest
@testable import Rental_Comparison

@MainActor
final class WorkspaceTests: XCTestCase {
    func testCreatingAndSwitchingTasksKeepsIndependentOptions() {
        let store = AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true)
        let initialID = store.state.hunt.id
        let initialOptionCount = store.state.options.count

        store.createTask(title: "北京任务", city: "北京", destination: "国贸", expectedMonths: 6)

        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertEqual(store.task.title, "北京任务")
        XCTAssertTrue(store.task.listings.isEmpty)

        store.switchTask(to: initialID)

        XCTAssertEqual(store.task.title, "上海租房计划")
        XCTAssertEqual(store.state.options.count, initialOptionCount)
    }

    func testPreferencesPersistThroughWorkspaceSave() throws {
        var savedWorkspace: DecisionWorkspace?
        let client = DecisionPersistenceClient(
            loadV2: { nil },
            loadV1: { nil },
            saveV2: { _ in },
            loadWorkspace: { savedWorkspace },
            saveWorkspace: { savedWorkspace = $0 }
        )
        let store = AppStore(persistence: client, useFixtures: true)

        store.updatePreferences {
            $0.defaultCurrency = "HKD"
            $0.defaultExpectedStayMonths = 18
        }

        XCTAssertEqual(savedWorkspace?.preferences.defaultCurrency, "HKD")
        XCTAssertEqual(savedWorkspace?.preferences.defaultExpectedStayMonths, 18)
    }
}
