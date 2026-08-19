import SwiftUI

struct ListingsView: View {
    @Environment(AppStore.self) private var store
    @Binding var showingTaskSettings: Bool
    let onSelectTab: (AppTab) -> Void
    @State private var showingAdd = false
    @State private var limitMessage: String?
    @State private var selectedListingID: UUID?

    private var candidates: [Listing] { store.task.listings.filter { $0.status == .candidate } }
    private var eliminated: [Listing] { store.task.listings.filter { $0.status == .eliminated } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.task.completed ? "决策已完成" : "当前选房任务")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text(store.task.title)
                        .font(.largeTitle.bold())
                    Text(summaryText)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                NextActionCard(action: NextActionEngine.nextAction(in: store.state)) { destination in
                    switch destination {
                    case .capture:
                        showingAdd = true
                    case .compare, .finalDecision:
                        onSelectTab(.comparison)
                    case .verify:
                        onSelectTab(.verify)
                    }
                }
                .padding(.horizontal)

                if candidates.isEmpty {
                    ContentUnavailableView(
                        "还没有候选房源",
                        systemImage: "house",
                        description: Text("先记下第一套候选，细节可以在之后按需补充。")
                    )
                    .frame(minHeight: 360)
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(candidates) { listing in
                                ListingCard(
                                    listing: listing,
                                    limitMessage: $limitMessage,
                                    onOpenDetails: { selectedListingID = listing.id }
                                )
                                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 32)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                }

                if !eliminated.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("已淘汰")
                            .font(.title2.bold())
                        ForEach(eliminated) { listing in
                            NavigationLink(value: listing.id) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(listing.name).font(.headline)
                                        Text(listing.eliminationReason ?? "未填写原因")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationDestination(for: UUID.self) { ListingDetailView(listingID: $0) }
        .navigationDestination(isPresented: Binding(
            get: { selectedListingID != nil },
            set: { if !$0 { selectedListingID = nil } }
        )) {
            if let selectedListingID {
                ListingDetailView(listingID: selectedListingID)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("任务设置", systemImage: "slider.horizontal.3") { showingTaskSettings = true }
                    .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("添加候选", systemImage: "plus") { showingAdd = true }
                    .accessibilityIdentifier("addListingButton")
            }
        }
        .sheet(isPresented: $showingAdd) { QuickCaptureView() }
        .alert("暂时无法加入对比", isPresented: Binding(
            get: { limitMessage != nil },
            set: { if !$0 { limitMessage = nil } }
        )) {
            Button("好", role: .cancel) { limitMessage = nil }
        } message: { Text(limitMessage ?? "") }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("listingsScreen")
    }

    private var summaryText: String {
        let blockers = DecisionReadinessEngine.huntBlockerCount(in: store.state)
        let blockerText = blockers == 0 ? "暂无高影响阻塞" : "\(blockers) 个决策阻塞"
        return "\(store.task.city) · \(candidates.count) 个候选 · \(blockerText)"
    }
}

private struct NextActionCard: View {
    let action: NextAction
    let onSelect: (NextActionDestination) -> Void

