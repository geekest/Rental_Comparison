import Foundation

struct CostSummary: Equatable {
    var monthlyHousing: Double
    var firstCash: Double
    var monthlyFees: Double
    var amortizedOneTime: Double
    var unknowns: [String]
}

enum DecisionEngine {
    static func calculateCosts(for listing: Listing, expectedMonths: Int) -> CostSummary {
        let unknowns = listing.costs.filter { !$0.confirmed || $0.amount == nil }.map(\.name)
        let known = listing.costs.filter { $0.confirmed && $0.amount != nil }
        let monthlyFees = known.filter { $0.cadence != .oneTime }.reduce(0) { $0 + monthlyAmount(for: $1) }
        let amortized = known.filter { $0.cadence == .oneTime && !$0.refundable }
            .reduce(0) { $0 + ($1.amount ?? 0) / Double(max(expectedMonths, 1)) }
        let firstCash = known.filter { $0.cadence == .oneTime }.reduce(0) { $0 + ($1.amount ?? 0) }
        return CostSummary(
            monthlyHousing: listing.rent + monthlyFees + amortized,
            firstCash: firstCash,
            monthlyFees: monthlyFees,
            amortizedOneTime: amortized,
            unknowns: unknowns
        )
    }

    static func monthlyAmount(for item: CostItem) -> Double {
        let amount = item.amount ?? 0
        return switch item.cadence {
        case .daily: amount * 30
        case .monthly, .oneTime: amount
        case .quarterly: amount / 3
        case .semiAnnual: amount / 6
        case .annual: amount / 12
        }
    }

    static func requiredConflicts(in task: RentalTask, listing: Listing) -> [ConditionDefinition] {
        task.conditions.filter { $0.importance == .required && listing.conditionResults[$0.id] != .met }
    }

    static func inspectionIssues(in listing: Listing) -> [InspectionItem] {
        listing.inspections.filter { !$0.hidden && $0.state == .issue }
    }

    static func normalize(_ task: inout RentalTask) {
        let candidateIDs = Set(task.listings.filter { $0.status == .candidate }.map(\.id))
        task.comparisonIDs = Array(task.comparisonIDs.filter(candidateIDs.contains).prefix(5))
        if task.baselineID.map({ !task.comparisonIDs.contains($0) }) ?? true {
            task.baselineID = task.comparisonIDs.first
        }
        if let finalID = task.finalListingID, !candidateIDs.contains(finalID) {
            task.finalListingID = nil
            task.finalReason = nil
            task.completed = false
        }
    }

    static func comparisonListings(in task: RentalTask) -> [Listing] {
        let indexed = Dictionary(uniqueKeysWithValues: task.listings.map { ($0.id, $0) })
        var listings = task.comparisonIDs.compactMap { indexed[$0] }
        guard let baselineID = task.baselineID,
              let index = listings.firstIndex(where: { $0.id == baselineID }) else { return listings }
        let baseline = listings.remove(at: index)
        listings.insert(baseline, at: 0)
        return listings
    }
}

extension Double {
    func formattedMoney(currency: String) -> String {
        formatted(.currency(code: currency.uppercased()).precision(.fractionLength(0)).locale(.autoupdatingCurrent))
    }
}
