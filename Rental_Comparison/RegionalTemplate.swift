import Foundation

protocol RegionalTemplate {
    var id: String { get }
    var defaultCurrency: String { get }
    var areaUnit: String { get }
    var suggestedCriteria: [TemplateCriterion] { get }
    var suggestedInspectionNames: [String] { get }
}

struct TemplateCriterion: Hashable {
    var key: String
    var title: String
    var importance: Importance
}

struct ChinaMainlandTemplate: RegionalTemplate {
    let id = "china-mainland"
    let defaultCurrency = "CNY"
    let areaUnit = "㎡"
    let suggestedCriteria = [
        TemplateCriterion(key: "budget", title: "月均居住成本不超过预算", importance: .required),
        TemplateCriterion(key: "move-in", title: "可在计划日期前入住", importance: .required),
        TemplateCriterion(key: "commute", title: "通勤在可接受范围内", importance: .required),
        TemplateCriterion(key: "sunlight", title: "自然采光良好", importance: .preferred)
    ]
    let suggestedInspectionNames = ["采光与通风", "噪音", "潮湿与发霉", "水压与排水"]
}

enum RegionalTemplateCatalog {
    static func template(id: String) -> any RegionalTemplate {
        switch id {
        case ChinaMainlandTemplate().id: ChinaMainlandTemplate()
        default: ChinaMainlandTemplate()
        }
    }
}

protocol ProviderAdapter {
    var id: String { get }
    func capture(text: String?, mediaIDs: [String]) -> ProviderCapture
}

struct ProviderCapture: Hashable {
    var sourceReferences: [String]
    var evidenceMediaIDs: [String]
}

struct ManualProviderAdapter: ProviderAdapter {
    let id = "manual"

    func capture(text: String?, mediaIDs: [String]) -> ProviderCapture {
        ProviderCapture(sourceReferences: text.map { [$0] } ?? [], evidenceMediaIDs: mediaIDs)
    }
}