    var body: some View {
        Button { onSelect(action.destination) } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("下一步").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(action.title).font(.headline).foregroundStyle(.primary)
                    Text(action.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ListingCard: View {
    @Environment(AppStore.self) private var store
    let listing: Listing
    @Binding var limitMessage: String?
    let onOpenDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    ListingImageView(listing: listing)
                    if listing.focused {
                        StatusPill(text: "重点", systemImage: "star.fill", color: .orange)
                            .padding(12)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipped()
            VStack(alignment: .leading, spacing: 10) {
                Text(listing.name)
                    .font(.title2.bold())
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(listing.rent.formattedMoney(currency: listing.currency)).font(.title.bold())
                    Text("/ 月").foregroundStyle(.secondary)
                }
                Label(commuteText.isEmpty ? "通勤" : commuteText, systemImage: listing.commuteMode?.symbol ?? "clock")
                    .opacity(commuteText.isEmpty ? 0 : 1)
                    .accessibilityHidden(commuteText.isEmpty)
                HStack(spacing: 8) {
                    StatusPill(text: readinessText, systemImage: readinessSymbol, color: readinessColor)
                    if readiness.blockerCount > 0 {
                        Text("\(readiness.blockerCount) 项阻塞")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    } else if hasUnknownCosts {
                        Text("费用待确认")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 12) {
                    Button {
                        if !store.toggleComparison(listing.id) { limitMessage = "一次最多比较 5 套候选房源。" }
                    } label: {
                        Text(store.task.comparisonIDs.contains(listing.id) ? "已加入对比" : "加入对比")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("comparisonButton_\(listing.id.uuidString)")
                    NavigationLink(value: listing.id) {
                        Text("查看详情")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("listingDetailButton_\(listing.id.uuidString)")
                }
                .frame(maxWidth: .infinity)
            }
            .padding([.horizontal, .bottom])
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onOpenDetails)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("listingCard_\(listing.id.uuidString)")
    }

    private var hasUnknownCosts: Bool {
        !DecisionEngine.calculateCosts(for: listing, expectedMonths: store.task.expectedMonths).unknowns.isEmpty
    }

    private var readiness: DecisionReadinessSummary {
        DecisionReadinessEngine.summary(for: listing.id, in: store.state)
    }

    private var readinessText: String {
        switch readiness.status {
        case .notReady: "尚未就绪"
        case .needsVerification: "待验证"
        case .readyWithKnownRisks: "已知风险"
        case .ready: "可决策"
        }
    }

    private var readinessSymbol: String {
        switch readiness.status {
        case .notReady: "questionmark.circle"
        case .needsVerification: "exclamationmark.circle"
        case .readyWithKnownRisks: "exclamationmark.triangle"
        case .ready: "checkmark.circle"
        }
    }

    private var readinessColor: Color {
        switch readiness.status {
        case .notReady: .secondary
        case .needsVerification: .orange
        case .readyWithKnownRisks: .orange
        case .ready: .green
        }
    }

    private var commuteText: String {
        [listing.commuteMode?.title, listing.commuteMinutes.map { "\($0) 分钟" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

}

struct ListingDetailView: View {
    @Environment(AppStore.self) private var store
    let listingID: UUID
    @State private var showingEdit = false
    @State private var showingEliminate = false
    @State private var eliminationReason = ""
    @State private var showingAddUnknown = false
    @State private var unknownReason = ""

    private var listing: Listing? { store.task.listings.first { $0.id == listingID } }

    var body: some View {
        Group {
            if let listing {
                List {
                    ListingImageView(listing: listing)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                    blockerSection
                    decisionFactSection(for: listing)
                    suggestedFactsSection
                    overviewSection(for: listing)
                    decisionSection(for: listing)
                    viewingSection(for: listing)
                    eliminationSection(for: listing)
                }
                .navigationTitle(listing.name)
                .toolbar { Button("完整信息") { showingEdit = true } }
                .sheet(isPresented: $showingEdit) { ListingEditorView(existing: listing) }
                .alert("淘汰这套房源？", isPresented: $showingEliminate) {
                    TextField("原因（可选）", text: $eliminationReason)
                    Button("取消", role: .cancel) {}
                    Button("淘汰", role: .destructive) { store.toggleEliminated(listing.id, reason: eliminationReason) }
                } message: { Text("房源会退出当前对比，但可以随时恢复。") }
                .alert("添加待确认事项", isPresented: $showingAddUnknown) {
                    TextField("例如：确认夜间噪音", text: $unknownReason)
                    Button("取消", role: .cancel) { unknownReason = "" }
                    Button("添加") {
                        store.createUnknown(optionID: listing.id, reason: unknownReason)
                        unknownReason = ""
                    }
                } message: {
                    Text("系统会将其作为高影响事项，并生成可执行的验证任务。")
                }
            } else {
                ContentUnavailableView("房源不存在", systemImage: "house.slash")
            }
        }
    }

    private func fact(for key: String) -> Fact? {
        store.state.facts.first { $0.optionID == listingID && $0.key == key }
    }

    @ViewBuilder private var blockerSection: some View {
        if !openUnknowns.isEmpty {
            Section("决策阻塞项") {
                ForEach(openUnknowns) { unknown in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(unknown.reason, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text(unknown.impactLevel == .high ? "高影响：解决前可能改变选择" : "待确认")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func decisionFactSection(for listing: Listing) -> some View {
        Section("决策事实") {
            DecisionFactRow(title: "月租", value: listing.rent > 0 ? listing.rent.formattedMoney(currency: listing.currency) : "待补充", fact: fact(for: FactKey.monthlyRent))
            DecisionFactRow(title: "通勤", value: listing.commuteMinutes.map { "\($0) 分钟" } ?? "待补充", fact: fact(for: FactKey.commuteMinutes))
            DecisionFactRow(title: "租期", value: listing.leaseMonths.map { "\($0) 个月" } ?? "待补充", fact: fact(for: FactKey.leaseMonths))
        }
    }

    @ViewBuilder private var suggestedFactsSection: some View {
        if !missingDecisionFacts.isEmpty {
            Section {
                ForEach(missingDecisionFacts, id: \.self) { item in
                    Label(item, systemImage: "plus.circle")
                }
            } header: {
                Text("建议下一步补充")
            } footer: {
                Text("只补充会帮助你做出选择的信息，不需要一次填完整张表。")
            }
        }
    }

    private func overviewSection(for listing: Listing) -> some View {
        Section("概览") {
            LabeledContent("月租", value: listing.rent.formattedMoney(currency: listing.currency))
            LabeledContent("租赁方式", value: listing.roomDescription)
            LabeledContent("面积", value: listing.area.map { "\($0.formatted()) \(areaUnit) · \(listing.areaScope ?? "范围待补充")" } ?? "待补充")
            LabeledContent("楼层", value: listing.floor ?? "待补充")
            LabeledContent("地址", value: listing.address ?? "待补充")
        }
    }

    private func decisionSection(for listing: Listing) -> some View {
        Section("决策") {
            Toggle("重点考虑", isOn: Binding(get: { listing.focused }, set: { _ in store.toggleFocus(listing.id) }))
            Toggle("加入本次对比", isOn: Binding(get: { store.task.comparisonIDs.contains(listing.id) }, set: { _ in _ = store.toggleComparison(listing.id) }))
                .disabled(listing.status == .eliminated)
            Button("添加待确认事项", systemImage: "questionmark.circle") { showingAddUnknown = true }
        }
    }

    private func viewingSection(for listing: Listing) -> some View {
        Section {
            if searchStage == .viewingPlanned {
                NavigationLink { ViewingModeView(optionID: listing.id) } label: {
                    Label("开始验证这套房", systemImage: "eye")
                }
                .accessibilityIdentifier("startViewingButton")
            } else {
                Button("计划看房", systemImage: "calendar.badge.plus") {
                    store.setSearchStage(.viewingPlanned, for: listing.id)
                }
                .accessibilityIdentifier("scheduleViewingButton")
            }
            NavigationLink("完整检查（可选）") { InspectionView(listingID: listing.id) }
        } header: {
            Text("现场验证")
        } footer: {
            Text(searchStage == .viewingPlanned ? "优先确认本套房会影响选择的事项。" : "计划看房后，系统会把现场风险转为可执行验证。")
        }
    }

    private func eliminationSection(for listing: Listing) -> some View {
        Section {
            Button(listing.status == .candidate ? "淘汰这套房源" : "恢复到候选池", role: listing.status == .candidate ? .destructive : nil) {
                if listing.status == .candidate { showingEliminate = true } else { store.toggleEliminated(listing.id) }
            }
        }
    }

    private var openUnknowns: [DecisionUnknown] {
        store.state.unknowns.filter { $0.optionID == listingID && $0.status == .open }
    }

    private var searchStage: SearchStage {
        store.state.options.first { $0.id == listingID }?.searchStage ?? .saved
    }

    private var areaUnit: String {
        RegionalTemplateCatalog.template(id: store.state.hunt.regionTemplateID).areaUnit
    }

    private var missingDecisionFacts: [String] {
        var values: [String] = []
        if fact(for: FactKey.monthlyRent) == nil { values.append("月租") }
        if fact(for: FactKey.commuteMinutes) == nil { values.append("通勤时间") }
        if fact(for: FactKey.leaseMonths) == nil { values.append("租期") }
        return values
    }
}

private struct DecisionFactRow: View {
    let title: String
    let value: String
    let fact: Fact?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: value)
            if let fact {
                Text("来源：\(fact.sourceType.title) · \(fact.verificationState.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未记录或确认")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private extension FactSourceType {
    var title: String {
        switch self {
        case .screenshot: "截图"
        case .photo: "照片"
        case .userObservation: "现场观察"
        case .manual: "手动记录"
        case .listing: "房源信息"
        case .agentMessage: "中介消息"
        case .agentVerbal: "口头承诺"
        case .contract: "合同"
        }
    }
}

private extension FactVerificationState {
    var title: String {
        switch self {
        case .unknown: "待确认"
        case .extracted: "待核验"
        case .userConfirmed: "已确认"
        case .observed: "已现场观察"
        }
    }
}
