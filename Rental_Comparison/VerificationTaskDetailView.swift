import PhotosUI
import SwiftUI

struct VerificationTaskDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID
    @State private var taskState: VerificationTaskState = .pending
    @State private var result = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoIDs: [String] = []
    @State private var photoError: String?

    private var task: VerificationTask? {
        store.state.verificationTasks.first { $0.id == taskID }
    }

    var body: some View {
        Group {
            if let task {
                Form {
                    Section("需要确认") {
                        Text(task.title).font(.headline)
                        Text(task.instruction).foregroundStyle(.secondary)
                    }
                    Section("本次记录") {
                        Picker("结果", selection: $taskState) {
                            Text("待确认").tag(VerificationTaskState.pending)
                            Text("已验证").tag(VerificationTaskState.verified)
                            Text("发现风险").tag(VerificationTaskState.issue)
                            Text("暂不处理").tag(VerificationTaskState.skipped)
                        }
                        PersistentFormField("观察结果（可选）") {
                            TextField("例如：夜间关窗后仍能听见车流声", text: $result, axis: .vertical)
                                .lineLimit(2...5)
                        }
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 3, matching: .images) {
                            Label(photoIDs.isEmpty ? "添加现场证据" : "已添加 \(photoIDs.count) 张", systemImage: "camera")
                        }
                    }
                }
                .navigationTitle("验证任务")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            store.completeVerificationTask(task.id, state: taskState, result: result, photoIDs: photoIDs)
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    taskState = task.state
                    result = task.result ?? ""
                }
                .onChange(of: selectedPhotos) { _, items in
                    Task { await importPhotos(items) }
                }
                .alert("无法读取照片", isPresented: Binding(
                    get: { photoError != nil },
                    set: { if !$0 { photoError = nil } }
                )) { Button("好", role: .cancel) {} } message: { Text(photoError ?? "") }
            } else {
                ContentUnavailableView("任务不存在", systemImage: "checklist.unchecked")
            }
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                photoIDs.append(try PersistenceClient.saveMedia(data))
            }
            selectedPhotos.removeAll()
        } catch {
            photoError = error.localizedDescription
        }
    }
}

#Preview("验证任务") {
    NavigationStack { VerificationTaskDetailView(taskID: Fixtures.xuhuiID) }
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
