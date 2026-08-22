import Foundation

enum ListingStatus: String, Codable, CaseIterable, Identifiable {
    case candidate
    case eliminated
    var id: Self { self }
}
enum RentalType: String, Codable, CaseIterable, Identifiable {
    case entire
    case shared
    var id: Self { self }
    var title: String { self == .entire ? "整租" : "合租" }
}

enum CommuteMode: String, Codable, CaseIterable, Identifiable {
    case subway
    case walking
    case driving
    var id: Self { self }
    var title: String {
        switch self {
        case .subway: "地铁"
        case .walking: "步行"
        case .driving: "开车"
        }
    }
    var symbol: String {
        switch self {
        case .subway: "tram.fill"
        case .walking: "figure.walk"
        case .driving: "car.fill"
        }
    }
}

enum Importance: String, Codable, CaseIterable, Identifiable {
    case required
    case preferred
    case ignored
    var id: Self { self }
    var title: String {
        switch self {
        case .required: "硬性"
        case .preferred: "偏好"
        case .ignored: "不关注"
        }
    }
}

enum ConditionResult: String, Codable, CaseIterable, Identifiable {
    case met
    case conflict
    case unknown
    var id: Self { self }
    var title: String {
        switch self {
        case .met: "符合"
        case .conflict: "不符合"
        case .unknown: "未知"
        }
    }
    var symbol: String {
        switch self {
        case .met: "checkmark.circle.fill"
        case .conflict: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

enum InspectionState: String, Codable, CaseIterable, Identifiable {
    case unchecked
    case okay
    case issue
    var id: Self { self }
    var title: String {
        switch self {
        case .unchecked: "未检查"
        case .okay: "无问题"
        case .issue: "有问题"
        }
    }
}

enum CostCadence: String, Codable, CaseIterable, Identifiable {
    case daily
    case monthly
    case quarterly
    case semiAnnual
    case annual
    case oneTime
    var id: Self { self }
    var title: String {
        switch self {
        case .daily: "每日"
        case .monthly: "每月"
        case .quarterly: "每季度"
        case .semiAnnual: "每半年"
        case .annual: "每年"
        case .oneTime: "一次性"
        }
    }
}

struct CostItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double?
    var cadence: CostCadence
    var refundable: Bool
    var confirmed: Bool
}

struct ConditionDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var importance: Importance
    var custom = false
}

struct InspectionItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var state: InspectionState = .unchecked
    var note = ""
    var photoIDs: [String] = []
    var hidden = false
    var custom = false
}

struct Listing: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var city: String
    var rentalType: RentalType
    var rent: Double
    var currency = "CNY"
    var status: ListingStatus = .candidate
    var focused = false
    var eliminationReason: String?
    var address: String?
    var area: Double?
    var areaScope: String?
    var layout: String?
    var floor: String?
    var hasElevator: Bool?
    var availableDate: Date?
    var leaseMonths: Int?
    var roomCount: Int?
    var commuteMinutes: Int?
    var commuteFare: Double?
    var commuteMode: CommuteMode?
    var bundledImageName: String?
    var photoIDs: [String] = []
    var costs: [CostItem] = []
    var conditionResults: [String: ConditionResult] = [:]
    var inspections: [InspectionItem] = InspectionItem.defaults

    var roomDescription: String {
        guard let roomCount else { return rentalType.title }
        return "\(rentalType.title) \(roomCount) 居"
    }
}

struct DecisionEvent: Identifiable, Codable, Hashable {
    enum EventType: String, Codable {
        case focused, unfocused, eliminated, restored, compared, confirmed, withdrawn
    }
    var id = UUID()
    var type: EventType
    var listingID: UUID
    var at = Date()
    var reason: String?
}

struct RentalTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var city: String
    var currency = "CNY"
    var expectedMonths: Int
    var commuteDestination: String
    var listings: [Listing]
    var conditions: [ConditionDefinition]
    var comparisonIDs: [UUID]
    var baselineID: UUID?
    var finalListingID: UUID?
    var finalReason: String?
    var events: [DecisionEvent] = []
    var completed = false
}

struct AppState: Codable, Hashable {
    var version = 1
    var privacyAcknowledged = false
    var task: RentalTask
}

extension InspectionItem {
    static let defaultNames = ["采光与通风", "噪音", "潮湿与发霉", "水压与排水", "家电与设施", "安全与门禁", "网络信号", "周边环境", "图片与实物差异"]
    static var defaults: [InspectionItem] {
        defaultNames.enumerated().map { InspectionItem(id: "inspection-\($0.offset + 1)", name: $0.element) }
    }
}

extension ConditionDefinition {
    static var defaults: [ConditionDefinition] {
        [
            .init(id: "budget", name: "月均居住成本不超过 ¥9,500", importance: .required),
            .init(id: "move-in", name: "在最晚日期前可入住", importance: .required),
            .init(id: "rental-type", name: "符合整租或合租要求", importance: .preferred),
            .init(id: "commute", name: "单程通勤不超过 40 分钟", importance: .required),
            .init(id: "sunlight", name: "自然采光良好", importance: .preferred),
            .init(id: "private", name: "拥有独立私人空间", importance: .preferred),
            .init(id: "pet", name: "允许宠物", importance: .ignored),
            .init(id: "elevator", name: "有电梯", importance: .ignored),
            .init(id: "parking", name: "方便停车", importance: .ignored),
            .init(id: "cooking", name: "允许做饭", importance: .preferred)
        ]
    }
}
