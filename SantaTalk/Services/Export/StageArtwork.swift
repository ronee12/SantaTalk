import CoreImage
import SwiftUI

/// The still layers of a shared video, rendered once from SwiftUI.
///
/// Everything that does not move — Santa, the two name badges, the tile's stroke
/// and shadow, the glass placeholder, the free-tier wordmark — is drawn by
/// `ImageRenderer` from real SwiftUI views and handed to Core Image as flat
/// pictures. Only the child's camera frames are composited per frame.
///
/// Drawing these from SwiftUI rather than by hand in Core Graphics is the whole
/// point: the shared video and `PlayerView` are then the same design, and stay
/// the same design when the design changes.
///
/// `@unchecked Sendable` because `CIImage` carries no such promise, and these
/// four are immutable from the moment they are made. `nonisolated` because the
/// per-frame handler reads them off the main actor.
nonisolated struct StageArtwork: @unchecked Sendable {

    /// The whole frame as it looks when the camera was off: stage, Santa, his
    /// badge, the wordmark, and the tile holding its glass placeholder.
    let backdrop: CIImage

    /// Transparent apart from the tile's stroke and the child's name badge,
    /// which belong *above* whatever fills the tile.
    let chrome: CIImage

    /// Opaque white inside the tile's rounded rect, transparent outside. Used as
    /// an alpha mask so the camera's square frames take the tile's corners.
    let tileMask: CIImage

    /// `chrome` over `backdrop`, ready to emit for any moment the camera did not
    /// cover. Flattened once here rather than composited thousands of times.
    let placeholderFrame: CIImage

    @MainActor
    static func render(childName: String, showsWordmark: Bool) -> StageArtwork? {
        guard
            let backdropImage = rasterise(
                ExportBackdrop(showsWordmark: showsWordmark), isOpaque: true
            ),
            let chromeImage = rasterise(ExportChrome(childName: childName), isOpaque: false),
            let maskImage = rasterise(ExportTileMask(), isOpaque: false)
        else { return nil }

        let backdrop = CIImage(cgImage: backdropImage)
        let chrome = CIImage(cgImage: chromeImage)

        return StageArtwork(
            backdrop: backdrop,
            chrome: chrome,
            tileMask: CIImage(cgImage: maskImage),
            placeholderFrame: chrome.composited(over: backdrop)
        )
    }

    @MainActor
    private static func rasterise(_ view: some View, isOpaque: Bool) -> CGImage? {
        let renderer = ImageRenderer(
            content: view
                .frame(width: ExportGeometry.designSize.width,
                       height: ExportGeometry.designSize.height)
        )
        renderer.scale = ExportGeometry.scale
        renderer.isOpaque = isOpaque
        return renderer.cgImage
    }
}

// MARK: - The layers

private struct ExportBackdrop: View {
    let showsWordmark: Bool

    var body: some View {
        Palette.stage
            .overlay {
                Image("SantaPortrait")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                ExportNameBadge(name: "Santa", fontSize: 14)
                    .padding(ExportGeometry.tileInset)
            }
            .overlay(alignment: .bottomTrailing) {
                if showsWordmark { wordmark.padding(ExportGeometry.tileInset) }
            }
            // The tile's base fill and its shadow live here, under everything
            // that will cover them. A shadow cast by the camera's own frames
            // would have to be re-drawn every frame for no visible difference.
            .overlay(alignment: .topTrailing) { placeholderTile.padding(ExportGeometry.tileInset) }
    }

    private var placeholderTile: some View {
        RoundedRectangle(cornerRadius: ExportGeometry.tileCornerRadius, style: .continuous)
            .fill(Palette.pictureInPicture)
            .frame(width: ExportGeometry.tileSize.width, height: ExportGeometry.tileSize.height)
            .overlay {
                AvatarSilhouette()
                    .fill(Color(hex: 0xEDF2FF, opacity: 0.26))
                    .frame(width: 44, height: 44)
            }
            .shadow(color: .black.opacity(0.5), radius: 14, y: 10)
    }

    /// Free tier only. A parent who has paid is sending a keepsake, not an
    /// advert.
    private var wordmark: some View {
        Text("SantaTalk")
            .font(Typeface.rounded(15, .semibold))
            .tracking(-0.2)
            .foregroundStyle(Palette.snow.opacity(0.55))
            .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
    }
}

private struct ExportChrome: View {
    let childName: String

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ExportGeometry.tileCornerRadius, style: .continuous)
                    .stroke(Color(hex: 0xEDF2FF, opacity: 0.22), lineWidth: 1.2)
                    .frame(width: ExportGeometry.tileSize.width,
                           height: ExportGeometry.tileSize.height)
                    .overlay(alignment: .bottomLeading) {
                        ExportNameBadge(name: childName, fontSize: 11).padding(8)
                    }
                    .padding(ExportGeometry.tileInset)
            }
    }
}

private struct ExportTileMask: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ExportGeometry.tileCornerRadius, style: .continuous)
                    .fill(Color.white)
                    .frame(width: ExportGeometry.tileSize.width,
                           height: ExportGeometry.tileSize.height)
                    .padding(ExportGeometry.tileInset)
            }
    }
}

/// `TileNameBadge` with its blur taken out.
///
/// `ImageRenderer` cannot draw `.ultraThinMaterial` — materials are composited
/// by the window server, and there is no window here. Using the real badge would
/// silently produce a badge with no background at all, so the blur is replaced
/// with the solid it resolves to over a dark stage.
private struct ExportNameBadge: View {
    let name: String
    let fontSize: CGFloat

    var body: some View {
        Text(name)
            .font(Typeface.rounded(fontSize, .regular))
            .foregroundStyle(Palette.snow)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: 0x070C1E, opacity: 0.72))
            }
    }
}
