import Foundation

enum VerificationTaskEngine {
    static func sync(in state: inout DecisionAppState) {
        let openUnknowns = state.unknowns.filter { $0.status == .open }
        for unknown in openUnknowns where !state.verificationTasks.contains(where: { $0.unknownID == unknown.id }) {
            state.verificationTasks.append(.init(
                id: UUID(),
                optionID: unknown.optionID,
                unknownID: unknown.id,
                type: taskType(for: unknown),
                title: unknown.reason,
                instruction: instruction(for: unknown),
                state: .pending,
                result: nil,
                evidenceIDs: []
            ))
        }
    }

    private static func taskType(for unknown: DecisionUnknown) -> VerificationTaskType {
        if unknown.factKey.contains(FactKey.noise) { return .observe }
        if unknown.factKey.contains("criterion") { return .check }
        return .ask
    }

    private static func instruction(for unknown: DecisionUnknown) -> String {
        if unknown.factKey.contains(FactKey.noise) {
            return "看房时关闭窗户静听 30 秒，再记录是否存在持续噪音。"
        }
        if unknown.factKey.contains("criterion") {
            return "看房或联系对方时，确认这项条件，并记录实际情况。"
        }
        return "向房东或中介确认具体信息，并保存可追溯的记录。"
    }
}
