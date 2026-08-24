import PhotosUI
import SwiftUI
import UIKit

struct ListingImageView: View {
    let listing: Listing

    var body: some View {
        Group {
            if let photoID = listing.photoIDs.first,
               let url = PersistenceClient.mediaURL(for: photoID),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable()
            } else if let image = bundledImage(named: listing.bundledImageName) {
                Image(uiImage: image).resizable()
            } else {
                ContentUnavailableView("暂无照片", systemImage: "photo")
            }
        }
        .scaledToFill()
        .clipped()
        .accessibilityLabel("\(listing.name)的房源照片")
    }

    private func bundledImage(named name: String?) -> UIImage? {
        guard let name,
              let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "listings") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
struct StatusPill: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview("房源图片") {
    ListingImageView(listing: Fixtures.initialState.task.listings[0])
        .frame(height: 220)
        .padding()
}

struct ListingMediaHeaderView: View {
    @Environment(AppStore.self) private var store
    let optionID: UUID
    let listingName: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedEvidenceID: UUID?
    @State private var errorMessage: String?

    private var media: [ListingMedia] {
        store.listingMedia(for: optionID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mediaContent
            addPhotoControl
        }
        .onAppear { selectFirstMediaIfNeeded() }
        .onChange(of: media.map(\.evidenceID)) { _, _ in selectFirstMediaIfNeeded() }
        .onChange(of: selectedPhotos) { _, items in Task { await importPhotos(items) } }
        .alert("无法导入图片", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder private var mediaContent: some View {
        if media.isEmpty {
            ContentUnavailableView(
                "暂无照片",
                systemImage: "photo.on.rectangle",
                description: Text("添加房源照片或保留的原始截图会显示在这里。")
            )
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .background(.fill.tertiary)
        } else {
            TabView(selection: $selectedEvidenceID) {
                ForEach(media) { item in
                    ListingMediaImage(mediaID: item.mediaID, label: "\(listingName)的\(item.isScreenshot ? "原始截图" : "房源照片")")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(Optional(item.evidenceID))
                        .overlay(alignment: .bottomLeading) {
                            if item.isScreenshot { screenshotBadge }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .frame(height: 260)
            .background(.fill.tertiary)
        }
    }

    private var screenshotBadge: some View {
        Text("原始截图")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
            .foregroundStyle(.white)
            .padding(14)
    }

    private var addPhotoControl: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
            Image(systemName: "plus")
                .font(.headline.weight(.bold))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("添加房源图片")
        .accessibilityIdentifier("addListingMediaButton")
        .padding(14)
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos.removeAll() }
        do {
            let dataItems = try await items.asyncCompactMap { try await $0.loadTransferable(type: Data.self) }
            try store.addListingMedia(dataItems, to: optionID)
            selectedEvidenceID = store.listingMedia(for: optionID).first?.evidenceID
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectFirstMediaIfNeeded() {
        guard let first = media.first else {
            selectedEvidenceID = nil
            return
        }
        if !media.contains(where: { $0.evidenceID == selectedEvidenceID }) {
            selectedEvidenceID = first.evidenceID
        }
    }
}

struct ListingMediaManagerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let optionID: UUID
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var pendingRemoval: ListingMedia?
    @State private var errorMessage: String?

    private var media: [ListingMedia] {
        store.listingMedia(for: optionID)
    }

    private var primaryEvidenceID: UUID? {
        store.state.options.first(where: { $0.id == optionID })?.primaryEvidenceID
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                mediaGrid
            }
            .navigationTitle("管理图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: selectedPhotos) { _, items in Task { await importPhotos(items) } }
            .alert("移除这张图片？", isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ), presenting: pendingRemoval) { item in
                Button("移除", role: .destructive) {
                    store.removeListingMedia(item.evidenceID, from: optionID)
                    pendingRemoval = nil
                }
                Button("取消", role: .cancel) { pendingRemoval = nil }
            } message: { item in
                Text(item.isScreenshot ? "移除后将不再保留这张原始截图。" : "移除后，这张房源照片将无法恢复。")
            }
            .alert("无法导入图片", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var mediaGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(media) { item in
                ListingMediaGridCell(
                    item: item,
                    isPrimary: item.evidenceID == primaryEvidenceID,
                    onMakePrimary: { store.setPrimaryListingMedia(item.evidenceID, for: optionID) },
                    onRemove: { pendingRemoval = item }
                )
            }
            addPhotoControl
        }
        .padding()
    }

    private var addPhotoControl: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 8, matching: .images) {
            Label("添加图片", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 104)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
        }
        .accessibilityIdentifier("addListingMediaInManagerButton")
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos.removeAll() }
        do {
            let dataItems = try await items.asyncCompactMap { try await $0.loadTransferable(type: Data.self) }
            try store.addListingMedia(dataItems, to: optionID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ListingMediaGridCell: View {
    let item: ListingMedia
    let isPrimary: Bool
    let onMakePrimary: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ListingMediaImage(mediaID: item.mediaID, label: item.isScreenshot ? "原始截图" : "房源照片")
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if isPrimary {
                Label("主图", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.yellow, in: Capsule())
                    .padding(7)
            }
            Menu {
                Button("设为主图", systemImage: "star") { onMakePrimary() }
                    .disabled(isPrimary)
                Button("移除", systemImage: "trash", role: .destructive) { onRemove() }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .padding(7)
            }
            .accessibilityLabel(item.isScreenshot ? "原始截图操作" : "房源照片操作")
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            if item.isScreenshot {
                Text("原始截图")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.58), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(7)
            }
        }
    }
}

private struct ListingMediaImage: View {
    let mediaID: String
    let label: String

    var body: some View {
        Group {
            if let url = PersistenceClient.mediaURL(for: mediaID),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ContentUnavailableView("无法载入图片", systemImage: "photo.badge.exclamationmark")
            }
        }
        .clipped()
        .accessibilityLabel(label)
    }
}

private extension Array {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async throws -> [T] {
        var values: [T] = []
        for element in self {
            if let value = try await transform(element) {
                values.append(value)
            }
        }
        return values
    }
}
