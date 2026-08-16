import XCTest

final class RentalComparisonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testMainTabsOpenCoreScreens() {
        XCTAssertTrue(app.staticTexts["上海租房计划"].waitForExistence(timeout: 8))
        app.tabBars.buttons["对比"].tap()
        XCTAssertTrue(app.navigationBars["比较房源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["真实成本"].exists)
        app.tabBars.buttons["条件"].tap()
        XCTAssertTrue(app.navigationBars["条件"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["月均居住成本不超过 ¥9,500"].exists)
    }

    func testAddListingSheetHasRequiredFields() {
        app.buttons["addListingButton"].tap()
        XCTAssertTrue(app.textFields["listingNameField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["listingRentField"].exists)
        XCTAssertTrue(app.buttons["saveListingButton"].exists)
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
        XCTAssertTrue(app.staticTexts["8 / 18 楼"].exists)

        let card = app.otherElements["listingCard_\(listingID)"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(app.navigationBars["徐汇 · 一室一厅"].waitForExistence(timeout: 5))
    }
}
