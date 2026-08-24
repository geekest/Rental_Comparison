import XCTest
import UIKit
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
        XCTAssertEqual(draft.currency, "USD")
        XCTAssertEqual(draft.roomCount, 1)
        XCTAssertNil(draft.area)
        XCTAssertEqual(draft.city, "")
    }

    func testParsesRawScreenshotOCRIntoMatchingFields() {
        let text = """
        Assets
        ComparisonView
        Re
        09:44 L
        100
        视频
        图片
        评价
        必看好房｜严选好房・品质好・价格优
        合租•龙湖时代天街-01卧
        ¥3330/月（季付价）
        23-26年毕业生
        使用面积
        37.13m
        户型
        3室2厅2卫
        朝向
        朝南
        楼层
        20/26
        独立起居室
        独立卫生间
        """

        let draft = ListingImportParser.parse(text: text)

        XCTAssertEqual(draft.name, "龙湖时代天街-01卧")
        XCTAssertEqual(draft.monthlyRent, 3330)
        XCTAssertEqual(draft.area, 37.13)
        XCTAssertEqual(draft.layout, "3室2厅2卫")
        XCTAssertEqual(draft.roomCount, 3)
        XCTAssertEqual(draft.rentalType, .shared)
        XCTAssertNil(draft.address)
    }

    func testParsesExplicitAddressWithoutTreatingListingNameAsAddress() {
        let text = """
        合租•龙湖时代天街-01卧
        地址：上海市浦东新区申江路 500 号
        ¥3330/月
        """

        let draft = ListingImportParser.parse(text: text)

        XCTAssertEqual(draft.name, "龙湖时代天街-01卧")
        XCTAssertEqual(draft.address, "上海市浦东新区申江路 500 号")
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

    @MainActor
    func testScreenshotImportKeepsCoverAndOriginalEvidenceSeparate() throws {
        let store = AppStore(
            persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }),
            useFixtures: true
        )
        var draft = ListingImportDraft()
        draft.name = "带裁切封面的房源"
        draft.photoIDs = ["cover-photo"]
        draft.sourceScreenshotIDs = ["original-screenshot"]

        let optionID = store.captureImportedOption(draft: draft)
        let evidence = store.state.evidence.filter { $0.optionID == optionID }
        let listing = try XCTUnwrap(store.task.listings.first { $0.id == optionID })

        XCTAssertTrue(evidence.contains { $0.type == .photo && $0.mediaID == "cover-photo" })
        XCTAssertTrue(evidence.contains { $0.type == .screenshot && $0.mediaID == "original-screenshot" })
        XCTAssertEqual(listing.photoIDs, ["cover-photo"])
    }

    func testCoverCropProducesSixteenByNineImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 800), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 800))
        }

        let cropped = try XCTUnwrap(ListingCoverCropper.croppedImage(from: image, selection: .default))
        let cgImage = try XCTUnwrap(cropped.cgImage)

        XCTAssertEqual(cgImage.width, 400)
        XCTAssertEqual(cgImage.height, 225)
        XCTAssertEqual(Double(cgImage.width) / Double(cgImage.height), 16.0 / 9.0, accuracy: 0.01)
    }

    func testAutomaticCoverUsesRoomRegionBetweenNavigationAndListingText() {
        let lines = [
            RecognizedListingLine(text: "VR 视频 图片 评价", boundingBox: CGRect(x: 0.1, y: 0.87, width: 0.5, height: 0.03)),
            RecognizedListingLine(text: "必看好房｜严选好房", boundingBox: CGRect(x: 0.05, y: 0.48, width: 0.7, height: 0.03)),
            RecognizedListingLine(text: "合租•龙湖时代天街-01卧", boundingBox: CGRect(x: 0.05, y: 0.38, width: 0.8, height: 0.03))
        ]

        let selection = ListingCoverCropper.automaticSelection(
            imageSize: CGSize(width: 400, height: 800),
            lines: lines
        )
        let cropRect = ListingCoverCropper.normalizedCropRect(
            imageSize: CGSize(width: 400, height: 800),
            selection: selection
        )

        XCTAssertGreaterThan(cropRect.minY, 0.13)
        XCTAssertLessThan(cropRect.maxY, 0.49)
        XCTAssertEqual(cropRect.width / cropRect.height, 16.0 / 9.0 / 0.5, accuracy: 0.01)
    }
}
