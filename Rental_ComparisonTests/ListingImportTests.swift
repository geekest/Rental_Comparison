import XCTest
@testable import Rental_Comparison

final class ListingImportTests: XCTestCase {
    func testDetectsTheThreeInitialProviders() throws {
        XCTAssertEqual(ListingImportParser.provider(for: try XCTUnwrap(URL(string: "https://m.lianjia.com/chuzu/sh/zufang/SH2106397257317220352.html"))), .lianjia)
        XCTAssertEqual(ListingImportParser.provider(for: try XCTUnwrap(URL(string: "https://bj.zu.ke.com/zufang/BJ1907477165083983872.html"))), .beike)
        XCTAssertEqual(ListingImportParser.provider(for: try XCTUnwrap(URL(string: "https://www.reddit.com/r/MadisonClassifieds/comments/1rjwwqk/apartment-for-rent-live-resortstyle-at-22_slate/"))), .reddit)
        XCTAssertNil(ListingImportParser.provider(for: try XCTUnwrap(URL(string: "https://example.com/listing/1"))))
    }

    func testShareURLRouterRoundTripsSupportedURL() throws {
        let sharedURL = try XCTUnwrap(URL(string: "https://www.reddit.com/r/MadisonClassifieds/comments/example/"))
        let appURL = try XCTUnwrap(ImportURLRouter.hostAppURL(for: sharedURL))

        XCTAssertEqual(ImportURLRouter.sharedURL(from: appURL), sharedURL)
    }

    func testParsesChineseListingFixtureIntoConservativeFields() {
        let text = "整租·汇金广场 2室2厅 南 链家/130.63㎡/徐家汇/距徐家汇站387m 官方核验 16000 元/月"
        let draft = ListingImportParser.parse(text: text, provider: .lianjia)

        XCTAssertEqual(draft.provider, .lianjia)
        XCTAssertEqual(draft.name, "汇金广场")
        XCTAssertEqual(draft.monthlyRent, 16000)
        XCTAssertEqual(draft.area, 130.63)
        XCTAssertEqual(draft.roomCount, 2)
        XCTAssertEqual(draft.rentalType, .entire)
    }

    func testParsesEnglishRedditFixtureWithoutInventingMissingFields() {
        let text = "Apartment for Rent! Beautiful 1 bedroom + 1 bathroom apartment. $1,650 per month. Madison, WI"
        let draft = ListingImportParser.parse(text: text, provider: .reddit)

        XCTAssertEqual(draft.provider, .reddit)
        XCTAssertEqual(draft.monthlyRent, 1650)
        XCTAssertEqual(draft.roomCount, 1)
        XCTAssertNil(draft.area)
        XCTAssertEqual(draft.city, "")
    }

    func testHTMLMetadataKeepsSourceAndImageCandidates() throws {
        let url = try XCTUnwrap(URL(string: "https://bj.zu.ke.com/zufang/BJ1907477165083983872.html"))
        let html = """
        <html><head>
        <title>整租·金茂北京国际社区 1室1厅 西</title>
        <meta property="og:title" content="整租·金茂北京国际社区 1室1厅 西">
        <meta property="og:description" content="50.00㎡ 贝壳优选 2100 元/月">
        <meta property="og:image" content="https://example.com/image.jpg">
        </head><body>北京租房</body></html>
        """
        let draft = try ListingImportParser.parse(url: url, html: html)

        XCTAssertEqual(draft.sourceURL, url)
        XCTAssertEqual(draft.name, "金茂北京国际社区")
        XCTAssertEqual(draft.monthlyRent, 2100)
        XCTAssertEqual(draft.area, 50)
        XCTAssertEqual(draft.imageURLs.count, 1)
        XCTAssertEqual(draft.city, "北京")
    }

    @MainActor
    func testImportedOptionStoresConfirmedFactsAndSourceEvidence() throws {
        var savedState: DecisionAppState?
        let store = AppStore(
            persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { savedState = $0 }),
            useFixtures: true
        )
        var draft = ListingImportDraft()
        draft.provider = .reddit
        draft.sourceURL = try XCTUnwrap(URL(string: "https://www.reddit.com/r/apartments/comments/example/"))
        draft.sourceDescription = "Apartment for rent"
        draft.name = "Reddit candidate"
        draft.city = "Madison"
        draft.monthlyRent = 1650
        draft.roomCount = 1

        let optionID = store.captureImportedOption(draft: draft)
        let facts = store.state.facts.filter { $0.optionID == optionID }
        XCTAssertTrue(facts.contains { $0.key == FactKey.monthlyRent && $0.verificationState == .userConfirmed })
        XCTAssertTrue(facts.contains { $0.key == FactKey.city && $0.value == .text("Madison") })
        XCTAssertTrue(store.state.options.first { $0.id == optionID }?.sourceRefs.contains(draft.sourceURL!.absoluteString) == true)
        XCTAssertTrue(store.state.evidence.contains { $0.optionID == optionID && $0.type == .listing && $0.sourceURL == draft.sourceURL!.absoluteString })
        XCTAssertNotNil(savedState)
    }
}
