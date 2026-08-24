import PhotosUI
import SwiftUI

struct InspectionView: View {
    @Environment(AppStore.self) private var store
    let listingID: UUID

    private var listing: Listing? { store.task.listings.first { $0.id == listingID } }

    var body: some View {
        List {
            if let listing {
                ForEach(listing.inspections.filter { !$0.hidden }) { item in
                    InspectionItemSection(listingID: listingID, itemID: item.id)
                }
            }
        }
        .navigationTitle("看房检查")
        .navigationBarTitleDisplayMode(.inline)
    }

}

private struct InspectionItemSection: View {
    @Environment(AppStore.self) private var store
    let listingID: UUID
    let itemID: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoError: String?

    private var item: InspectionItem? {
        store.task.listings.first { $0.id == listingID }?.inspections.first { $0.id == itemID }
    }

    var body: some View {
        Section {
            Picker("检查结果", selection: stateBinding) {
                ForEach(InspectionState.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if item?.state == .issue {
                PersistentFormField("问题记录（可选）") {
                    TextField("例如：卧室临街，关窗后仍有噪音", text: noteBinding, axis: .vertical)
                        .lineLimit(2...5)
                }
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: max(3 - (item?.photoIDs.count ?? 0), 1), matching: .images) {
                    Label("添加现场照片（最多 3 张）", systemImage: "camera")
                }
                .disabled((item?.photoIDs.count ?? 0) >= 3)
                if let count = item?.photoIDs.count, count > 0 {
                    LabeledContent("已保存现场照片", value: "\(count) 张")
                    Button("移除现场照片", role: .destructive) {
                        updateItem {
                            PersistenceClient.deleteMedia($0.photoIDs)
                            $0.photoIDs.removeAll()
                        }
                    }
                }
            }
        } header: {
            Text(item?.name ?? "检查项")
        }
        .onChange(of: selectedPhotos) { _, items in
            Task { await importPhotos(items) }
        }
        .alert("无法读取照片", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) { Button("好", role: .cancel) {} } message: { Text(photoError ?? "") }
    }

    private var stateBinding: Binding<InspectionState> {
        Binding(
            get: { item?.state ?? .unchecked },
            set: { state in
                updateItem {
                    $0.state = state
                    if state != .issue {
                        $0.note = ""
                        PersistenceClient.deleteMedia($0.photoIDs)
                        $0.photoIDs.removeAll()
                    }
                }
            }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { item?.note ?? "" },
            set: { note in updateItem { $0.note = note } }
        )
    }

    private func updateItem(_ change: (inout InspectionItem) -> Void) {
        store.updateTask { task in
            guard let listingIndex = task.listings.firstIndex(where: { $0.id == listingID }),
                  let itemIndex = task.listings[listingIndex].inspections.firstIndex(where: { $0.id == itemID }) else { return }
            change(&task.listings[listingIndex].inspections[itemIndex])
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        do {
            var ids: [String] = []
            for photo in items.prefix(max(3 - (item?.photoIDs.count ?? 0), 0)) {
                guard let data = try await photo.loadTransferable(type: Data.self) else { continue }
                ids.append(try PersistenceClient.saveMedia(data))
            }
            updateItem { $0.photoIDs.append(contentsOf: ids) }
            selectedPhotos.removeAll()
        } catch {
            photoError = error.localizedDescription
        }
    }
}

#Preview("检查") {
    NavigationStack { InspectionView(listingID: Fixtures.xuhuiID) }
        .environment(AppStore(persistence: .init(loadV2: { nil }, loadV1: { nil }, saveV2: { _ in }), useFixtures: true))
}
