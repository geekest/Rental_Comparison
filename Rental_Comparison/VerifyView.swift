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

    private var viewingOptions: [Option] {
        store.state.options.filter { $0.decisionState != .eliminated && $0.searchStage == .viewingPlanned }
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

            if !viewingOptions.isEmpty {
                Section("即将看房") {
                    ForEach(viewingOptions) { option in
                        NavigationLink {
                            ViewingModeView(optionID: option.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.displayName).font(.headline)
                                Text("先处理 \(pendingTasks.filter { $0.optionID == option.id }.count) 项待验证信息")
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
                            VerificationTaskDetailView(taskID: task.id)
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

struct ViewingModeView: View {
    @Environment(AppStore.self) private var store
    let optionID: UUID

    private var option: Option? {
        store.state.options.first { $0.id == optionID }
    }

    private var pendingTasks: [VerificationTask] {
        store.state.verificationTasks.filter { $0.optionID == optionID && $0.state == .pending }
    }

    var body: some View {
        List {
            Section {
                Text("优先完成会改变选择的现场观察；正常项不需要填写说明。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if pendingTasks.isEmpty {
                ContentUnavailableView("本次没有待确认事项", systemImage: "checkmark.circle")
                    .listRowBackground(Color.clear)
            } else {
                Section("本次需要确认 \(pendingTasks.count) 项") {
                    ForEach(pendingTasks) { task in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(task.title, systemImage: task.type.symbol)
                                .font(.headline)
                            Text(task.instruction)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("正常") {
                                    store.completeVerificationTask(task.id, state: .verified, result: nil, photoIDs: [])
                                }
                                .buttonStyle(.borderedProminent)
                                NavigationLink("记录问题") {
                                    VerificationTaskDetailView(taskID: task.id)
                                }
                                .buttonStyle(.bordered)
                                Button("跳过") {
                                    store.completeVerificationTask(task.id, state: .skipped, result: nil, photoIDs: [])
                                }
                                .buttonStyle(.bordered)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(option?.displayName ?? "现场验证")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if option?.searchStage == .viewingPlanned {
                Button("完成看房") {
                    store.setSearchStage(.viewed, for: optionID)
                }
            }
        }
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
