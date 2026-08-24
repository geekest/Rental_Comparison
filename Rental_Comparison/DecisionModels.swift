import Foundation

enum HuntStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case completed
    case archived

    var id: Self { self }
}
enum SearchStage: String, Codable, CaseIterable, Identifiable {
    case saved
    case contacted
    case viewingPlanned = "viewing_planned"
    case viewed
    case applied
    case unavailable

    var id: Self { self }
}

enum OptionDecisionState: String, Codable, CaseIterable, Identifiable {
    case candidate
    case eliminated
    case final

    var id: Self { self }
}

enum FactSourceType: String, Codable, CaseIterable, Identifiable {
    case screenshot
    case photo
    case userObservation = "user_observation"
    case manual
    case listing
    case agentMessage = "agent_message"
    case agentVerbal = "agent_verbal"
    case contract

    var id: Self { self }
}

enum FactVerificationState: String, Codable, CaseIterable, Identifiable {
    case unknown
    case extracted
    case userConfirmed = "user_confirmed"
    case observed

    var id: Self { self }
}

enum EvidenceType: String, Codable, CaseIterable, Identifiable {
    case listing
    case screenshot
    case photo
    case agentMessage = "agent_message"
    case agentVerbal = "agent_verbal"
    case contract
    case userObservation = "user_observation"
    case manual

    var id: Self { self }
}

enum UnknownImpactLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: Self { self }
}

enum UnknownStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case resolved

    var id: Self { self }
}

enum VerificationTaskType: String, Codable, CaseIterable, Identifiable {
    case ask
    case check
    case observe
    case photo
    case measure

    var id: Self { self }
}

enum VerificationTaskState: String, Codable, CaseIterable, Identifiable {
    case pending
    case verified
    case issue
    case skipped

    var id: Self { self }
}

enum DecisionReadiness: String, Codable, CaseIterable, Identifiable {
    case notReady = "not_ready"
    case needsVerification = "needs_verification"
    case readyWithKnownRisks = "ready_with_known_risks"
    case ready

    var id: Self { self }
}

struct CostFactValue: Codable, Hashable {
    var name: String
    var amount: Double?
    var currency: String
    var cadence: CostCadence
    var refundable: Bool
}

enum FactValue: Codable, Hashable {
    case text(String)
    case decimal(Double)
    case boolean(Bool)
    case date(Date)
    case cost(CostFactValue)
}

struct Hunt: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var regionTemplateID: String
    var city: String
    var defaultCurrency: String
    var expectedStayMonths: Int?
    var primaryDestination: String?
    var optionIDs: [UUID]
    var criterionIDs: [UUID]
    var comparisonOptionIDs: [UUID]
    var baselineOptionID: UUID?
    var finalOptionID: UUID?
    var finalReason: String?
    var status: HuntStatus
    var createdAt: Date
    var updatedAt: Date
}

struct Option: Identifiable, Codable, Hashable {
    var id: UUID
    var huntID: UUID
    var displayName: String
    var searchStage: SearchStage
    var decisionState: OptionDecisionState
    var isFocused: Bool
    var eliminationReason: String?
    var sourceRefs: [String]
    var factIDs: [UUID]
    var evidenceIDs: [UUID]
    var primaryEvidenceID: UUID? = nil
    var verificationTaskIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
}

struct Fact: Identifiable, Codable, Hashable {
    var id: UUID
    var optionID: UUID
    var key: String
    var value: FactValue
    var sourceType: FactSourceType
    var sourceRef: String?
    var verificationState: FactVerificationState
    var evidenceIDs: [UUID]
    var capturedAt: Date
    var updatedAt: Date
}

struct Evidence: Identifiable, Codable, Hashable {
    var id: UUID
    var optionID: UUID
    var type: EvidenceType
    var mediaID: String?
    var bundledAssetName: String?
    var text: String?
    var sourceURL: String?
    var capturedAt: Date
}

struct ListingMedia: Identifiable, Hashable {
    let evidenceID: UUID
    let mediaID: String
    let type: EvidenceType
    let capturedAt: Date

    var id: UUID { evidenceID }
    var isScreenshot: Bool { type == .screenshot }
}

struct Criterion: Identifiable, Codable, Hashable {
    var id: UUID
    var huntID: UUID
    var key: String
    var title: String
    var importance: Importance
    var source: String
}

struct DecisionUnknown: Identifiable, Codable, Hashable {
    var id: UUID
    var optionID: UUID
    var factKey: String
    var impactLevel: UnknownImpactLevel
    var reason: String
    var status: UnknownStatus
    var createdAt: Date
    var resolvedAt: Date?
}

struct VerificationTask: Identifiable, Codable, Hashable {
    var id: UUID
    var optionID: UUID
    var unknownID: UUID?
    var type: VerificationTaskType
    var title: String
    var instruction: String
    var state: VerificationTaskState
    var result: String?
    var evidenceIDs: [UUID]
}

struct DecisionEventRecord: Identifiable, Codable, Hashable {
    enum EventType: String, Codable {
        case captured
        case focused
        case unfocused
        case eliminated
        case restored
        case comparisonOpened = "comparison_opened"
        case unknownCreated = "unknown_created"
        case unknownResolved = "unknown_resolved"
        case verificationCompleted = "verification_completed"
        case confirmed
        case withdrawn
    }

    var id: UUID
    var type: EventType
    var optionID: UUID?
    var at: Date
    var reason: String?
}

struct DecisionAppState: Codable, Hashable {
    var version = 2
    var privacyAcknowledged: Bool
    var hunt: Hunt
    var options: [Option]
    var facts: [Fact]
    var evidence: [Evidence]
    var criteria: [Criterion]
    var unknowns: [DecisionUnknown]
    var verificationTasks: [VerificationTask]
    var events: [DecisionEventRecord]
}

struct DecisionPreferences: Codable, Hashable {
    var defaultCurrency = "CNY"
    var defaultExpectedStayMonths = 12
    var showEliminatedOptions = true
}

struct DecisionWorkspace: Codable, Hashable {
    var version = 1
    var currentTaskID: UUID
    var tasks: [DecisionAppState]
    var preferences = DecisionPreferences()
}

enum FactKey {
    static let city = "city"
    static let monthlyRent = "monthly_rent"
    static let rentalType = "rental_type"
    static let address = "address"
    static let area = "area"
    static let areaScope = "area_scope"
    static let layout = "layout"
    static let floor = "floor"
    static let elevator = "elevator"
    static let availableDate = "available_date"
    static let leaseMonths = "lease_months"
    static let bedroomCount = "bedroom_count"
    static let commuteMinutes = "commute_minutes"
    static let commuteCost = "commute_cost"
    static let commuteMode = "commute_mode"
    static let noise = "noise"
    static let costPrefix = "cost."
    static let criterionResultPrefix = "criterion_result."
}
