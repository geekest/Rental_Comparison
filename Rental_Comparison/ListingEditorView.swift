import PhotosUI
import SwiftUI
import UIKit

struct ListingEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Listing
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoError: String?

    private let isNew: Bool

    init(existing: Listing? = nil) {
        isNew = existing == nil
        _draft = State(initialValue: existing ?? Listing(
            name: "",
            city: "",
            rentalType: .entire,
            rent: 0,
            costs: [],
            inspections: InspectionItem.defaults
        ))
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var areaUnit: String {
        RegionalTemplateCatalog.template(id: store.state.hunt.regionTemplateID).areaUnit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("主要信息") {
                    TextField("房源名称", text: $draft.name)
                        .accessibilityIdentifier("listingNameField")
                    TextField("城市", text: $draft.city)
                    Picker("租赁方式", selection: $draft.rentalType) {
                        ForEach(RentalType.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("月租", value: $draft.rent, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("listingRentField")
                    TextField("货币", text: $draft.currency)
                        .textInputAutocapitalization(.characters)
                    Stepper("居室数：\(draft.roomCount ?? 1)", value: optionalIntBinding(\Listing.roomCount, fallback: 1), in: 1...20)
                }

                Section("房源照片") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                        Label(draft.photoIDs.isEmpty ? "选择照片" : "已选择 \(draft.photoIDs.count) 张", systemImage: "photo.on.rectangle.angled")
                    }
                    if !draft.photoIDs.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(draft.photoIDs, id: \.self) { id in
                                    if let url = PersistenceClient.mediaURL(for: id),
                                       let image = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 96, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                        Button("移除所选照片", role: .destructive) {
                            PersistenceClient.deleteMedia(draft.photoIDs)
                            draft.photoIDs.removeAll()
                        }
                    }
                }

                Section("位置与空间") {
                    TextField("地址", text: optionalStringBinding(\Listing.address))
                    TextField("面积（\(areaUnit)）", value: $draft.area, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("面积范围", selection: optionalStringBinding(\Listing.areaScope, fallback: "整套")) {
                        Text("整套").tag("整套")
                        Text("私人空间").tag("私人空间")
                    }
                    TextField("户型", text: optionalStringBinding(\Listing.layout))
                    TextField("楼层", text: optionalStringBinding(\Listing.floor))
                    Picker("电梯", selection: optionalBoolBinding(\Listing.hasElevator)) {
                        Text("待补充").tag(Bool?.none)
                        Text("有").tag(Bool?.some(true))
                        Text("无").tag(Bool?.some(false))
                    }
                }

                Section("通勤") {
                    Picker("方式", selection: $draft.commuteMode) {
                        Text("待补充").tag(CommuteMode?.none)
                        ForEach(CommuteMode.allCases) { Text($0.title).tag(CommuteMode?.some($0)) }
                    }
                    TextField("单程分钟", value: $draft.commuteMinutes, format: .number)
                        .keyboardType(.numberPad)
                    TextField("单次支出", value: $draft.commuteFare, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section("费用明细") {
                    ForEach($draft.costs) { $item in
                        DisclosureGroup {
                            TextField("名称", text: $item.name)
                            TextField("金额", value: $item.amount, format: .number)
                                .keyboardType(.decimalPad)
                            Picker("周期", selection: $item.cadence) {
                                ForEach(CostCadence.allCases) { Text($0.title).tag($0) }
                            }
                            Toggle("可退", isOn: $item.refundable)
                            Toggle("信息已确认", isOn: $item.confirmed)
                            Button("删除费用", role: .destructive) {
                                draft.costs.removeAll { $0.id == item.id }
                            }
                        } label: {
                            LabeledContent(item.name.isEmpty ? "未命名费用" : item.name, value: item.amount?.formattedMoney(currency: draft.currency) ?? "待补充")
                        }
                    }
                    Button("添加费用", systemImage: "plus") {
                        draft.costs.append(.init(name: "", cadence: .monthly, refundable: false, confirmed: false))
                    }
                }
            }
            .navigationTitle(isNew ? "添加租赁方案" : "完整信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.city = draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.currency = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveListingButton")
                }
            }
            .onAppear {
                if isNew && draft.city.isEmpty { draft.city = store.task.city }
                if isNew { draft.currency = store.task.currency }
            }
            .onChange(of: selectedPhotos) { _, items in
                Task { await importPhotos(items) }
            }
            .alert("无法读取照片", isPresented: Binding(
                get: { photoError != nil },
                set: { if !$0 { photoError = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(photoError ?? "") }
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        do {
            var ids: [String] = []
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                ids.append(try PersistenceClient.saveMedia(data))
            }
            draft.photoIDs.append(contentsOf: ids)
            selectedPhotos.removeAll()
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<Listing, String?>, fallback: String = "") -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] ?? fallback }, set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    private func optionalIntBinding(_ keyPath: WritableKeyPath<Listing, Int?>, fallback: Int) -> Binding<Int> {
        Binding(get: { draft[keyPath: keyPath] ?? fallback }, set: { draft[keyPath: keyPath] = $0 })
    }

    private func optionalBoolBinding(_ keyPath: WritableKeyPath<Listing, Bool?>) -> Binding<Bool?> {
        Binding(get: { draft[keyPath: keyPath] }, set: { draft[keyPath: keyPath] = $0 })
    }
}
