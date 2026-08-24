import PhotosUI
import SwiftUI
import UIKit
import Vision

enum AddListingRoute: Hashable, Identifiable {
    case direct
    case link
    case screenshot

    var id: Self { self }
}

struct AddListingFlowView: View {
    let route: AddListingRoute

    var body: some View {
        switch route {
        case .direct:
            QuickCaptureView()
        case .link:
            ListingLinkImportView()
        case .screenshot:
            ListingScreenshotImportView()
        }
    }
}

struct ListingLinkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText: String
    @State private var draft: ListingImportDraft?
    @State private var errorMessage: String?
    @State private var isLoading = false
    private let initialURL: URL?

    init(initialURL: URL? = nil) {
        self.initialURL = initialURL
        _urlText = State(initialValue: initialURL?.absoluteString ?? "")
    }

    var body: some View {
        Group {
            if let draft {
                ListingImportReviewView(draft: draft)
            } else {
                NavigationStack {
                    Form {
                        Section {
                            Text("当前支持链家、贝壳和 Reddit。解析结果会先作为建议展示，确认后才保存为房源信息。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Section("房源链接") {
                            PersistentFormField("链接") {
                                TextField("粘贴房源详情链接", text: $urlText, axis: .vertical)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .accessibilityIdentifier("listingURLField")
                            }
                            if isLoading { ProgressView("正在解析页面") }
                            Button("开始解析", systemImage: "wand.and.stars") { Task { await importURL() } }
                                .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("parseListingURLButton")
                        }
                    }
                    .navigationTitle("链接导入")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                    .alert("无法解析链接", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                        Button("好", role: .cancel) {}
                    } message: { Text(errorMessage ?? "") }
                }
                .task {
                    if initialURL != nil && draft == nil && !isLoading { await importURL() }
                }
            }
        }
    }

    @MainActor
    private func importURL() async {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https" else {
            errorMessage = ListingImportError.invalidURL.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            draft = try await ListingLinkImporter().importURL(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ListingScreenshotImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var draft: ListingImportDraft?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let draft {
                ListingImportReviewView(draft: draft)
            } else {
                NavigationStack {
                    Form {
                        Section {
                            Text("识别在本机完成。能识别的内容会填入待确认字段，原始截图会作为证据保留。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Section("选择截图") {
                            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
                                Label("从相册选择截图", systemImage: "photo.on.rectangle.angled")
                            }
                            .accessibilityIdentifier("chooseListingScreenshotsButton")
                            if isLoading { ProgressView("正在识别截图") }
                        }
                    }
                    .navigationTitle("截图识别")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                    .onChange(of: selectedPhotos) { _, items in Task { await recognize(items) } }
                    .alert("无法识别截图", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                        Button("好", role: .cancel) {}
                    } message: { Text(errorMessage ?? "") }
                }
            }
        }
    }

    @MainActor
    private func recognize(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer {
            isLoading = false
            selectedPhotos.removeAll()
        }
        do {
            var allText: [String] = []
            var photoIDs: [String] = []
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                photoIDs.append(try PersistenceClient.saveMedia(data))
                allText.append(try await VisionListingRecognizer.recognize(data: data))
            }
            guard !allText.isEmpty else { throw ListingImportError.emptyResponse }
            var result = ListingImportParser.parse(text: allText.joined(separator: "\n"))
            result.photoIDs = photoIDs
            result.extractionNote = "识别结果来自本地 OCR，仅作为待确认建议。"
            draft = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ListingImportReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ListingImportDraft
    @State private var saving = false

    init(draft: ListingImportDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(draft.sourceType == .listing ? "页面解析建议，请逐项确认" : "截图识别建议，请逐项确认", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    if !draft.extractionNote.isEmpty { Text(draft.extractionNote).font(.caption).foregroundStyle(.secondary) }
                }
                Section("可确认信息") {
                    PersistentFormField("房源名称") {
                        TextField("例如：龙湖时代天街 01 卧", text: $draft.name)
                            .accessibilityIdentifier("importedListingNameField")
                    }
                    PersistentFormField("城市") {
                        TextField("例如：上海", text: $draft.city)
                    }
                    Picker("租赁方式", selection: $draft.rentalType) {
                        ForEach(RentalType.allCases) { Text($0.title).tag($0) }
                    }
                    PersistentFormField("月租（可选）") {
                        TextField("例如：3330", value: $draft.monthlyRent, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("importedListingRentField")
                    }
                    PersistentFormField("货币") {
                        TextField("例如：CNY", text: $draft.currency)
                            .textInputAutocapitalization(.characters)
                    }
                    PersistentFormField("地址（可选）") {
                        TextField("例如：徐汇区龙华路 1 号", text: optionalStringBinding(\.address))
                    }
                    PersistentFormField("面积（可选）") {
                        TextField("例如：37.13", value: $draft.area, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    PersistentFormField("户型（可选）") {
                        TextField("例如：3 室 2 厅", text: optionalStringBinding(\.layout))
                    }
                }
                Section("导入证据") {
                    if let provider = draft.provider { LabeledContent("来源平台", value: provider.title) }
                    if let sourceURL = draft.sourceURL { Text(sourceURL.absoluteString).font(.caption).textSelection(.enabled) }
                    LabeledContent("保留图片", value: "\(draft.photoIDs.count) 张")
                    if !draft.sourceDescription.isEmpty {
                        Text(draft.sourceDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                    }
                }
            }
            .navigationTitle("确认导入信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认保存") {
                        saving = true
                        store.captureImportedOption(draft: draft)
                        dismiss()
                    }
                    .disabled(saving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("confirmImportedListingButton")
                }
            }
            .onAppear {
                if draft.city.isEmpty { draft.city = store.task.city }
                if draft.currency.isEmpty { draft.currency = store.state.hunt.defaultCurrency }
            }
        }
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<ListingImportDraft, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { value in
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = normalized.isEmpty ? nil : value
            }
        )
    }
}

enum VisionListingRecognizer {
    static func recognize(data: Data) async throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ListingImportError.emptyResponse }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: ListingImportError.emptyResponse)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
