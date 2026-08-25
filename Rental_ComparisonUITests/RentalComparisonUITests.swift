import XCTest

final class RentalComparisonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testMainTabsOpenDecisionScreens() {
        XCTAssertTrue(app.staticTexts["上海租房计划"].waitForExistence(timeout: 8))
        app.tabBars.buttons["待确认"].tap()
        XCTAssertTrue(app.navigationBars["待确认"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["下一次需要确认"].exists)
        app.tabBars.buttons["对比"].tap()
        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["主要差异"].exists)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["常用偏好"].exists)
    }

    func testComparisonAnalysisCanCollapseAndExpand() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-startComparison"]
        app.launch()

        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        let disclosure = app.buttons["comparisonAnalysisDisclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["硬性冲突"].exists)

        disclosure.tap()
        XCTAssertFalse(app.staticTexts["硬性冲突"].exists)

        disclosure.tap()
        XCTAssertTrue(app.staticTexts["硬性冲突"].waitForExistence(timeout: 3))
    }

    func testComparisonSectionsShareHorizontalScrollPosition() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-startComparison"]
        app.launch()

        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        let detailsDisclosure = app.buttons["comparisonDetailsDisclosure"]
        XCTAssertTrue(detailsDisclosure.waitForExistence(timeout: 3))
        detailsDisclosure.tap()
        detailsDisclosure.tap()

        let costValue = app.staticTexts["¥9,250"]
        let commuteMetric = app.descendants(matching: .any)
            .matching(identifier: "comparisonMetric-commute-22222222-2222-2222-2222-222222222222")
            .firstMatch
        for _ in 0..<6 where !costValue.exists || !commuteMetric.exists {
            app.swipeUp()
        }
        XCTAssertTrue(costValue.waitForExistence(timeout: 3))
        XCTAssertTrue(commuteMetric.waitForExistence(timeout: 3))

        let initialX = commuteMetric.frame.minX
        for _ in 0..<3 where !costValue.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(costValue.isHittable)
        let dragStart = costValue.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let dragEnd = costValue.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd, withVelocity: .fast, thenHoldForDuration: 0.1)

        for _ in 0..<3 where !commuteMetric.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(commuteMetric.waitForExistence(timeout: 3))
        XCTAssertLessThan(commuteMetric.frame.minX, initialX)
    }

    func testComparisonDetailsCanCollapseAndExpand() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-startComparison"]
        app.launch()

        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        let disclosure = app.buttons["comparisonDetailsDisclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 3))
        XCTAssertEqual(disclosure.value as? String, "已展开")

        disclosure.tap()
        XCTAssertEqual(disclosure.value as? String, "已收起")
        let analysisDisclosure = app.buttons["comparisonAnalysisDisclosure"]
        XCTAssertTrue(analysisDisclosure.waitForExistence(timeout: 3))
        XCTAssertLessThan(disclosure.frame.minY, analysisDisclosure.frame.minY)

        disclosure.tap()
        XCTAssertEqual(disclosure.value as? String, "已展开")
    }

    func testComparisonHeaderStaysVisibleWhileScrolling() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-startComparison"]
        app.launch()

        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["比较房源"].staticTexts["比较房源"].exists)
        let header = app.staticTexts["comparisonHeader-11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(header.waitForExistence(timeout: 3))
        let initialHeaderFrame = header.frame
        XCTAssertGreaterThan(initialHeaderFrame.height, 0)

        for _ in 0..<4 {
            app.swipeUp()
        }

        XCTAssertGreaterThanOrEqual(header.frame.minY, 0)
        XCTAssertGreaterThan(header.frame.maxY, 0)
    }

    func testQuickCaptureAllowsNameWithoutRent() {
        app.buttons["addListingButton"].tap()
        XCTAssertTrue(app.buttons["directListingButton"].waitForExistence(timeout: 3))
        app.buttons["directListingButton"].tap()
        XCTAssertTrue(app.textFields["listingNameField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["listingRentField"].exists)
        let nameLabel = app.staticTexts["persistentFieldLabel_房源名称"]
        XCTAssertTrue(nameLabel.exists)
        XCTAssertTrue(app.buttons["saveListingButton"].exists)
        app.textFields["listingNameField"].tap()
        app.textFields["listingNameField"].typeText("Quick candidate")
        XCTAssertTrue(nameLabel.exists, "输入内容后字段标签仍应可见")
        app.buttons["saveListingButton"].tap()
        XCTAssertTrue(app.navigationBars["快速添加候选"].waitForNonExistence(timeout: 5))
    }

    func testAddListingMenuShowsThreeImportMethods() {
        app.buttons["addListingButton"].tap()

        XCTAssertTrue(app.buttons["directListingButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["linkImportButton"].exists)
        XCTAssertTrue(app.buttons["screenshotImportButton"].exists)
    }

    func testListingCardCanJoinComparisonAndOpenDetails() {
        let listingID = "33333333-3333-3333-3333-333333333333"
        let firstCard = app.otherElements["listingCard_11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.swipeLeft()
        let comparisonButton = app.buttons["comparisonButton_\(listingID)"]

        XCTAssertTrue(comparisonButton.waitForExistence(timeout: 5))
        XCTAssertEqual(comparisonButton.label, "加入对比")

        comparisonButton.tap()
        XCTAssertEqual(comparisonButton.label, "已加入对比")
        comparisonButton.tap()
        XCTAssertEqual(comparisonButton.label, "加入对比")

        let card = app.otherElements["listingCard_\(listingID)"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(app.navigationBars["普陀 · 开间"].waitForExistence(timeout: 5))
    }

    func testPlannedViewingOpensOptionSpecificVerificationMode() {
        let listingID = "11111111-1111-1111-1111-111111111111"
        let card = app.otherElements["listingCard_\(listingID)"]

        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["listingDetailButton_\(listingID)"].tap()
        XCTAssertTrue(app.navigationBars["徐汇 · 一室一厅"].waitForExistence(timeout: 5))
        let scheduleButton = app.buttons["scheduleViewingButton"]
        for _ in 0..<8 where !scheduleButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(scheduleButton.isHittable)

        scheduleButton.tap()
        let startButton = app.buttons["startViewingButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        XCTAssertTrue(app.buttons["正常"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["正常"].firstMatch.tap()
    }

    func testListingDetailProvidesTopLevelPhotoManagement() {
        let listingID = "11111111-1111-1111-1111-111111111111"

        XCTAssertTrue(app.otherElements["listingCard_\(listingID)"].waitForExistence(timeout: 5))
        app.buttons["listingDetailButton_\(listingID)"].tap()

        XCTAssertTrue(app.navigationBars["徐汇 · 一室一厅"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["manageListingMediaButton"].waitForExistence(timeout: 5))

        app.buttons["manageListingMediaButton"].tap()
        XCTAssertTrue(app.navigationBars["管理图片"].waitForExistence(timeout: 5))
    }
}
