import SwiftUI

/// SF Rounded throughout, per the design system. Sizes and weights come from the comp.
enum Typeface {

    static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The system alert on the microphone step deliberately uses the platform face,
    /// because a custom-looking permission dialog reads as a phishing attempt.
    static func system(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

private struct LineHeightModifier: ViewModifier {
    let fontSize: CGFloat
    let multiple: CGFloat

    /// SF renders at roughly 1.21x its point size, so only the remainder is added as spacing.
    private var spacing: CGFloat { max(0, fontSize * (multiple - 1.21)) }

    func body(content: Content) -> some View {
        content.lineSpacing(spacing)
    }
}

extension View {
    /// Reproduces a CSS `line-height` multiple on a SwiftUI `Text`.
    func lineHeight(_ multiple: CGFloat, size: CGFloat) -> some View {
        modifier(LineHeightModifier(fontSize: size, multiple: multiple))
    }
}

extension Text {

    /// 24pt semibold, -0.3 tracking — every onboarding and step question.
    func questionStyle() -> some View {
        self.font(Typeface.rounded(24, .semibold))
            .tracking(-0.3)
            .foregroundStyle(Palette.snow)
            .lineHeight(1.3, size: 24)
    }

    /// 16pt regular secondary copy sitting under a question.
    func subtitleStyle() -> some View {
        self.font(Typeface.rounded(16, .regular))
            .foregroundStyle(Palette.secondary)
            .lineHeight(1.5, size: 16)
    }

    /// 13pt helper text under a field or list.
    func footnoteStyle(_ color: Color = Palette.secondary) -> some View {
        self.font(Typeface.rounded(13, .regular))
            .foregroundStyle(color)
            .lineHeight(1.45, size: 13)
    }

    /// The uppercase 13pt section captions used across the vault.
    func sectionCaptionStyle() -> some View {
        self.font(Typeface.rounded(13, .regular))
            .tracking(0.4)
            .foregroundStyle(Palette.secondary)
    }
}
