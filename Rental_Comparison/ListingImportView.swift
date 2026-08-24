import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision

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
        var temporaryMediaIDs: [String] = []
        do {
            var allText: [String] = []
            var sourceScreenshotIDs: [String] = []
            var coverPhotoID: String?
            var coverSourceScreenshotID: String?
            var coverSelection: ListingCoverCropSelection?
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let sourceScreenshotID = try PersistenceClient.saveMedia(data)
                sourceScreenshotIDs.append(sourceScreenshotID)
                temporaryMediaIDs.append(sourceScreenshotID)
                let recognition = try await VisionListingRecognizer.recognize(data: data)
                allText.append(recognition.text)
                if coverPhotoID == nil,
                   let image = UIImage(data: data),
                   let generated = ListingCoverCropper.makeAutomaticCover(from: image, lines: recognition.lines) {
                    let generatedCoverID = try PersistenceClient.saveMedia(generated.data)
                    coverPhotoID = generatedCoverID
                    coverSourceScreenshotID = sourceScreenshotID
                    temporaryMediaIDs.append(generatedCoverID)
                    coverSelection = generated.selection
                }
            }
            guard !allText.isEmpty else { throw ListingImportError.emptyResponse }
            var result = ListingImportParser.parse(text: allText.joined(separator: "\n"))
            result.photoIDs = coverPhotoID.map { [$0] } ?? []
            result.sourceScreenshotIDs = sourceScreenshotIDs
            result.coverSourceScreenshotID = coverSourceScreenshotID
            result.coverCropSelection = coverSelection
            result.automaticCoverCropSelection = coverSelection
            result.extractionNote = coverPhotoID == nil
                ? "识别结果来自本地 OCR，仅作为待确认建议；封面生成失败，请保留原图后手动补充照片。"
                : "识别结果来自本地 OCR，仅作为待确认建议；系统已自动裁切封面，可继续调整。"
            draft = result
        } catch {
            PersistenceClient.deleteMedia(temporaryMediaIDs)
            errorMessage = error.localizedDescription
        }
    }
}

