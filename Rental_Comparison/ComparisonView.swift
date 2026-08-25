import SwiftUI

private final class ComparisonScrollCoordinator {
    private final class WeakScrollView {
        weak var value: UIScrollView?

        init(_ value: UIScrollView) {
            self.value = value
        }
    }

    private var scrollViews: [ObjectIdentifier: WeakScrollView] = [:]
    private var observations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var lastOffsetX: CGFloat = 0
    private var isSynchronizing = false

    func register(_ scrollView: UIScrollView) {
        let id = ObjectIdentifier(scrollView)
        guard observations[id] == nil else { return }

        scrollViews[id] = WeakScrollView(scrollView)
        observations[id] = scrollView.observe(\UIScrollView.contentOffset, options: [.new]) { [weak self, weak scrollView] _, _ in
            guard let scrollView else { return }
            self?.synchronize(from: scrollView)
        }
        applyStoredOffset(to: scrollView, attemptsRemaining: 6)
    }

    private func synchronize(from source: UIScrollView) {
        guard !isSynchronizing else { return }
        lastOffsetX = source.contentOffset.x
        scrollViews = scrollViews.filter { $0.value.value != nil }

        isSynchronizing = true
        defer { isSynchronizing = false }
        for (id, weakScrollView) in scrollViews {
            guard let target = weakScrollView.value, id != ObjectIdentifier(source) else { continue }
            setHorizontalOffset(lastOffsetX, on: target)
        }
    }

    private func applyStoredOffset(to scrollView: UIScrollView, attemptsRemaining: Int) {
        DispatchQueue.main.async { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            let minimumX = -scrollView.adjustedContentInset.left
            let maximumX = max(minimumX, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right)
            guard maximumX > minimumX + 0.5 || attemptsRemaining == 0 else {
                self.applyStoredOffset(to: scrollView, attemptsRemaining: attemptsRemaining - 1)
                return
            }

            self.isSynchronizing = true
            self.setHorizontalOffset(self.lastOffsetX, on: scrollView)
            self.isSynchronizing = false
        }
    }

    private func setHorizontalOffset(_ offsetX: CGFloat, on scrollView: UIScrollView) {
        let minimumX = -scrollView.adjustedContentInset.left
        let maximumX = max(minimumX, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right)
        let targetX = min(max(offsetX, minimumX), maximumX)
        guard abs(scrollView.contentOffset.x - targetX) > 0.5 else { return }

        var targetOffset = scrollView.contentOffset
        targetOffset.x = targetX
        scrollView.setContentOffset(targetOffset, animated: false)
    }
}

private struct ComparisonScrollResolver: UIViewRepresentable {
    let coordinator: ComparisonScrollCoordinator

    func makeUIView(context: Context) -> ComparisonScrollResolverView {
        let view = ComparisonScrollResolverView()
        view.resolve = { [coordinator] scrollView in
            coordinator.register(scrollView)
        }
        return view
    }

    func updateUIView(_ uiView: ComparisonScrollResolverView, context: Context) {}
}

private final class ComparisonScrollResolverView: UIView {
    var resolve: ((UIScrollView) -> Void)?
    private var resolved = false
    private var resolutionScheduled = false
    private var remainingAttempts = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveScrollViewIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resolveScrollViewIfNeeded()
    }

    private func resolveScrollViewIfNeeded() {
        guard window != nil, !resolved, !resolutionScheduled else { return }
        resolutionScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resolutionScheduled = false

            var ancestor = self.superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView,
                   scrollView.contentSize.width > scrollView.bounds.width + 1 {
                    self.resolved = true
                    self.resolve?(scrollView)
                    return
                }
                ancestor = view.superview
            }

            guard self.remainingAttempts > 0 else { return }
            self.remainingAttempts -= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.resolveScrollViewIfNeeded()
            }
        }
    }
}

private enum ComparisonLayout {
    static let columnWidth: CGFloat = 180
    static let columnSpacing: CGFloat = 16
    static let columnContentInset: CGFloat = 16
    static let sectionHorizontalInset: CGFloat = 24
    static let titleContentSpacing: CGFloat = 16
}

