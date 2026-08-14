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
