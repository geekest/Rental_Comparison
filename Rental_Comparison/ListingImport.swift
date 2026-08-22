import Foundation

enum ListingProvider: String, CaseIterable, Identifiable, Hashable {
    case lianjia
    case beike
    case reddit

    var id: Self { self }

    var title: String {
        switch self {
        case .lianjia: return "链家"
        case .beike: return "贝壳"
        case .reddit: return "Reddit"
        }
    }

    var hosts: [String] {
        switch self {
        case .lianjia: return ["lianjia.com", "m.lianjia.com"]
        case .beike: return ["ke.com", "m.ke.com", "zu.ke.com", "sh.zu.ke.com"]
        case .reddit: return ["reddit.com", "www.reddit.com", "old.reddit.com", "redd.it"]
        }
    }
}

struct ListingImportDraft: Identifiable, Hashable {
    var id = UUID()
    var provider: ListingProvider?
    var sourceURL: URL?
    var sourceTitle = ""
    var sourceDescription = ""
    var imageURLs: [URL] = []
    var photoIDs: [String] = []
    var name = ""
    var city = ""
    var monthlyRent: Double?
    var currency = "CNY"
    var address: String?
    var area: Double?
    var layout: String?
    var roomCount: Int?
    var rentalType: RentalType = .entire
    var extractedText = ""
    var extractionNote = ""

    var sourceType: FactSourceType {
        sourceURL == nil ? .screenshot : .listing
    }
}

enum ListingImportError: LocalizedError {
    case invalidURL
    case unsupportedProvider
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "链接格式无效。"
        case .unsupportedProvider: return "暂不支持这个平台，请先使用链家、贝壳或 Reddit 链接。"
        case .emptyResponse: return "页面没有返回可解析内容。"
        }
    }
}

enum ListingImportParser {
    static func provider(for url: URL) -> ListingProvider? {
        let host = url.host?.lowercased() ?? ""
        return ListingProvider.allCases.first { provider in
            provider.hosts.contains { host == $0 || host.hasSuffix(".\($0)") }
        }
    }

    static func parse(url: URL, html: String) throws -> ListingImportDraft {
        guard let provider = provider(for: url) else { throw ListingImportError.unsupportedProvider }
        let title = firstMetaValue(in: html, key: "og:title") ?? firstTagText(in: html, tag: "title") ?? ""
        let description = firstMetaValue(in: html, key: "og:description") ?? visibleText(from: html)
        var draft = parse(text: [title, description].joined(separator: "\n"), provider: provider)
        draft.sourceURL = url
        draft.sourceTitle = title.htmlDecoded
        draft.sourceDescription = description.htmlDecoded
        draft.imageURLs = metaValues(in: html, key: "og:image")
            .compactMap(URL.init(string:))
            .filter { $0.scheme == "http" || $0.scheme == "https" }
        draft.extractedText = visibleText(from: html)
        if draft.name.isEmpty { draft.name = fallbackName(for: url, provider: provider) }
        return draft
    }

