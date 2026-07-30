import SwiftUI

/// Stands in for the comp's `<image-slot>` placeholders — the reaction tile, the live camera
/// tile and the paywall app icon, none of which have final art yet.
///
/// Drop a real image name in and it renders that instead.
struct ImageSlot: View {
    let label: String
    var imageName: String?
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Palette.pictureInPicture

                VStack(spacing: Metrics.Space.s) {
                    AvatarSilhouette()
                        .fill(Color(hex: 0xEDF2FF, opacity: 0.26))
                        .frame(width: 46, height: 46)

                    Text(label)
                        .font(Typeface.rounded(10, .regular))
                        .foregroundStyle(Palette.dim)
                        .lineHeight(1.35, size: 10)
                        .multilineTextAlignment(.center)
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(label)
    }
}

/// The head-and-shoulders mark the comp uses in its empty tiles.
struct AvatarSilhouette: VectorGlyph {
    static let viewBox = CGSize(width: 84, height: 84)

    func draw(into path: inout Path) {
        path.addEllipse(in: CGRect(x: 25, y: 13, width: 34, height: 34))
        path.move(to: CGPoint(x: 8, y: 84))
        path.addCurve(to: CGPoint(x: 42, y: 54),
                      control1: CGPoint(x: 8, y: 65), control2: CGPoint(x: 23, y: 54))
        path.addCurve(to: CGPoint(x: 76, y: 84),
                      control1: CGPoint(x: 61, y: 54), control2: CGPoint(x: 76, y: 65))
        path.closeSubpath()
    }
}
