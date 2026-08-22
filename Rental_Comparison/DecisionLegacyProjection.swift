import Foundation

enum DecisionLegacyProjection {
    static func appState(from state: DecisionAppState) -> AppState {
        .init(privacyAcknowledged: state.privacyAcknowledged, task: task(from: state))
    }

    static func task(from state: DecisionAppState) -> RentalTask {
        let hunt = state.hunt
        let factsByOption = Dictionary(grouping: state.facts, by: \.optionID)
        let evidenceByOption = Dictionary(grouping: state.evidence, by: \.optionID)
        let tasksByOption = Dictionary(grouping: state.verificationTasks, by: \.optionID)
        let criteria = state.criteria.filter { hunt.criterionIDs.contains($0.id) }
        let listings = state.options.filter { hunt.optionIDs.contains($0.id) }.map { option in
            listing(
                from: option,
                facts: factsByOption[option.id] ?? [],
                evidence: evidenceByOption[option.id] ?? [],
                tasks: tasksByOption[option.id] ?? [],
                city: text(from: factsByOption[option.id]?.first(where: { $0.key == FactKey.city })?.value) ?? hunt.city,
                currency: hunt.defaultCurrency,
                criteria: criteria
            )
        }

        return .init(
            id: hunt.id,
            title: hunt.title,
            city: hunt.city,
            currency: hunt.defaultCurrency,
            expectedMonths: hunt.expectedStayMonths ?? 12,
            commuteDestination: hunt.primaryDestination ?? "",
            listings: listings,
            conditions: criteria.map { .init(id: $0.key, name: $0.title, importance: $0.importance, custom: $0.source == "user") },
            comparisonIDs: hunt.comparisonOptionIDs,
            baselineID: hunt.baselineOptionID,
            finalListingID: hunt.finalOptionID,
            finalReason: hunt.finalReason,
            events: state.events.compactMap(legacyEvent),
            completed: hunt.status == .completed
        )
    }

    private static func listing(
        from option: Option,
        facts: [Fact],
        evidence: [Evidence],
        tasks: [VerificationTask],
        city: String,
        currency: String,
        criteria: [Criterion]
    ) -> Listing {
        let factsByKey = Dictionary(grouping: facts, by: \.key)
        func firstValue(for key: String) -> FactValue? { factsByKey[key]?.first?.value }
        let conditionPairs: [(String, ConditionResult)] = criteria.compactMap { criterion in
            guard case let .text(value)? = firstValue(for: "\(FactKey.criterionResultPrefix)\(criterion.key)"),
                  let result = ConditionResult(rawValue: value) else { return nil }
            return (criterion.key, result)
        }
        let conditionResults = Dictionary(uniqueKeysWithValues: conditionPairs)
        let costs = facts.compactMap { fact -> CostItem? in
            guard fact.key.hasPrefix(FactKey.costPrefix), case let .cost(value) = fact.value else { return nil }
            return .init(id: UUID(uuidString: fact.key.replacingOccurrences(of: FactKey.costPrefix, with: "")) ?? fact.id, name: value.name, amount: value.amount, cadence: value.cadence, refundable: value.refundable, confirmed: fact.verificationState != .unknown)
        }
        let bundledImageName = evidence.first(where: { $0.bundledAssetName != nil })?.bundledAssetName
        let photoIDs = evidence.compactMap(\.mediaID)

        return .init(
            id: option.id,
            name: option.displayName,
            city: text(from: firstValue(for: FactKey.city)) ?? city,
            rentalType: rentalType(from: firstValue(for: FactKey.rentalType)),
            rent: decimal(from: firstValue(for: FactKey.monthlyRent)) ?? 0,
            currency: currency,
            status: option.decisionState == .eliminated ? .eliminated : .candidate,
            focused: option.isFocused,
            eliminationReason: option.eliminationReason,
            address: text(from: firstValue(for: FactKey.address)),
            area: decimal(from: firstValue(for: FactKey.area)),
            areaScope: text(from: firstValue(for: FactKey.areaScope)),
            layout: text(from: firstValue(for: FactKey.layout)),
            floor: text(from: firstValue(for: FactKey.floor)),
            hasElevator: boolean(from: firstValue(for: FactKey.elevator)),
            availableDate: date(from: firstValue(for: FactKey.availableDate)),
            leaseMonths: decimal(from: firstValue(for: FactKey.leaseMonths)).map(Int.init),
            roomCount: decimal(from: firstValue(for: FactKey.bedroomCount)).map(Int.init),
            commuteMinutes: decimal(from: firstValue(for: FactKey.commuteMinutes)).map(Int.init),
            commuteFare: decimal(from: firstValue(for: FactKey.commuteCost)),
            commuteMode: commuteMode(from: firstValue(for: FactKey.commuteMode)),
            bundledImageName: bundledImageName,
            photoIDs: photoIDs,
            costs: costs,
            conditionResults: conditionResults,
            inspections: tasks.map { inspection(from: $0, evidence: evidence) }
        )
    }

    private static func inspection(from task: VerificationTask, evidence: [Evidence]) -> InspectionItem {
        let inspectionState: InspectionState
        switch task.state {
        case .pending, .skipped:
            inspectionState = .unchecked
        case .verified:
            inspectionState = .okay
        case .issue:
            inspectionState = .issue
        }
        return .init(
            id: task.id.uuidString,
            name: task.title,
            state: inspectionState,
            note: task.result ?? "",
            photoIDs: evidence
                .filter { task.evidenceIDs.contains($0.id) && ($0.type == .photo || $0.type == .screenshot) }
                .compactMap(\.mediaID),
            hidden: false,
            custom: false
        )
    }

    private static func legacyEvent(_ event: DecisionEventRecord) -> DecisionEvent? {
        let type: DecisionEvent.EventType
        switch event.type {
        case .focused:
            type = .focused
        case .unfocused:
            type = .unfocused
        case .eliminated:
            type = .eliminated
        case .restored:
            type = .restored
        case .comparisonOpened:
            type = .compared
        case .confirmed:
            type = .confirmed
        case .withdrawn:
            type = .withdrawn
        case .captured, .unknownCreated, .unknownResolved, .verificationCompleted:
            return nil
        }
        guard let optionID = event.optionID else { return nil }
        return .init(id: event.id, type: type, listingID: optionID, at: event.at, reason: event.reason)
    }

    private static func text(from value: FactValue?) -> String? {
        guard case let .text(value)? = value else { return nil }
        return value
    }

    private static func decimal(from value: FactValue?) -> Double? {
        guard case let .decimal(value)? = value else { return nil }
        return value
    }

    private static func boolean(from value: FactValue?) -> Bool? {
        guard case let .boolean(value)? = value else { return nil }
        return value
    }

    private static func date(from value: FactValue?) -> Date? {
        guard case let .date(value)? = value else { return nil }
        return value
    }

    private static func rentalType(from value: FactValue?) -> RentalType {
        guard case let .text(value)? = value, let type = RentalType(rawValue: value) else { return .entire }
        return type
    }

    private static func commuteMode(from value: FactValue?) -> CommuteMode? {
        guard case let .text(value)? = value else { return nil }
        return CommuteMode(rawValue: value)
    }
}
