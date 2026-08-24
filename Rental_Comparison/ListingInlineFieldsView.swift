import PhotosUI
import SwiftUI
import UIKit

struct ListingInlineFieldsView: View {
    @Binding var listing: Listing
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoError: String?

    var body: some View {
        Group {
            Section("基本信息") {
                PersistentFormField("房源名称") {
                    TextField("例如：龙湖时代天街 01 卧", text: $listing.name)
                }
                PersistentFormField("城市") {
                    TextField("例如：上海", text: $listing.city)
                }
                Picker("租赁方式", selection: $listing.rentalType) {
                    ForEach(RentalType.allCases) { Text($0.title).tag($0) }
                }
                PersistentFormField("月租") {
                    TextField("例如：3330", value: $listing.rent, format: .number).keyboardType(.decimalPad)
                }
                PersistentFormField("货币") {
                    TextField("例如：CNY", text: $listing.currency).textInputAutocapitalization(.characters)
                }
                PersistentFormField("居室数") {
                    TextField("例如：3", value: optionalIntBinding(\.roomCount, fallback: 1), format: .number).keyboardType(.numberPad)
                }
            }

            Section("照片") {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                    Label(listing.photoIDs.isEmpty ? "添加照片" : "已添加 \(listing.photoIDs.count) 张", systemImage: "photo.on.rectangle.angled")
                }
                if !listing.photoIDs.isEmpty {
                    Button("移除照片", role: .destructive) {
                        PersistenceClient.deleteMedia(listing.photoIDs)
                        listing.photoIDs.removeAll()
                    }
                }
            }

            Section("位置与空间") {
                PersistentFormField("地址") {
                    TextField("例如：徐汇区龙华路 1 号", text: optionalStringBinding(\.address))
                }
                PersistentFormField("面积") {
                    TextField("例如：37.13", value: $listing.area, format: .number).keyboardType(.decimalPad)
                }
                Picker("面积范围", selection: optionalStringBinding(\.areaScope, fallback: "整套")) {
                    Text("整套").tag("整套")
                    Text("私人空间").tag("私人空间")
                }
                PersistentFormField("户型") {
                    TextField("例如：3 室 2 厅", text: optionalStringBinding(\.layout))
                }
                PersistentFormField("楼层") {
                    TextField("例如：20/26", text: optionalStringBinding(\.floor))
                }
                Picker("电梯", selection: $listing.hasElevator) {
                    Text("待补充").tag(Bool?.none)
                    Text("有").tag(Bool?.some(true))
                    Text("无").tag(Bool?.some(false))
                }
                PersistentFormField("租期（月）") {
                    TextField("例如：12", value: $listing.leaseMonths, format: .number).keyboardType(.numberPad)
                }
            }

            Section("通勤") {
                Picker("方式", selection: $listing.commuteMode) {
                    Text("待补充").tag(CommuteMode?.none)
                    ForEach(CommuteMode.allCases) { Text($0.title).tag(CommuteMode?.some($0)) }
                }
                PersistentFormField("单程时间（分钟）") {
                    TextField("例如：30", value: $listing.commuteMinutes, format: .number).keyboardType(.numberPad)
                }
                PersistentFormField("单次支出") {
                    TextField("例如：5", value: $listing.commuteFare, format: .number).keyboardType(.decimalPad)
                }
            }

            Section("费用明细") {
                ForEach($listing.costs) { $item in
                    DisclosureGroup(item.name.isEmpty ? "未命名费用" : item.name) {
                        PersistentFormField("费用名称") {
                            TextField("例如：物业费", text: $item.name)
                        }
                        PersistentFormField("金额") {
                            TextField("例如：300", value: $item.amount, format: .number).keyboardType(.decimalPad)
                        }
                        Picker("周期", selection: $item.cadence) { ForEach(CostCadence.allCases) { Text($0.title).tag($0) } }
                        Toggle("可退", isOn: $item.refundable)
                        Toggle("信息已确认", isOn: $item.confirmed)
                        Button("删除费用", role: .destructive) { listing.costs.removeAll { $0.id == item.id } }
                    }
                }
                Button("添加费用", systemImage: "plus") {
                    listing.costs.append(.init(name: "", cadence: .monthly, refundable: false, confirmed: false))
                }
            }
        }
        .onChange(of: selectedPhotos) { _, items in Task { await importPhotos(items) } }
        .alert("无法读取照片", isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(photoError ?? "") }
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<Listing, String?>, fallback: String = "") -> Binding<String> {
        Binding(get: { listing[keyPath: keyPath] ?? fallback }, set: { listing[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    private func optionalIntBinding(_ keyPath: WritableKeyPath<Listing, Int?>, fallback: Int) -> Binding<Int> {
        Binding(get: { listing[keyPath: keyPath] ?? fallback }, set: { listing[keyPath: keyPath] = $0 })
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                listing.photoIDs.append(try PersistenceClient.saveMedia(data))
            }
            selectedPhotos.removeAll()
        } catch {
            photoError = error.localizedDescription
        }
    }
}

#Preview {
    Form { ListingInlineFieldsView(listing: .constant(Fixtures.initialState.task.listings[0])) }
}
