import SwiftUI

struct ConditionsView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAdd = false
    @State private var newConditionName = ""

    var body: some View {
        List {
            Section {
                Text("先标记哪些条件不能妥协，再逐套记录符合、不符合或未知。系统不会生成综合分数。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.task.conditions) { condition in
                Section {
                    Picker("重要程度", selection: importanceBinding(condition.id)) {
                        ForEach(Importance.allCases) { Text($0.title).tag($0) }
                    }
                    ForEach(store.task.listings.filter { $0.status == .candidate }) { listing in
                        HStack {
                            Text(listing.name)
                            Spacer()
                            Picker("\(listing.name)的结果", selection: resultBinding(listingID: listing.id, conditionID: condition.id)) {
                                ForEach(ConditionResult.allCases) { result in
                                    Label(result.title, systemImage: result.symbol).tag(result)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                } header: {
                    HStack {
                        Text(condition.name)
                        if condition.importance == .required {
                            Text("硬性").foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("选房重点")
        .toolbar { Button("添加重点", systemImage: "plus") { showingAdd = true } }
        .alert("添加自定义条件", isPresented: $showingAdd) {
            TextField("例如：必须有电梯", text: $newConditionName)
            Button("取消", role: .cancel) { newConditionName = "" }
            Button("添加") {
                let name = newConditionName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.updateTask { $0.conditions.append(.init(id: UUID().uuidString, name: name, importance: .preferred, custom: true)) }
                newConditionName = ""
            }
        }
        .accessibilityIdentifier("conditionsScreen")
    }

    private func importanceBinding(_ conditionID: String) -> Binding<Importance> {
        Binding(
            get: { store.task.conditions.first { $0.id == conditionID }?.importance ?? .preferred },
            set: { importance in
                store.updateTask { task in
                    guard let index = task.conditions.firstIndex(where: { $0.id == conditionID }) else { return }
                    task.conditions[index].importance = importance
                }
            }
        )
    }

    private func resultBinding(listingID: UUID, conditionID: String) -> Binding<ConditionResult> {
        Binding(
            get: { store.task.listings.first { $0.id == listingID }?.conditionResults[conditionID] ?? .unknown },
            set: { result in
                store.updateTask { task in
                    guard let index = task.listings.firstIndex(where: { $0.id == listingID }) else { return }
                    task.listings[index].conditionResults[conditionID] = result
                }
            }
        )
    }
}

#Preview("条件") {
    NavigationStack { ConditionsView() }
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
