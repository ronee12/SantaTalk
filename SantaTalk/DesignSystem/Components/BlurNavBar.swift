import SwiftUI

/// The translucent nav-bar background shared by the vault and the chat thread.
private struct TranslucentNavBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            // The bar's fill runs up behind the status bar; only its content stays inside
            // the safe area.
            Palette.navBlur
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairline).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }
}

extension View {
    func translucentNavBackground() -> some View {
        modifier(TranslucentNavBackground())
    }
}

/// Chevron plus a word — the standard back affordance on parent screens.
struct BackLabelButton: View {
    let title: String
    var color: Color = Palette.firelight
    var chevronColor: Color = Palette.firelightSoft
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ChevronShape()
                    .stroke(chevronColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 18)
                Text(title)
                    .font(Typeface.rounded(17, .regular))
                    .foregroundStyle(color)
            }
            .padding(.leading, 6)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// A trailing text action in a nav bar — Lock, Delete.
struct NavTextButton: View {
    let title: String
    var color: Color = Palette.firelight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.rounded(17, .regular))
                .foregroundStyle(color)
                .padding(.trailing, 12)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
