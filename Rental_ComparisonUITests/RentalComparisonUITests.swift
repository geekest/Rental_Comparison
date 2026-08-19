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
        app.tabBars.buttons["对比"].tap()
        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["主要差异"].exists)
        app.tabBars.buttons["待确认"].tap()
        XCTAssertTrue(app.navigationBars["待确认"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["下一次需要确认"].exists)
    }

    func testQuickCaptureAllowsNameWithoutRent() {
        app.buttons["addListingButton"].tap()
        XCTAssertTrue(app.textFields["listingNameField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["listingRentField"].exists)
        XCTAssertTrue(app.buttons["saveListingButton"].exists)
        app.textFields["listingNameField"].tap()
        app.textFields["listingNameField"].typeText("Quick candidate")
        app.buttons["saveListingButton"].tap()
        XCTAssertTrue(app.navigationBars["快速添加候选"].waitForNonExistence(timeout: 5))
    }

    func testListingCardCanRemoveFromComparisonAndOpenDetails() {
        let listingID = "11111111-1111-1111-1111-111111111111"
        let comparisonButton = app.buttons["comparisonButton_\(listingID)"]

        XCTAssertTrue(comparisonButton.waitForExistence(timeout: 5))
        XCTAssertTrue(comparisonButton.isEnabled)

        comparisonButton.tap()
        XCTAssertEqual(comparisonButton.label, "加入对比")

        comparisonButton.tap()
        XCTAssertEqual(comparisonButton.label, "已加入对比")
        XCTAssertTrue(app.staticTexts["费用待确认"].exists)

        let card = app.otherElements["listingCard_\(listingID)"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(app.navigationBars["徐汇 · 一室一厅"].waitForExistence(timeout: 5))
    }
}
