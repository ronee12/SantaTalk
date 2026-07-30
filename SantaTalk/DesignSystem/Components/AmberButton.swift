import SwiftUI

/// The primary call to action. Amber always means go, so there is no greyed-out amber —
/// the disabled state is flat glass instead.
struct AmberButton: View {
    let title: String
    var height: CGFloat = 52
    var cornerRadius: CGFloat = Metrics.Radius.card
    var fontSize: CGFloat = 18
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if isEnabled { action() } }) {
            Text(title)
                .font(Typeface.rounded(fontSize, isEnabled ? .bold : .semibold))
                .foregroundStyle(isEnabled ? Palette.onAmber : Palette.faint)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background {
                    if isEnabled {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Gradients.amberButton)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(height: 1)
                                    .padding(.horizontal, cornerRadius / 2)
                            }
                            .shadow(color: Palette.firelight.opacity(0.3), radius: 13, y: 10)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Palette.glass)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isEnabled ? [] : .isStaticText)
    }
}

/// The quiet amber text link that sits under a primary button.
struct AmberLink: View {
    let title: String
    var color: Color = Palette.firelight
    var fontSize: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.rounded(fontSize, .regular))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Metrics.parentTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// A bordered pill used for Cancel and Change it on the kid-zone confirmation screens.
struct OutlinePill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.rounded(16, .regular))
                .foregroundStyle(Palette.snow)
                .padding(.horizontal, 20)
                .frame(minHeight: Metrics.parentTarget)
                .overlay {
                    Capsule().stroke(Color(hex: 0xEDF2FF, opacity: 0.2), lineWidth: 1)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
