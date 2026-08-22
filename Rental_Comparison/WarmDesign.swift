import SwiftUI

enum WarmDesign {
    static let canvas = Color(red: 0.973, green: 0.961, blue: 0.925)
    static let paper = Color(red: 1.0, green: 0.996, blue: 0.98)
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.105)
    static let secondaryInk = Color(red: 0.40, green: 0.39, blue: 0.35)
    static let moss = Color(red: 0.29, green: 0.49, blue: 0.31)
    static let mossWash = Color(red: 0.90, green: 0.94, blue: 0.87)
    static let apricotWash = Color(red: 1.0, green: 0.93, blue: 0.77)
    static let warning = Color(red: 0.79, green: 0.40, blue: 0.20)
    static let line = Color(red: 0.88, green: 0.85, blue: 0.77)
    static let corner: CGFloat = 24

}

struct WarmSectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(WarmDesign.ink)
            Spacer()
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WarmDesign.secondaryInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WarmDesign.mossWash, in: Capsule())
        }
    }
}

struct WarmToolbarIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(WarmDesign.ink)
            .frame(width: 38, height: 38)
            .background(WarmDesign.paper, in: Circle())
            .overlay(Circle().stroke(WarmDesign.line.opacity(0.75), lineWidth: 1))
    }
}
