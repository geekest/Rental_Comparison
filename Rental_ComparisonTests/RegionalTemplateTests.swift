import XCTest
@testable import Rental_Comparison

final class RegionalTemplateTests: XCTestCase {
    func testChinaTemplateOwnsRegionalDefaults() {
        let template = RegionalTemplateCatalog.template(id: "china-mainland")

        XCTAssertEqual(template.defaultCurrency, "CNY")
        XCTAssertEqual(template.areaUnit, "㎡")
        XCTAssertTrue(template.suggestedCriteria.contains { $0.key == "commute" })
    }

    func testManualAdapterDoesNotInterpretEvidence() {
        let capture = ManualProviderAdapter().capture(text: "房东消息", mediaIDs: ["photo-a"])

        XCTAssertEqual(capture.sourceReferences, ["房东消息"])
        XCTAssertEqual(capture.evidenceMediaIDs, ["photo-a"])
    }

    func testMoneyFormattingRequiresAndPreservesTheProvidedCurrency() {
        let dollar = 1_200.0.formattedMoney(currency: "USD")
        let euro = 1_200.0.formattedMoney(currency: "EUR")

        XCTAssertNotEqual(dollar, euro)
    }

    func testMoneyFormattingFollowsExplicitLocale() {
        let english = 1_200.0.formattedMoney(currency: "USD", locale: Locale(identifier: "en_US"))
        let chinese = 1_200.0.formattedMoney(currency: "USD", locale: Locale(identifier: "zh_CN"))

        XCTAssertNotEqual(english, chinese)
    }
}