    static func parse(text: String, provider: ListingProvider? = nil) -> ListingImportDraft {
        let normalized = text.htmlDecoded.replacingOccurrences(of: "\u{00a0}", with: " ")
        let compact = normalized.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        let rent = firstNumber(
            in: compact,
            patterns: [
                #"([0-9]{1,6}(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*元\s*/?\s*月"#,
                #"(?:¥|\$)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*(?:/\s*month|per\s*month|monthly|/\s*mo)?"#,
                #"([0-9]{2,6}(?:\.[0-9]+)?)\s*(?:per\s*month|/\s*month|monthly)"#
            ]
        )
        let area = firstNumber(in: compact, patterns: [#"([0-9]+(?:\.[0-9]+)?)\s*(?:㎡|m²|平方米)"#])
        let layout = firstMatch(in: compact, patterns: [#"([0-9]+\s*室\s*[0-9]+\s*厅)"#, #"([0-9]+\s*(?:bed|bedroom)s?)"#])
        let roomCount = layout.flatMap { firstNumber(in: $0, patterns: [#"([0-9]+)\s*(?:室|bed|bedroom)"#]).map(Int.init) }
        let rentalType: RentalType = compact.localizedCaseInsensitiveContains("合租") || compact.localizedCaseInsensitiveContains("shared") || compact.localizedCaseInsensitiveContains("roommate") ? .shared : .entire
        let city = cityName(in: compact)
        let name = listingName(from: compact)
        var draft = ListingImportDraft()
        draft.provider = provider
        draft.name = name
        draft.city = city
        draft.monthlyRent = rent
        draft.address = addressCandidate(from: compact)
        draft.area = area
        draft.layout = layout
        draft.roomCount = roomCount
        draft.rentalType = rentalType
        draft.extractedText = normalized
        return draft
    }

    private static func firstMetaValue(in html: String, key: String) -> String? {
        metaValues(in: html, key: key).first
    }

    private static func metaValues(in html: String, key: String) -> [String] {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #"<meta[^>]+(?:property|name)=["']"# + escapedKey + #"["'][^>]+content=["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[valueRange])
        }
    }

    private static func firstTagText(in html: String, tag: String) -> String? {
        let pattern = #"<"# + tag + #"[^>]*>(.*?)</"# + tag + #">"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let valueRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[valueRange]).htmlDecoded
    }

    private static func visibleText(from html: String) -> String {
        html.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .htmlDecoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstNumber(in text: String, patterns: [String]) -> Double? {
        patterns.lazy.compactMap { pattern in
            guard let value = firstMatch(in: text, patterns: [pattern]) else { return nil }
            return Double(value.replacingOccurrences(of: ",", with: ""))
        }.first
    }

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
                  let valueRange = Range(match.range(at: 1), in: text) else { continue }
            return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func listingName(from text: String) -> String {
        if let separator = text.range(of: "·") {
            let tail = text[separator.upperBound...]
            return String(tail.split(separator: " ").first ?? "").trimmingCharacters(in: .punctuationCharacters)
        }
        if let match = firstMatch(in: text, patterns: [#"(.{2,32}?)(?:[0-9]+\s*(?:室|bed|bedroom))"#]) {
            return match.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text.split(separator: "\n").first ?? "").prefix(48).description
    }

    private static func addressCandidate(from text: String) -> String? {
        firstMatch(in: text, patterns: [#"([\u4e00-\u9fa5]{2,8}(?:区|县|镇|街道|路|街|弄|号)[^，。;；]{0,28})"#])
    }

    private static func cityName(in text: String) -> String {
        for (keyword, city) in [("上海", "上海"), ("北京", "北京"), ("深圳", "深圳"), ("广州", "广州"), ("杭州", "杭州")] where text.contains(keyword) {
            return city
        }
        return ""
    }

    private static func fallbackName(for url: URL, provider: ListingProvider) -> String {
        let slug = url.path.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: ".html", with: "") ?? provider.title
        return slug.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
    }
}

struct ListingLinkImporter {
    func importURL(_ url: URL) async throws -> ListingImportDraft {
        guard ListingImportParser.provider(for: url) != nil else { throw ListingImportError.unsupportedProvider }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode), !data.isEmpty else {
            throw ListingImportError.emptyResponse
        }
        var draft = try ListingImportParser.parse(url: url, html: String(decoding: data, as: UTF8.self))
        for imageURL in draft.imageURLs.prefix(8) {
            do {
                let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
                guard let imageHTTP = imageResponse as? HTTPURLResponse, (200..<400).contains(imageHTTP.statusCode), !imageData.isEmpty else { continue }
                draft.photoIDs.append(try PersistenceClient.saveMedia(imageData))
            } catch {
                continue
            }
        }
        return draft
    }
}

private extension String {
    var htmlDecoded: String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
