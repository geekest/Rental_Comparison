import SwiftUI

enum AppTab: Hashable {
    case hunt
    case verify
    case comparison
    case settings
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .hunt
    @State private var showingTaskSettings = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-startComparison") {
            _selectedTab = State(initialValue: .comparison)
        } else if arguments.contains("-startVerify") {
            _selectedTab = State(initialValue: .verify)
        } else {
            _selectedTab = State(initialValue: .hunt)
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ListingsView(
                        showingTaskSettings: $showingTaskSettings,
                        onSelectTab: { selectedTab = $0 }
                    )
                }
                .tabItem { Label("选房", systemImage: "house.fill") }
                .tag(AppTab.hunt)

                NavigationStack {
                    VerifyView()
                }
                .tabItem { Label("待确认", systemImage: "checklist.checked") }
                .badge(DecisionReadinessEngine.huntBlockerCount(in: store.state))
                .tag(AppTab.verify)

                NavigationStack {
                    ComparisonView()
                }
                .tabItem { Label("对比", systemImage: "square.split.2x1") }
                .badge(store.task.comparisonIDs.count)
                .tag(AppTab.comparison)

                NavigationStack { SettingsView() }
                    .tabItem { Label("设置", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(WarmDesign.moss)
            .toolbarBackground(WarmDesign.canvas, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .accessibilityIdentifier("mainTabView")

            if !store.state.privacyAcknowledged {
                PrivacyNoticeView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showingTaskSettings) {
            TaskSettingsView()
        }
        .sheet(isPresented: Binding(
            get: { store.pendingImportURL != nil },
            set: { if !$0 { store.clearPendingImportURL() } }
        )) {
            if let url = store.pendingImportURL {
                ListingLinkImportView(initialURL: url)
            }
        }
        .alert("无法保存", isPresented: Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.clearSaveError() } }
        )) {
            Button("好", role: .cancel) { store.clearSaveError() }
        } message: {
            Text(store.saveError ?? "请稍后重试。")
        }
    }
}

private struct PrivacyNoticeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            WarmDesign.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(WarmDesign.moss)
                    .accessibilityHidden(true)
                Text("你的房源，只保存在这台设备")
                    .font(.largeTitle.bold())
                Text("租金、地址、照片和选择记录不会上传到业务服务器。卸载 App 会删除本地内容，请在需要时导出决策报告。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Button("开始整理") {
                    withAnimation { store.acceptPrivacy() }
                }
                .buttonStyle(.borderedProminent)
                .tint(WarmDesign.moss)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("acceptPrivacyButton")
                Spacer()
            }
            .padding(28)
        }
    }
}

private struct TaskSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var city = ""
    @State private var destination = ""
    @State private var expectedMonths = 12
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("我的选房任务") {
                    ForEach(store.tasks) { task in
                        Button {
                            load(task)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title).foregroundStyle(WarmDesign.ink)
                                    Text("\(task.city.isEmpty ? "城市待补充" : task.city) · \(task.listings.count) 套候选")
                                        .font(.caption).foregroundStyle(WarmDesign.secondaryInk)
                                }
                                Spacer()
                                if task.id == store.task.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(WarmDesign.moss) }
                            }
                        }
                        .swipeActions {
                            if store.tasks.count > 1 {
                                Button("删除", role: .destructive) { store.deleteTask(task.id) }
                            }
                        }
                    }
                    Button("新建选房任务", systemImage: "plus") {
                        isCreating = true
                        title = ""
                        city = ""
                        destination = ""
                        expectedMonths = store.preferences.defaultExpectedStayMonths
                    }
                }
                Section("选房任务") {
                    PersistentFormField("任务名称") {
                        TextField("例如：上海租房计划", text: $title)
                    }
                    PersistentFormField("城市") {
                        TextField("例如：上海", text: $city)
                    }
                    PersistentFormField("主要通勤目的地") {
                        TextField("例如：公司", text: $destination)
                    }
                    Stepper("预计居住 \(expectedMonths) 个月", value: $expectedMonths, in: 1...60)
                }
                Section {
                    NavigationLink("管理优先级与硬性条件") {
                        ConditionsView()
                    }
                } header: {
                    Text("选房重点")
                } footer: {
                    Text("优先级用于帮助识别冲突，不会生成综合评分或自动推荐。")
                }
                Section {
                    Button("恢复示例数据", role: .destructive) {
                        store.resetToFixtures()
                        dismiss()
                    }
                } footer: {
                    Text("恢复示例数据会替换当前设备上的选房任务。")
                }
            }
            .navigationTitle("任务设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if isCreating {
                            store.createTask(title: title, city: city, destination: destination, expectedMonths: expectedMonths)
                        } else {
                            store.updateTask {
                                $0.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                $0.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
                                $0.commuteDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                                $0.expectedMonths = expectedMonths
                            }
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                load(store.task)
            }
        }
    }

    private func load(_ task: RentalTask) {
        store.switchTask(to: task.id)
        isCreating = false
        title = task.title
        city = task.city
        destination = task.commuteDestination
        expectedMonths = task.expectedMonths
    }
}

#Preview {
    RootView()
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
