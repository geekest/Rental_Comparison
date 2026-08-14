import SwiftUI

struct ComparisonView: View {
    @Environment(AppStore.self) private var store
    @State private var showingManager = false
    @State private var showingFinal = false

    private var listings: [Listing] { store.comparisonListings }

    var body: some View {
        Group {
            if listings.count < 2 {
                ContentUnavailableView {
                    Label("至少选择 2 套房源", systemImage: "slider.horizontal.3")
                } description: {
                    Text("回到房源页加入候选；一次最多比较 5 套。")
                } actions: {
                    Button("管理对比房源") { showingManager = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ComparisonHeader(listings: listings)

                        ComparisonSection(title: "真实成本", subtitle: "月租与固定费用的月均支出", symbol: "wallet.pass") { listing in
                            let summary = DecisionEngine.calculateCosts(for: listing, expectedMonths: store.task.expectedMonths)
                            VStack(alignment: .leading, spacing: 8) {
                                MetricValue(summary.monthlyHousing.formattedMoney(currency: listing.currency), caption: "月均居住成本")
                                MetricValue(summary.firstCash.formattedMoney(currency: listing.currency), caption: "首期现金")
                                if !summary.unknowns.isEmpty {
                                    StatusPill(text: "\(summary.unknowns.count) 项费用未知", systemImage: "questionmark.circle", color: .orange)
                                }
                            }
                        }

                        ComparisonSection(title: "通勤时间", subtitle: "前往 \(store.task.commuteDestination.isEmpty ? "主要目的地" : store.task.commuteDestination) 的单程记录", symbol: "clock") { listing in
                            VStack(alignment: .leading, spacing: 8) {
                                MetricValue(listing.commuteMinutes.map { "\($0) 分钟" } ?? "待补充", caption: listing.commuteMode?.title ?? "方式待补充")
                                Text(listing.commuteFare.map { "\($0.formattedMoney(currency: listing.currency)) / 次" } ?? "通勤支出待补充")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ComparisonSection(title: "条件风险", subtitle: "硬性冲突、未知项与普通偏好", symbol: "checklist") { listing in
                            VStack(alignment: .leading, spacing: 8) {
                                let conflicts = DecisionEngine.requiredConflicts(in: store.task, listing: listing)
                                if conflicts.isEmpty {
                                    StatusPill(text: "无已知硬性冲突", systemImage: "checkmark.circle.fill", color: .green)
                                } else {
                                    ForEach(conflicts) { condition in
                                        StatusPill(
                                            text: condition.name,
                                            systemImage: listing.conditionResults[condition.id] == .conflict ? "xmark.octagon.fill" : "questionmark.circle.fill",
                                            color: listing.conditionResults[condition.id] == .conflict ? .red : .orange
                                        )
                                    }
                                }
                            }
                        }

                        ComparisonSection(title: "看房记录", subtitle: "已记录的现场异常", symbol: "eye") { listing in
                            let issues = DecisionEngine.inspectionIssues(in: listing)
                            VStack(alignment: .leading, spacing: 8) {
                                if issues.isEmpty {
                                    StatusPill(text: "无已记录异常", systemImage: "checkmark.circle", color: .green)
                                } else {
                                    ForEach(issues) { issue in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Label(issue.name, systemImage: "exclamationmark.triangle.fill")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.orange)
                                            if !issue.note.isEmpty { Text(issue.note).font(.caption).foregroundStyle(.secondary) }
                                        }
                                    }
                                }
                            }
                        }

                        if store.task.completed, let finalID = store.task.finalListingID {
                            NavigationLink {
                                ResultView(finalListingID: finalID)
                            } label: {
                                Label("查看最终结果", systemImage: "checkmark.seal.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.horizontal)
                        } else {
                            Button {
                                showingFinal = true
                            } label: {
                                Text("确认最终房源").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.horizontal)
                            .accessibilityIdentifier("confirmFinalButton")
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("比较房源")
        .toolbar { Button("调整") { showingManager = true } }
        .sheet(isPresented: $showingManager) { CompareManagerView() }
        .sheet(isPresented: $showingFinal) { FinalDecisionView() }
        .accessibilityIdentifier("comparisonScreen")
    }
}
private struct ComparisonHeader: View {
    @Environment(AppStore.self) private var store
    let listings: [Listing]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(listings) { listing in
                    VStack(alignment: .leading, spacing: 8) {
                        ListingImageView(listing: listing)
                            .frame(width: 180, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(listing.name).font(.headline).lineLimit(2)
                        if listing.id == store.task.baselineID {
                            StatusPill(text: "比较基准", systemImage: "pin.fill", color: .blue)
                        } else {
                            Button("设为基准") { store.updateTask { $0.baselineID = listing.id } }
                                .font(.subheadline)
                        }
                    }
                    .frame(width: 180, alignment: .leading)
                }
            }
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollIndicators(.hidden)
    }
}

private struct ComparisonSection<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder let content: (Listing) -> Content
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(store.comparisonListings) { listing in
                        content(listing)
                            .frame(width: 220, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .overlay(alignment: .trailing) { Divider() }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal)
    }
}

private struct MetricValue: View {
    let value: String
    let caption: String
    init(_ value: String, caption: String) { self.value = value; self.caption = caption }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.bold()).minimumScaleFactor(0.75)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct CompareManagerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var limitReached = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.candidateListings) { listing in
                        Button {
                            if !store.toggleComparison(listing.id) { limitReached = true }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(listing.name).foregroundStyle(.primary)
                                    Text(listing.rent.formattedMoney(currency: listing.currency)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.task.comparisonIDs.contains(listing.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("已选择 \(store.task.comparisonIDs.count) / 5 套；至少选择 2 套才能比较。")
                }
            }
            .navigationTitle("管理对比房源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() } }
            .alert("最多比较 5 套", isPresented: $limitReached) { Button("好", role: .cancel) {} }
        }
    }
}

private struct FinalDecisionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var reason = ""
    @State private var acknowledged = false

    private var selected: Listing? { store.candidateListings.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("选择最终房源") {
                    Picker("房源", selection: $selectedID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(store.candidateListings) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    TextField("选择理由（可选）", text: $reason, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let selected {
                    let costs = DecisionEngine.calculateCosts(for: selected, expectedMonths: store.task.expectedMonths)
                    Section("确认前检查") {
                        LabeledContent("未知费用", value: costs.unknowns.isEmpty ? "无" : "\(costs.unknowns.count) 项")
                        LabeledContent("硬性风险", value: "\(DecisionEngine.requiredConflicts(in: store.task, listing: selected).count) 项")
                        LabeledContent("看房异常", value: "\(DecisionEngine.inspectionIssues(in: selected).count) 项")
                        Toggle("我已知晓仍未解决的项目", isOn: $acknowledged)
                    }
                }
            }
            .navigationTitle("最终选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        guard let selectedID else { return }
                        store.confirmFinal(selectedID, reason: reason)
                        dismiss()
                    }
                    .disabled(selectedID == nil || !acknowledged)
                    .accessibilityIdentifier("finalConfirmButton")
                }
            }
        }
    }
}
