import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section("常用偏好") {
                Picker("语言", selection: preferenceBinding(\.language)) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .accessibilityIdentifier("languagePicker")

                Picker("货币单位", selection: preferenceBinding(\.defaultCurrency)) {
                    Text("人民币（CNY）").tag("CNY")
                    Text("港币（HKD）").tag("HKD")
                    Text("美元（USD）").tag("USD")
                }
                .accessibilityIdentifier("currencyPicker")
                Stepper("默认居住 \(store.preferences.defaultExpectedStayMonths) 个月", value: preferenceBinding(\.defaultExpectedStayMonths), in: 1...60)
                Toggle("显示已淘汰房源", isOn: preferenceBinding(\.showEliminatedOptions))
            }
            Section("当前任务") {
                Text(store.task.title).font(.headline)
                Text("\(store.task.city.isEmpty ? "城市待补充" : store.task.city) · \(store.tasks.count) 个任务")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .accessibilityIdentifier("settingsScreen")
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<DecisionPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0[keyPath: keyPath] = value } }
        )
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
