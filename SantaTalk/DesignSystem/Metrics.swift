import SwiftUI

/// Fixed layout values from the comp.
///
/// The comp is drawn in a 402×874 device frame with the status bar and home indicator inside
/// it, so its paddings are measured from the physical screen edge — 52pt down to a nav bar,
/// 34pt up from the bottom. On device those distances *are* the safe-area insets, so screens
/// here respect the safe area and these constants carry only what is left over on top of it.
/// That keeps the design intact on Dynamic Island devices instead of tucking content under it.
enum Metrics {

    /// Extra space above the safe area for a nav bar. The comp's 52pt is the status-bar inset.
    static let navTop: CGFloat = 0
    /// Onboarding step headers sit 56pt from the edge — 4pt clear of the status bar.
    static let stepTop: CGFloat = 4
    /// The comp's 34pt bottom gutter is exactly the home-indicator inset.
    static let bottom: CGFloat = 0

    /// Sheets deliberately bleed under the home indicator, so their content pads for it.
    static let sheetBottom: CGFloat = 34

    /// Standard horizontal gutter for body content.
    static let gutter: CGFloat = 24
    /// Narrower gutter used by grids and lists that carry their own tile padding.
    static let listGutter: CGFloat = 16

    /// Spacing scale: 4, 8, 12, 16, 24, 32. Nothing between.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 12
        static let tile: CGFloat = 14
        static let sheet: CGFloat = 22
        static let group: CGFloat = 12
    }

    /// Minimum tap target for a parent-facing control.
    static let parentTarget: CGFloat = 44
    /// Minimum tap target for anything a child taps.
    static let childTarget: CGFloat = 88
}