struct ComparisonView: View {
    @Environment(AppStore.self) private var store
    @State private var showingManager = false
    @State private var showingFinal = false
    @State private var showingAnalysis = true
    @State private var showingFullMatrix = true
    @State private var comparisonScrollCoordinator = ComparisonScrollCoordinator()

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
                        DisclosureGroup(isExpanded: $showingFullMatrix) {
                            VStack(alignment: .leading, spacing: 28) {
                                ComparisonSection(
                                    title: "真实成本",
                                    subtitle: "月租与固定费用的月均支出",
                                    symbol: "wallet.pass",
                                    scrollCoordinator: comparisonScrollCoordinator
                                ) { listing in
                                    let summary = DecisionEngine.calculateCosts(for: listing, expectedMonths: store.task.expectedMonths)
                                    VStack(alignment: .leading, spacing: 8) {
                                        MetricValue(summary.monthlyHousing.formattedMoney(currency: listing.currency), caption: "月均居住成本")
                                        MetricValue(summary.firstCash.formattedMoney(currency: listing.currency), caption: "首期现金")
                                        if !summary.unknowns.isEmpty {
                                            StatusPill(text: "\(summary.unknowns.count) 项费用未知", systemImage: "questionmark.circle", color: .orange)
                                        }
                                    }
                                }

                                ComparisonSection(
                                    title: "通勤时间",
                                    subtitle: "前往 \(store.task.commuteDestination.isEmpty ? "主要目的地" : store.task.commuteDestination) 的单程记录",
                                    symbol: "clock",
                                    scrollCoordinator: comparisonScrollCoordinator
                                ) { listing in
                                    VStack(alignment: .leading, spacing: 8) {
                                        MetricValue(listing.commuteMinutes.map { "\($0) 分钟" } ?? "待补充", caption: listing.commuteMode?.title ?? "方式待补充")
                                            .accessibilityIdentifier("comparisonMetric-commute-\(listing.id.uuidString)")
                                        Text(listing.commuteFare.map { "\($0.formattedMoney(currency: listing.currency)) / 次" } ?? "通勤支出待补充")
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                ComparisonSection(
                                    title: "条件风险",
                                    subtitle: "硬性冲突、未知项与普通偏好",
                                    symbol: "checklist",
                                    scrollCoordinator: comparisonScrollCoordinator
                                ) { listing in
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

                                ComparisonSection(
                                    title: "看房记录",
                                    subtitle: "已记录的现场异常",
                                    symbol: "eye",
                                    scrollCoordinator: comparisonScrollCoordinator
                                ) { listing in
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
                            }
                            .padding(.top, ComparisonLayout.titleContentSpacing)
                        } label: {
                            Label("详细数据", systemImage: "list.bullet.rectangle")
                                .font(.title2.bold())
                        }
                        .padding(.horizontal, ComparisonLayout.sectionHorizontalInset)
                        .accessibilityIdentifier("comparisonDetailsDisclosure")
                        .accessibilityValue(showingFullMatrix ? "已展开" : "已收起")

                        DisclosureGroup(isExpanded: $showingAnalysis) {
                            DifferenceFirstSummary(listings: listings)
                                .padding(.top, ComparisonLayout.titleContentSpacing)
                        } label: {
                            Label("对比分析", systemImage: "chart.bar.xaxis")
                                .font(.title2.bold())
                        }
                        .padding(.horizontal, ComparisonLayout.sectionHorizontalInset)
                        .accessibilityIdentifier("comparisonAnalysisDisclosure")
                        .accessibilityValue(showingAnalysis ? "已展开" : "已收起")

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("调整") { showingManager = true } }
        .sheet(isPresented: $showingManager) { CompareManagerView() }
        .sheet(isPresented: $showingFinal) { FinalDecisionView() }
        .safeAreaInset(edge: .top, spacing: 0) {
            if listings.count >= 2 {
                ComparisonHeader(listings: listings)
                    .padding(.vertical, 8)
                    .background(.background)
                    .overlay(alignment: .bottom) { Divider() }
            }
        }
        .accessibilityIdentifier("comparisonScreen")
    }
}

private struct ComparisonHeader: View {
    @Environment(AppStore.self) private var store
    let listings: [Listing]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: ComparisonLayout.columnSpacing) {
                ForEach(listings) { listing in
                    VStack(alignment: .leading, spacing: 8) {
                        ListingImageView(listing: listing)
                            .frame(width: ComparisonLayout.columnWidth, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(listing.name)
                            .font(.headline)
                            .lineLimit(2)
                            .accessibilityIdentifier("comparisonHeader-\(listing.id.uuidString)")
                        if listing.id == store.task.baselineID {
                            StatusPill(text: "比较基准", systemImage: "pin.fill", color: .blue)
                        } else {
                            Button("设为基准") { store.updateTask { $0.baselineID = listing.id } }
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, ComparisonLayout.columnContentInset)
                    .frame(width: ComparisonLayout.columnWidth, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, ComparisonLayout.sectionHorizontalInset)
        .scrollIndicators(.hidden)
    }
}

private struct DifferenceFirstSummary: View {
    @Environment(AppStore.self) private var store
    let listings: [Listing]

    private var monthlyRentRange: ClosedRange<Double>? {
        guard !hasMixedCurrencies else { return nil }
        let values = listings.map(\.rent).filter { $0 > 0 }
        guard let minimum = values.min(), let maximum = values.max(), minimum != maximum else { return nil }
        return minimum...maximum
    }

    private var commuteRange: ClosedRange<Int>? {
        let values = listings.compactMap(\.commuteMinutes)
        guard let minimum = values.min(), let maximum = values.max(), minimum != maximum else { return nil }
        return minimum...maximum
    }

    private var hasMixedCurrencies: Bool {
        Set(listings.map { $0.currency.uppercased() }).count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            differenceSection("硬性冲突", symbol: "exclamationmark.octagon") {
                let conflicts = listings.flatMap { listing in
                    DecisionEngine.requiredConflicts(in: store.task, listing: listing).map { (listing, $0) }
                }
                if conflicts.isEmpty {
                    Label("当前没有已知硬性冲突", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    ForEach(Array(conflicts.enumerated()), id: \.offset) { _, item in
                        let listing = item.0
                        let condition = item.1
                        Label("\(listing.name)：\(condition.name)", systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            differenceSection("主要差异", symbol: "arrow.left.arrow.right") {
                if hasMixedCurrencies {
                    Label("候选使用不同货币，未进行汇率换算", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let monthlyRentRange {
                    Label("月租相差 \((monthlyRentRange.upperBound - monthlyRentRange.lowerBound).formattedMoney(currency: store.task.currency))", systemImage: "yensign.circle")
                }
                if let commuteRange {
                    Label("单程通勤相差 \(commuteRange.upperBound - commuteRange.lowerBound) 分钟", systemImage: "clock")
                }
                if monthlyRentRange == nil && commuteRange == nil {
                    Text("还没有足够的统一口径数据来突出差异。")
                        .foregroundStyle(.secondary)
                }
            }

            differenceSection("决策阻塞项", symbol: "questionmark.circle") {
                let blockers = store.state.unknowns.filter { unknown in
                    unknown.status == .open && unknown.impactLevel == .high && listings.contains { $0.id == unknown.optionID }
                }
                if blockers.isEmpty {
                    Label("当前没有高影响待确认项", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    ForEach(blockers) { blocker in
                        let optionName = store.state.options.first { $0.id == blocker.optionID }?.displayName ?? "候选"
                        Text("\(optionName)：\(blocker.reason)")
                    }
                }
            }

            differenceSection("已知取舍", symbol: "scale.3d") {
                if let cheapest = listings.filter({ $0.rent > 0 }).min(by: { $0.rent < $1.rent }),
                   let fastest = listings.compactMap({ listing in listing.commuteMinutes.map { (listing, $0) } }).min(by: { $0.1 < $1.1 }) {
                    Text("\(cheapest.name) 的月租最低；\(fastest.0.name) 的通勤最快。系统不会自动替你选择。")
                } else {
                    Text("补充月租和通勤后，这里会说明已知取舍。")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func differenceSection<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.title3.bold())
            content()
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ComparisonSection<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let scrollCoordinator: ComparisonScrollCoordinator
    @ViewBuilder let content: (Listing) -> Content
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: ComparisonLayout.columnSpacing) {
                    ForEach(store.comparisonListings) { listing in
                        content(listing)
                            .padding(.horizontal, ComparisonLayout.columnContentInset)
                            .frame(width: ComparisonLayout.columnWidth, alignment: .leading)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .overlay(alignment: .trailing) { Divider() }
                    }
                }
                .background(ComparisonScrollResolver(coordinator: scrollCoordinator))
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("comparisonSection-\(title)")
        }
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
                    PersistentFormField("选择理由（可选）") {
                        TextField("例如：通勤更短且风险可接受", text: $reason, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
                if selected != nil {
                    Section("Decision Readiness") {
                        LabeledContent("当前状态", value: readinessTitle)
                    }
                    Section("已知取舍") {
                        ForEach(tradeOffLines, id: \.self) { line in
                            Text(line)
                        }
                    }
                    if !blockers.isEmpty {
                        Section("未解决阻塞项") {
                            ForEach(blockers) { blocker in
                                Label(blocker.reason, systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    if !knownRisks.isEmpty {
                        Section("已知风险") {
                            ForEach(knownRisks) { task in
                                VStack(alignment: .leading, spacing: 3) {
                                    Label(task.title, systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    if let result = task.result, !result.isEmpty {
                                        Text(result).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Section("证据覆盖") {
                        if evidenceFacts.isEmpty {
                            Text("尚无已确认事实；请先补充决定性信息。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(evidenceFacts) { fact in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(factTitle(for: fact)).font(.subheadline.weight(.semibold))
                                    Text("\(factSourceTitle(fact.sourceType)) · \(verificationTitle(fact.verificationState))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Section("确认") {
                        Toggle(blockers.isEmpty ? "我已知晓本次取舍与风险" : "我确认继续处理未解决信息", isOn: $acknowledged)
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

    private var blockers: [DecisionUnknown] {
        guard let selectedID else { return [] }
        return store.state.unknowns.filter { $0.optionID == selectedID && $0.status == .open && $0.impactLevel == .high }
    }

    private var knownRisks: [VerificationTask] {
        guard let selectedID else { return [] }
        return store.state.verificationTasks.filter { $0.optionID == selectedID && $0.state == .issue }
    }

    private var evidenceFacts: [Fact] {
        guard let selectedID else { return [] }
        return store.state.facts.filter {
            $0.optionID == selectedID && ($0.verificationState == .userConfirmed || $0.verificationState == .observed)
        }
    }

    private var readinessTitle: String {
        guard let selectedID else { return "尚未选择" }
        switch DecisionReadinessEngine.summary(for: selectedID, in: store.state).status {
        case .notReady: return "尚未就绪"
        case .needsVerification: return "仍需验证"
        case .readyWithKnownRisks: return "带已知风险可决策"
        case .ready: return "可决策"
        }
    }

    private var tradeOffLines: [String] {
        guard let selected else { return ["选择候选后展示取舍。"] }
        let alternatives = store.candidateListings.filter { $0.id != selected.id }
        guard let reference = alternatives.compactMap({ listing in
            listing.commuteMinutes.map { (listing, $0) }
        }).min(by: { $0.1 < $1.1 })?.0 ?? alternatives.filter({ $0.rent > 0 }).min(by: { $0.rent < $1.rent }) else {
            return ["补充其他候选的月租或通勤后，会在这里展示取舍。"]
        }

        var lines: [String] = []
        if selected.rent > 0, reference.rent > 0, selected.currency.uppercased() == reference.currency.uppercased() {
            let difference = selected.rent - reference.rent
            if difference == 0 {
                lines.append("与 \(reference.name) 的月租相同。")
            } else {
                lines.append("相较 \(reference.name)，月租\(difference > 0 ? "高" : "低") \(abs(difference).formattedMoney(currency: selected.currency))。")
            }
        }
        if let selectedCommute = selected.commuteMinutes, let referenceCommute = reference.commuteMinutes {
            let difference = selectedCommute - referenceCommute
            if difference == 0 {
                lines.append("与 \(reference.name) 的单程通勤相同。")
            } else {
                lines.append("相较 \(reference.name)，单程通勤\(difference > 0 ? "多" : "少") \(abs(difference)) 分钟。")
            }
        }
        return lines.isEmpty ? ["补充其他候选的月租或通勤后，会在这里展示取舍。"] : lines
    }

    private func factTitle(for fact: Fact) -> String {
        switch fact.key {
        case FactKey.monthlyRent: "月租"
        case FactKey.commuteMinutes: "通勤时间"
        case FactKey.noise: "噪音"
        default: fact.key.replacingOccurrences(of: "user.", with: "")
        }
    }

    private func factSourceTitle(_ source: FactSourceType) -> String {
        switch source {
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

    private func verificationTitle(_ state: FactVerificationState) -> String {
        switch state {
        case .unknown: "待确认"
        case .extracted: "待核验"
        case .userConfirmed: "已确认"
        case .observed: "已现场观察"
        }
    }
}

#Preview("对比") {
    NavigationStack { ComparisonView() }
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