struct ListingImportReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ListingImportDraft
    @State private var saving = false
    @State private var coverEditRequest: ListingCoverEditRequest?

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
                if let coverID = draft.photoIDs.first {
                    Section("房源封面") {
                        ListingCoverPreview(mediaID: coverID)
                            .accessibilityIdentifier("importedListingCoverPreview")
                        if let sourceID = draft.coverSourceScreenshotID ?? draft.sourceScreenshotIDs.first {
                            Button("调整封面", systemImage: "crop") {
                                let current = draft.coverCropSelection ?? .default
                                coverEditRequest = .init(
                                    sourceScreenshotID: sourceID,
                                    selection: current,
                                    automaticSelection: draft.automaticCoverCropSelection ?? current
                                )
                            }
                            .accessibilityIdentifier("editImportedListingCoverButton")
                        }
                    }
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
                    if draft.sourceScreenshotIDs.isEmpty {
                        LabeledContent("保留图片", value: "\(draft.photoIDs.count) 张")
                    } else {
                        LabeledContent("原始截图", value: "\(draft.sourceScreenshotIDs.count) 张")
                        LabeledContent("卡片封面", value: draft.photoIDs.isEmpty ? "未生成" : "已生成")
                    }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        discardDraftMedia()
                        dismiss()
                    }
                }
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
            .sheet(item: $coverEditRequest) { request in
                ListingCoverEditorView(request: request) { mediaID, selection in
                    replaceCover(with: mediaID, selection: selection)
                }
            }
        }
    }

    private func replaceCover(with mediaID: String, selection: ListingCoverCropSelection) {
        let oldCoverID = draft.photoIDs.first
        if draft.photoIDs.isEmpty {
            draft.photoIDs = [mediaID]
        } else {
            draft.photoIDs[0] = mediaID
        }
        draft.coverCropSelection = selection
        if let oldCoverID,
           oldCoverID != mediaID,
           !draft.sourceScreenshotIDs.contains(oldCoverID) {
            PersistenceClient.deleteMedia([oldCoverID])
        }
    }

    private func discardDraftMedia() {
        PersistenceClient.deleteMedia(Array(Set(draft.photoIDs + draft.sourceScreenshotIDs)))
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

struct RecognizedListingLine: Hashable, Sendable {
    let text: String
    let boundingBox: CGRect
}

struct ListingRecognitionResult: Hashable, Sendable {
    let lines: [RecognizedListingLine]

    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

struct ListingCoverCropSelection: Hashable, Sendable {
    var horizontalPosition: Double
    var verticalPosition: Double
    var zoom: Double

    static let `default` = Self(horizontalPosition: 0.5, verticalPosition: 0.22, zoom: 1)

    var clamped: Self {
        .init(
            horizontalPosition: horizontalPosition.clamped(to: 0...1),
            verticalPosition: verticalPosition.clamped(to: 0...1),
            zoom: zoom.clamped(to: 1...2.5)
        )
    }
}

enum VisionListingRecognizer {
    static func recognize(data: Data) async throws -> ListingRecognitionResult {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ListingImportError.emptyResponse }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation -> RecognizedListingLine? in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    return .init(text: text, boundingBox: observation.boundingBox)
                }
                if lines.isEmpty {
                    continuation.resume(throwing: ListingImportError.emptyResponse)
                } else {
                    continuation.resume(returning: ListingRecognitionResult(lines: lines))
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true
            request.customWords = ["整租", "合租", "月租", "使用面积", "户型", "楼层", "元/月", "室", "厅", "卫"]
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

enum ListingCoverCropper {
    static let targetAspectRatio: CGFloat = 16.0 / 9.0

    static func makeAutomaticCover(
        from image: UIImage,
        lines: [RecognizedListingLine]
    ) -> (data: Data, selection: ListingCoverCropSelection)? {
        let selection = automaticSelection(imageSize: image.size, lines: lines)
        guard let data = jpegData(from: image, selection: selection) else { return nil }
        return (data, selection)
    }

    static func automaticSelection(
        imageSize: CGSize,
        lines: [RecognizedListingLine]
    ) -> ListingCoverCropSelection {
        let cropSize = normalizedCropSize(imageSize: imageSize, zoom: 1)
        let cropHeight = Double(cropSize.height)
        guard cropHeight > 0, cropHeight <= 1 else { return .default }

        let navigationBottom = lines
            .filter { line in
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return ["VR", "视频", "图片", "评价"].contains { text.localizedCaseInsensitiveContains($0) }
            }
            .map { Double(1 - $0.boundingBox.minY) }
            .filter { $0 < 0.45 }
            .max()

        let regionTop = (navigationBottom.map { $0 + 0.01 } ?? 0.08).clamped(to: 0...1)
        let preferredLowerMarkers = ["必看好房", "严选好房"]
        let fallbackLowerMarkers = ["整租", "合租", "元/月", "/月"]
        let regionBottom = firstLowerBoundary(
            in: lines,
            terms: preferredLowerMarkers,
            below: regionTop
        ) ?? firstLowerBoundary(
            in: lines,
            terms: fallbackLowerMarkers,
            below: regionTop
        ) ?? 0.56

        let maximumOrigin = 1 - cropHeight
        let centeredOrigin: Double
        if regionBottom - regionTop >= cropHeight {
            centeredOrigin = regionTop + (regionBottom - regionTop - cropHeight) / 2
        } else {
            centeredOrigin = regionTop
        }
        let origin = centeredOrigin.clamped(to: 0...maximumOrigin)
        let verticalPosition = maximumOrigin > 0 ? origin / maximumOrigin : 0.5
        return .init(horizontalPosition: 0.5, verticalPosition: verticalPosition, zoom: 1)
    }

    static func jpegData(from image: UIImage, selection: ListingCoverCropSelection) -> Data? {
        guard let cropped = croppedImage(from: image, selection: selection) else { return nil }
        return cropped.jpegData(compressionQuality: 0.92)
    }

    static func croppedImage(from image: UIImage, selection: ListingCoverCropSelection) -> UIImage? {
        let normalizedImage = normalized(image)
        guard let cgImage = normalizedImage.cgImage else { return nil }
        let cropRect = normalizedCropRect(imageSize: normalizedImage.size, selection: selection)
        let proposedPixelRect = CGRect(
            x: cropRect.minX * CGFloat(cgImage.width),
            y: cropRect.minY * CGFloat(cgImage.height),
            width: cropRect.width * CGFloat(cgImage.width),
            height: cropRect.height * CGFloat(cgImage.height)
        )
        let pixelWidth = proposedPixelRect.width.rounded(.down)
        let pixelHeight = proposedPixelRect.height.rounded(.down)
        let pixelRect = CGRect(
            x: proposedPixelRect.minX.rounded().clamped(to: 0...CGFloat(cgImage.width) - pixelWidth),
            y: proposedPixelRect.minY.rounded().clamped(to: 0...CGFloat(cgImage.height) - pixelHeight),
            width: pixelWidth,
            height: pixelHeight
        )
        guard pixelRect.width > 0,
              pixelRect.height > 0,
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped)
    }

    static func normalizedCropRect(
        imageSize: CGSize,
        selection: ListingCoverCropSelection
    ) -> CGRect {
        let selection = selection.clamped
        let cropSize = normalizedCropSize(imageSize: imageSize, zoom: selection.zoom)
        return CGRect(
            x: (1 - cropSize.width) * CGFloat(selection.horizontalPosition),
            y: (1 - cropSize.height) * CGFloat(selection.verticalPosition),
            width: cropSize.width,
            height: cropSize.height
        )
    }

    private static func normalizedCropSize(imageSize: CGSize, zoom: Double) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let imageAspectRatio = imageSize.width / imageSize.height
        let baseSize: CGSize
        if imageAspectRatio >= targetAspectRatio {
            baseSize = .init(width: targetAspectRatio / imageAspectRatio, height: 1)
        } else {
            baseSize = .init(width: 1, height: imageAspectRatio / targetAspectRatio)
        }
        return .init(width: baseSize.width / CGFloat(zoom), height: baseSize.height / CGFloat(zoom))
    }

    private static func firstLowerBoundary(
        in lines: [RecognizedListingLine],
        terms: [String],
        below regionTop: Double
    ) -> Double? {
        lines
            .filter { line in terms.contains { line.text.localizedCaseInsensitiveContains($0) } }
            .map { Double(1 - $0.boundingBox.maxY) }
            .filter { $0 > regionTop }
            .min()
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

private struct ListingCoverPreview: View {
    let mediaID: String

    var body: some View {
        Group {
            if let url = PersistenceClient.mediaURL(for: mediaID),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ContentUnavailableView("无法载入封面", systemImage: "photo.badge.exclamationmark")
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(ListingCoverCropper.targetAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("房源卡片封面预览")
    }
}

private struct ListingCoverEditRequest: Identifiable, Hashable {
    let id = UUID()
    let sourceScreenshotID: String
    let selection: ListingCoverCropSelection
    let automaticSelection: ListingCoverCropSelection
}

private struct ListingCoverEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let request: ListingCoverEditRequest
    let onSave: (String, ListingCoverCropSelection) -> Void
    @State private var selection: ListingCoverCropSelection
    @State private var errorMessage: String?

    init(
        request: ListingCoverEditRequest,
        onSave: @escaping (String, ListingCoverCropSelection) -> Void
    ) {
        self.request = request
        self.onSave = onSave
        _selection = State(initialValue: request.selection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("封面预览") {
                    if let image = sourceImage,
                       let cropped = ListingCoverCropper.croppedImage(from: image, selection: selection) {
                        Image(uiImage: cropped)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(ListingCoverCropper.targetAspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("调整后的房源封面")
                    } else {
                        ContentUnavailableView("无法载入原始截图", systemImage: "photo.badge.exclamationmark")
                    }
                }
                Section("裁切范围") {
                    slider("上下位置", value: $selection.verticalPosition, range: 0...1)
                    slider("左右位置", value: $selection.horizontalPosition, range: 0...1)
                    slider("缩放", value: $selection.zoom, range: 1...2.5)
                    Button("恢复自动裁切", systemImage: "wand.and.stars") {
                        selection = request.automaticSelection
                    }
                }
                Section {
                    Text("原始截图会继续作为房源证据保留，调整只会重新生成卡片封面。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("调整封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCover() }
                        .disabled(sourceImage == nil)
                        .accessibilityIdentifier("saveImportedListingCoverButton")
                }
            }
            .alert("无法保存封面", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var sourceImage: UIImage? {
        guard let url = PersistenceClient.mediaURL(for: request.sourceScreenshotID) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }

    private func saveCover() {
        guard let image = sourceImage,
              let data = ListingCoverCropper.jpegData(from: image, selection: selection) else {
            errorMessage = "无法从这张截图生成封面。"
            return
        }
        do {
            let mediaID = try PersistenceClient.saveMedia(data)
            onSave(mediaID, selection.clamped)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
