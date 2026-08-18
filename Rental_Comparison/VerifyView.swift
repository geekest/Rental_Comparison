import SwiftUI

struct VerifyView: View {
    @Environment(AppStore.self) private var store

    private var highImpactUnknowns: [DecisionUnknown] {
        store.state.unknowns.filter { $0.status == .open && $0.impactLevel == .high }
    }

    private var pendingTasks: [VerificationTask] {
        store.state.verificationTasks.filter { $0.state == .pending }
    }

    private var completedTasks: [VerificationTask] {
        store.state.verificationTasks.filter { $0.state == .verified || $0.state == .issue }
    }

    var body: some View {
        List {
            Section {
                Text("优先处理会改变选择的未知项；每次看房或询问都应减少一个明确的不确定性。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !highImpactUnknowns.isEmpty {
                Section("决策阻塞项") {
                    ForEach(highImpactUnknowns) { unknown in
                        NavigationLink {
                            ListingDetailView(listingID: unknown.optionID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unknown.reason).font(.headline)
                                Text(optionName(for: unknown.optionID))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !pendingTasks.isEmpty {
                Section("下一次需要确认") {
                    ForEach(pendingTasks) { task in
                        NavigationLink {
                            ListingDetailView(listingID: task.optionID)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(task.title, systemImage: task.type.symbol)
                                    .font(.headline)
                                Text(optionName(for: task.optionID))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(task.instruction)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !completedTasks.isEmpty {
                Section("已记录的验证") {
                    ForEach(completedTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(task.title, systemImage: task.state == .issue ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(task.state == .issue ? .orange : .green)
                            Text(optionName(for: task.optionID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let result = task.result, !result.isEmpty {
                                Text(result).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if highImpactUnknowns.isEmpty && pendingTasks.isEmpty && completedTasks.isEmpty {
                ContentUnavailableView(
                    "暂时没有待确认事项",
                    systemImage: "checkmark.circle",
                    description: Text("添加候选或记录新的待确认信息后，会在这里生成下一步。")
                )
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("待确认")
        .accessibilityIdentifier("verifyScreen")
    }

    private func optionName(for optionID: UUID) -> String {
        store.state.options.first { $0.id == optionID }?.displayName ?? "已移除的候选"
    }
}

private extension VerificationTaskType {
    var symbol: String {
        switch self {
        case .ask: "message"
        case .check: "checklist"
        case .observe: "eye"
        case .photo: "camera"
        case .measure: "ruler"
        }
    }
}
