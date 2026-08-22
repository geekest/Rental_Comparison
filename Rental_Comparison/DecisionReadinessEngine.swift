import Foundation

struct DecisionReadinessSummary: Hashable {
    var status: DecisionReadiness
    var blockerCount: Int
    var openUnknownCount: Int
    var knownRiskCount: Int
}

enum DecisionReadinessEngine {
    static func summary(for optionID: UUID, in state: DecisionAppState) -> DecisionReadinessSummary {
        guard let option = state.options.first(where: { $0.id == optionID }), option.decisionState != .eliminated else {
            return .init(status: .notReady, blockerCount: 0, openUnknownCount: 0, knownRiskCount: 0)
        }

        let openUnknowns = state.unknowns.filter { $0.optionID == optionID && $0.status == .open }
        let blockers = openUnknowns.filter { $0.impactLevel == .high }
        let knownRisks = state.verificationTasks.filter { $0.optionID == optionID && $0.state == .issue }

        if !blockers.isEmpty {
            return .init(status: .needsVerification, blockerCount: blockers.count, openUnknownCount: openUnknowns.count, knownRiskCount: knownRisks.count)
        }
        if !knownRisks.isEmpty {
            return .init(status: .readyWithKnownRisks, blockerCount: 0, openUnknownCount: openUnknowns.count, knownRiskCount: knownRisks.count)
        }
        return .init(status: .ready, blockerCount: 0, openUnknownCount: openUnknowns.count, knownRiskCount: 0)
    }

    static func huntBlockerCount(in state: DecisionAppState) -> Int {
        state.unknowns.filter { $0.status == .open && $0.impactLevel == .high }.count
    }
}

enum NextActionDestination: Hashable {
    case verify
    case compare
    case capture
    case finalDecision
}

struct NextAction: Hashable {
    var title: String
    var detail: String
    var destination: NextActionDestination
}

enum NextActionEngine {
    static func nextAction(in state: DecisionAppState) -> NextAction {
        let candidates = state.options.filter { $0.decisionState != .eliminated }
        let highImpactUnknown = state.unknowns.first { $0.status == .open && $0.impactLevel == .high }
        if let highImpactUnknown, let option = state.options.first(where: { $0.id == highImpactUnknown.optionID }) {
            return .init(title: "优先确认：\(highImpactUnknown.reason)", detail: "\(option.displayName) 有高影响待确认事项", destination: .verify)
        }

        let plannedViewing = state.options.first { $0.decisionState != .eliminated && $0.searchStage == .viewingPlanned }
        if let plannedViewing {
            return .init(title: "准备看房：\(plannedViewing.displayName)", detail: "查看本次需要确认的事项", destination: .verify)
        }

        if candidates.count >= 2 && state.hunt.comparisonOptionIDs.count < 2 {
            return .init(title: "已有 \(candidates.count) 个候选可对比", detail: "先看清会改变选择的差异", destination: .compare)
        }

        if candidates.count < 2 {
            return .init(title: "再添加一个候选", detail: "至少保留 2 个方案，才能比较真实差异", destination: .capture)
        }

        let summaries = candidates.map { DecisionReadinessEngine.summary(for: $0.id, in: state) }
        if summaries.allSatisfy({ $0.status == .ready || $0.status == .readyWithKnownRisks }) {
            return .init(title: "候选已具备决策条件", detail: "查看已知取舍后确认最终方案", destination: .finalDecision)
        }
        return .init(title: "继续补齐决策信息", detail: "优先处理会影响选择的待确认事项", destination: .verify)
    }
}
