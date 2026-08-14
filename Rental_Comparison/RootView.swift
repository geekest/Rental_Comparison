import SwiftUI

enum AppTab: Hashable {
    case listings
    case comparison
    case conditions
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .listings
    @State private var showingTaskSettings = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-startComparison") {
            _selectedTab = State(initialValue: .comparison)
        } else if arguments.contains("-startConditions") {
            _selectedTab = State(initialValue: .conditions)
        } else {
            _selectedTab = State(initialValue: .listings)
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ListingsView(showingTaskSettings: $showingTaskSettings)
                }
                .tabItem { Label("房源", systemImage: "house") }
                .tag(AppTab.listings)

                NavigationStack {
                    ComparisonView()
                }
                .tabItem { Label("对比", systemImage: "slider.horizontal.3") }
                .badge(store.task.comparisonIDs.count)
                .tag(AppTab.comparison)

                NavigationStack {
                    ConditionsView()
                }
                .tabItem { Label("条件", systemImage: "checkmark.circle") }
                .tag(AppTab.conditions)
            }
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
            Color(.systemBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
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

    var body: some View {
        NavigationStack {
            Form {
                Section("选房任务") {
                    TextField("任务名称", text: $title)
                    TextField("城市", text: $city)
                    TextField("主要通勤目的地", text: $destination)
                    Stepper("预计居住 \(expectedMonths) 个月", value: $expectedMonths, in: 1...60)
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
                        store.updateTask {
                            $0.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            $0.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
                            $0.commuteDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                            $0.expectedMonths = expectedMonths
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                title = store.task.title
                city = store.task.city
                destination = store.task.commuteDestination
                expectedMonths = store.task.expectedMonths
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppStore(persistence: .init(load: { nil }, save: { _ in }), useFixtures: true))
}
