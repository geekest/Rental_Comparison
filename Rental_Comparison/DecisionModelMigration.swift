import Foundation

enum DecisionModelMigration {
    static func migrate(_ legacy: AppState, now: Date = .now) -> DecisionAppState {
        let task = legacy.task
        let huntID = task.id
        let criteria = task.conditions.map {
            Criterion(id: UUID(), huntID: huntID, key: $0.id, title: $0.name, importance: $0.importance, source: $0.custom ? "user" : "china-mainland")
        }

        var facts: [Fact] = []
        var evidence: [Evidence] = []
        var verificationTasks: [VerificationTask] = []
        var options: [Option] = []

        for listing in task.listings {
            let optionID = listing.id
            var optionFacts: [Fact] = []
            var optionEvidence: [Evidence] = []
            var optionTasks: [VerificationTask] = []

            if listing.rent > 0 {
                optionFacts.append(fact(optionID: optionID, key: FactKey.monthlyRent, value: .decimal(listing.rent), now: now))
            }
            optionFacts.append(fact(optionID: optionID, key: FactKey.rentalType, value: .text(listing.rentalType.rawValue), now: now))
            appendOptionalText(listing.address, key: FactKey.address, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDecimal(listing.area, key: FactKey.area, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalText(listing.areaScope, key: FactKey.areaScope, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalText(listing.layout, key: FactKey.layout, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalText(listing.floor, key: FactKey.floor, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalBoolean(listing.hasElevator, key: FactKey.elevator, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDate(listing.availableDate, key: FactKey.availableDate, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDecimal(listing.leaseMonths.map(Double.init), key: FactKey.leaseMonths, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDecimal(listing.roomCount.map(Double.init), key: FactKey.bedroomCount, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDecimal(listing.commuteMinutes.map(Double.init), key: FactKey.commuteMinutes, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalDecimal(listing.commuteFare, key: FactKey.commuteCost, optionID: optionID, into: &optionFacts, now: now)
            appendOptionalText(listing.commuteMode?.rawValue, key: FactKey.commuteMode, optionID: optionID, into: &optionFacts, now: now)

            for cost in listing.costs {
                optionFacts.append(fact(
                    optionID: optionID,
                    key: "\(FactKey.costPrefix)\(cost.id.uuidString)",
                    value: .cost(.init(name: cost.name, amount: cost.amount, currency: listing.currency, cadence: cost.cadence, refundable: cost.refundable)),
                    verificationState: cost.confirmed ? .userConfirmed : .unknown,
                    now: now
                ))
            }

            for (criterionID, result) in listing.conditionResults {
                optionFacts.append(fact(optionID: optionID, key: "\(FactKey.criterionResultPrefix)\(criterionID)", value: .text(result.rawValue), now: now))
            }

            for photoID in listing.photoIDs {
                optionEvidence.append(.init(id: UUID(), optionID: optionID, type: .photo, mediaID: photoID, bundledAssetName: nil, text: nil, sourceURL: nil, capturedAt: now))
            }
            if let bundledImageName = listing.bundledImageName {
                optionEvidence.append(.init(id: UUID(), optionID: optionID, type: .listing, mediaID: nil, bundledAssetName: bundledImageName, text: nil, sourceURL: nil, capturedAt: now))
            }

            for inspection in listing.inspections where !inspection.hidden {
                var inspectionEvidence: [Evidence] = []
                if !inspection.note.isEmpty {
                    inspectionEvidence.append(.init(id: UUID(), optionID: optionID, type: .userObservation, mediaID: nil, bundledAssetName: nil, text: inspection.note, sourceURL: nil, capturedAt: now))
                }
                inspectionEvidence += inspection.photoIDs.map {
                    .init(id: UUID(), optionID: optionID, type: .photo, mediaID: $0, bundledAssetName: nil, text: nil, sourceURL: nil, capturedAt: now)
                }
                optionEvidence += inspectionEvidence
                optionTasks.append(.init(
                    id: UUID(),
                    optionID: optionID,
                    unknownID: nil,
                    type: .check,
                    title: inspection.name,
                    instruction: "看房时检查\(inspection.name)。",
                    state: legacyTaskState(for: inspection.state),
                    result: inspection.note.nilIfBlank,
                    evidenceIDs: inspectionEvidence.map(\.id)
                ))
            }

            facts += optionFacts
            evidence += optionEvidence
            verificationTasks += optionTasks
            options.append(.init(
                id: optionID,
                huntID: huntID,
                displayName: listing.name,
                searchStage: listing.inspections.contains { $0.state != .unchecked } ? .viewed : .saved,
                decisionState: decisionState(for: listing, finalID: task.finalListingID),
                isFocused: listing.focused,
                eliminationReason: listing.eliminationReason,
                sourceRefs: [],
                factIDs: optionFacts.map(\.id),
                evidenceIDs: optionEvidence.map(\.id),
                verificationTaskIDs: optionTasks.map(\.id),
                createdAt: now,
                updatedAt: now
            ))
        }

        let hunt = Hunt(
            id: huntID,
            title: task.title,
            regionTemplateID: "china-mainland",
            city: task.city,
            defaultCurrency: task.currency,
            expectedStayMonths: task.expectedMonths,
            primaryDestination: task.commuteDestination.nilIfBlank,
            optionIDs: options.map(\.id),
            criterionIDs: criteria.map(\.id),
            comparisonOptionIDs: task.comparisonIDs,
            baselineOptionID: task.baselineID,
            finalOptionID: task.finalListingID,
            finalReason: task.finalReason,
            status: task.completed ? .completed : .active,
            createdAt: now,
            updatedAt: now
        )

        return .init(
            privacyAcknowledged: legacy.privacyAcknowledged,
            hunt: hunt,
            options: options,
            facts: facts,
            evidence: evidence,
            criteria: criteria,
            unknowns: [],
            verificationTasks: verificationTasks,
            events: task.events.map { event in
                .init(id: event.id, type: eventType(for: event.type), optionID: event.listingID, at: event.at, reason: event.reason)
            }
        )
    }

    private static func fact(
        optionID: UUID,
        key: String,
        value: FactValue,
        verificationState: FactVerificationState = .userConfirmed,
        now: Date
    ) -> Fact {
        .init(id: UUID(), optionID: optionID, key: key, value: value, sourceType: .manual, sourceRef: nil, verificationState: verificationState, evidenceIDs: [], capturedAt: now, updatedAt: now)
    }

    private static func appendOptionalText(_ value: String?, key: String, optionID: UUID, into facts: inout [Fact], now: Date) {
        guard let value = value?.nilIfBlank else { return }
        facts.append(fact(optionID: optionID, key: key, value: .text(value), now: now))
    }

    private static func appendOptionalDecimal(_ value: Double?, key: String, optionID: UUID, into facts: inout [Fact], now: Date) {
        guard let value else { return }
        facts.append(fact(optionID: optionID, key: key, value: .decimal(value), now: now))
    }

    private static func appendOptionalBoolean(_ value: Bool?, key: String, optionID: UUID, into facts: inout [Fact], now: Date) {
        guard let value else { return }
        facts.append(fact(optionID: optionID, key: key, value: .boolean(value), now: now))
    }

    private static func appendOptionalDate(_ value: Date?, key: String, optionID: UUID, into facts: inout [Fact], now: Date) {
        guard let value else { return }
        facts.append(fact(optionID: optionID, key: key, value: .date(value), now: now))
    }

    private static func decisionState(for listing: Listing, finalID: UUID?) -> OptionDecisionState {
        if listing.id == finalID { return .final }
        return listing.status == .eliminated ? .eliminated : .candidate
    }

    private static func legacyTaskState(for state: InspectionState) -> VerificationTaskState {
        switch state {
        case .unchecked: .pending
        case .okay: .verified
        case .issue: .issue
        }
    }

    private static func eventType(for type: DecisionEvent.EventType) -> DecisionEventRecord.EventType {
        switch type {
        case .focused: .focused
        case .unfocused: .unfocused
        case .eliminated: .eliminated
        case .restored: .restored
        case .compared: .comparisonOpened
        case .confirmed: .confirmed
        case .withdrawn: .withdrawn
        }
    }
}
private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
