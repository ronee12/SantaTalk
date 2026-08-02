import CoreGraphics

/// Where everything sits in a shared video.
///
/// The artwork is laid out in *design points* — a 405×720 frame, the same 9:16
/// proportion as the phone — so the SwiftUI that draws it can use the same font
/// sizes and paddings as the rest of the app instead of numbers multiplied up by
/// hand. `ImageRenderer` is then run at `scale`, which lands exactly on
/// 1080×1920 because 405 × (1080/405) is 1080 with nothing left over.
/// Explicitly `nonisolated`: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` would
/// otherwise put these constants on the main actor, and every one of them is
/// read from the Core Image handler on a background thread.
nonisolated enum ExportGeometry {

    /// The frame the artwork views are laid out in.
    static let designSize = CGSize(width: 405, height: 720)

    /// What actually gets encoded. 1080×1920 is the tallest size every social
    /// app accepts without re-encoding.
    static let pixelSize = CGSize(width: 1080, height: 1920)

    static var scale: CGFloat { pixelSize.width / designSize.width }

    /// Slightly larger than the player's 88×132 tile: the player's stage is
    /// inset inside a screen, this one is full bleed, so the tile needs the
    /// extra size to hold the same visual weight.
    static let tileSize = CGSize(width: 96, height: 144)
    static let tileInset: CGFloat = 16
    static let tileCornerRadius: CGFloat = 16

    /// The tile in design points, measured from the top-left as SwiftUI does.
    static var tileRect: CGRect {
        CGRect(
            x: designSize.width - tileInset - tileSize.width,
            y: tileInset,
            width: tileSize.width,
            height: tileSize.height
        )
    }

    /// The same tile in pixels, measured from the bottom-left as Core Image
    /// does. Every per-frame calculation works in this space.
    static var tileRectInPixels: CGRect {
        let rect = tileRect
        return CGRect(
            x: rect.minX * scale,
            y: (designSize.height - rect.maxY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    /// The full frame in Core Image pixel space.
    static var frameRect: CGRect {
        CGRect(origin: .zero, size: pixelSize)
    }
}
