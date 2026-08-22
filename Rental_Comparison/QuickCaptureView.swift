import PhotosUI
import SwiftUI

struct QuickCaptureView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rentText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoIDs: [String] = []
    @State private var mediaEvidenceType: EvidenceType = .screenshot
    @State private var isImportingPhotos = false
    @State private var photoError: String?

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var monthlyRent: Double? {
        let value = rentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("先记下候选；通勤、费用和看房信息可以在之后按需补充。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("候选信息") {
                    TextField("名称", text: $name)
                        .accessibilityIdentifier("listingNameField")
                    TextField("月租（可选）", text: $rentText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("listingRentField")
                    LabeledContent("货币", value: store.state.hunt.defaultCurrency)
                }

                Section("截图或照片（可选）") {
                    Picker("素材类型", selection: $mediaEvidenceType) {
                        Text("截图").tag(EvidenceType.screenshot)
                        Text("照片").tag(EvidenceType.photo)
                    }
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                        Label(photoIDs.isEmpty ? "添加截图或照片" : "已添加 \(photoIDs.count) 张", systemImage: "photo.on.rectangle.angled")
                    }
                    if isImportingPhotos {
                        ProgressView("正在导入照片")
                    }
                }
            }
            .navigationTitle("快速添加候选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        _ = store.captureOption(name: normalizedName, monthlyRent: monthlyRent, photoIDs: photoIDs, mediaEvidenceType: mediaEvidenceType)
                        dismiss()
                    }
                    .disabled(normalizedName.isEmpty || isImportingPhotos)
                    .accessibilityIdentifier("saveListingButton")
                }
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
        isImportingPhotos = true
        defer {
            isImportingPhotos = false
            selectedPhotos.removeAll()
        }
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                photoIDs.append(try PersistenceClient.saveMedia(data))
            }
        } catch {
            photoError = error.localizedDescription
        }
    }
}
