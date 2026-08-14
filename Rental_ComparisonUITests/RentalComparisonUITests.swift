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
}
