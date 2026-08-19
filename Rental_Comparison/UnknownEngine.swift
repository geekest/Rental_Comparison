import Foundation

enum UnknownEngine {
    static func refresh(in state: inout DecisionAppState, now: Date = .now) {
        let existing = Dictionary(uniqueKeysWithValues: state.unknowns.map { (unknownKey(for: $0), $0) })
        let desired = desiredUnknowns(in: state)
        let desiredKeys = Set(desired.map(unknownKey(for:)))

        var reconciled = desired.map { candidate -> DecisionUnknown in
            let key = unknownKey(for: candidate)
            guard var current = existing[key] else { return candidate }
            current.impactLevel = candidate.impactLevel
            current.reason = candidate.reason
            if current.status == .resolved,
               state.verificationTasks.contains(where: { $0.unknownID == current.id && ($0.state == .verified || $0.state == .issue) }) {
                return current
            }
            current.status = .open
            current.resolvedAt = nil
            return current
        }

        for unknown in state.unknowns where !desiredKeys.contains(unknownKey(for: unknown)) {
            if unknown.factKey.hasPrefix("system.") {
                var resolved = unknown
                resolved.status = .resolved
                resolved.resolvedAt = now
                reconciled.append(resolved)
            } else {
                reconciled.append(unknown)
            }
        }
        state.unknowns = reconciled
    }

    private static func desiredUnknowns(in state: DecisionAppState) -> [DecisionUnknown] {
        let factsByOption = Dictionary(grouping: state.facts, by: \.optionID)
        let criteria = state.criteria.filter { state.hunt.criterionIDs.contains($0.id) }
        return state.options
            .filter { $0.decisionState != .eliminated }
            .flatMap { option in
                let facts = factsByOption[option.id] ?? []
                var unknowns: [DecisionUnknown] = []
                if fact(for: FactKey.monthlyRent, in: facts) == nil {
                    unknowns.append(make(optionID: option.id, key: "system.\(FactKey.monthlyRent)", reason: "月租仍待确认", impact: .high))
                }
                for fact in facts where isUnknownCost(fact) {
                    unknowns.append(make(optionID: option.id, key: "system.\(fact.key)", reason: "\(costName(from: fact) ?? "费用")仍待确认", impact: .high))
                }
                for criterion in criteria where criterion.importance == .required {
                    let result = fact(for: "\(FactKey.criterionResultPrefix)\(criterion.key)", in: facts)
                    if case let .text(value)? = result?.value, value != ConditionResult.unknown.rawValue {
                        continue
                    }
                    unknowns.append(make(optionID: option.id, key: "system.criterion.\(criterion.key)", reason: "硬性条件“\(criterion.title)”仍待确认", impact: .high))
                }
                return unknowns
            }
    }

    private static func make(optionID: UUID, key: String, reason: String, impact: UnknownImpactLevel) -> DecisionUnknown {
        .init(id: UUID(), optionID: optionID, factKey: key, impactLevel: impact, reason: reason, status: .open, createdAt: .now, resolvedAt: nil)
    }

    private static func fact(for key: String, in facts: [Fact]) -> Fact? {
        facts.first { $0.key == key }
    }

    private static func isUnknownCost(_ fact: Fact) -> Bool {
        guard fact.key.hasPrefix(FactKey.costPrefix), case let .cost(cost) = fact.value else { return false }
        return cost.amount == nil || fact.verificationState == .unknown
    }

    private static func costName(from fact: Fact) -> String? {
        guard case let .cost(cost) = fact.value else { return nil }
        return cost.name.nilIfBlank
    }

    private static func unknownKey(for unknown: DecisionUnknown) -> String {
        "\(unknown.optionID.uuidString):\(unknown.factKey)"
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
