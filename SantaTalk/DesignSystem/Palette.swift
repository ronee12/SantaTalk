import SwiftUI

extension Color {
    /// Creates a colour from a `0xRRGGBB` literal, matching the hex values in the design comp.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Every colour in the app. Names follow the design system doc; values follow the comp.
enum Palette {

    // MARK: Night (kid zone)

    static let nightDeep = Color(hex: 0x070C1E)
    static let nightTop = Color(hex: 0x24376F)
    static let nightUpper = Color(hex: 0x131F4C)
    static let nightLower = Color(hex: 0x0A1132)
    static let nightFloor = Color(hex: 0x05091E)

    // MARK: Parent zone backdrop

    static let parentTop = Color(hex: 0x131E45)
    static let parentMid = Color(hex: 0x0C1533)
    static let parentBottom = Color(hex: 0x070C1E)

    // MARK: Text

    static let snow = Color(hex: 0xEDF2FF)
    static let cream = Color(hex: 0xFFF6E6)
    static let secondary = Color(hex: 0xA6B2D4)
    static let tertiary = Color(hex: 0x8E9BBD)
    static let dim = Color(hex: 0x8894B8)
    static let faint = Color(hex: 0x7C88AA)
    static let chevron = Color(hex: 0xC6D0EC)

    // MARK: Firelight

    static let firelight = Color(hex: 0xF5B14C)
    static let firelightSoft = Color(hex: 0xFFD79A)
    static let amberTop = Color(hex: 0xFFE0AE)
    static let amberBottom = Color(hex: 0xE39A2E)
    /// Text that sits on top of firelight. Never white — contrast fails.
    static let onAmber = Color(hex: 0x2A1505)

    // MARK: Santa red

    static let santa = Color(hex: 0xC8102E)
    static let santaBright = Color(hex: 0xE8394F)

    // MARK: System-matched call controls

    static let decline = Color(hex: 0xFF453A)
    static let accept = Color(hex: 0x34C759)
    static let systemBlue = Color(hex: 0x007AFF)

    // MARK: State

    static let pine = Color(hex: 0x4FD3A0)
    static let destructive = Color(hex: 0xFF7A8A)

    // MARK: Surfaces

    static let stage = Color(hex: 0x0B1226)
    static let pictureInPicture = Color(hex: 0x151C34)
    static let sheet = Color(hex: 0x101A3C)
    static let navBlur = Color(hex: 0x090F26)
    static let onTint = Color(hex: 0x12162B)

    // MARK: Child avatar tints

    static let tintGirl = Color(hex: 0xFFD79A)
    static let tintBoy = Color(hex: 0x9FD8FF)
    static let tintNew = Color(hex: 0xC6B6FF)

    // MARK: Translucent fills lifted straight from the comp

    static let glass = Color.white.opacity(0.06)
    static let glassRaised = Color.white.opacity(0.07)
    static let glassSunk = Color.white.opacity(0.05)
    static let hairline = Color(hex: 0xEDF2FF, opacity: 0.10)
    static let stroke = Color(hex: 0xEDF2FF, opacity: 0.14)
    static let strokeStrong = Color(hex: 0xEDF2FF, opacity: 0.16)
}

/// The gradients the comp reuses across screens.
enum Gradients {

    /// Primary call-to-action fill: `linear-gradient(180deg,#FFE0AE 0%,#F5B14C 55%,#E39A2E 100%)`.
    static let amberButton = LinearGradient(
        stops: [
            .init(color: Palette.amberTop, location: 0),
            .init(color: Palette.firelight, location: 0.55),
            .init(color: Palette.amberBottom, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Two-stop amber used on chips, pills and selected tiles.
    static let amberChip = LinearGradient(
        colors: [Palette.amberTop, Palette.firelight],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Progress and meter fills run horizontally.
    static let amberTrack = LinearGradient(
        colors: [Palette.firelight, Palette.firelightSoft],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Completed onboarding progress segment: `linear-gradient(90deg,#FFD79A,#F5B14C)`.
    static let segmentOn = LinearGradient(
        colors: [Palette.firelightSoft, Palette.firelight],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// The still backdrop behind every parent screen.
    static let parentBackdrop = LinearGradient(
        stops: [
            .init(color: Palette.parentTop, location: 0),
            .init(color: Palette.parentMid, location: 0.46),
            .init(color: Palette.parentBottom, location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The red header on the safety page.
    static let santaHeader = LinearGradient(
        colors: [Palette.santaBright, Palette.santa],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The home screen's primary call button.
    static let callButton = LinearGradient(
        colors: [Palette.santaBright, Palette.santa],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The paywall's arched header.
    static let paywallHeader = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x1B2A5C), location: 0),
            .init(color: Color(hex: 0x131E45), location: 0.55),
            .init(color: Color(hex: 0x101A3C), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
