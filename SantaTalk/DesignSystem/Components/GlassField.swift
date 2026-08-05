import SwiftUI

/// A single-line glass field on the night scene. 56pt tall, 18pt text — thumb-sized and
/// glanceable while standing up.
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 56
    var fontSize: CGFloat = 18
    var fontWeight: Font.Weight = .medium
    var cornerRadius: CGFloat = Metrics.Radius.card
    var accessibilityTitle: String

    var body: some View {
        TextField("", text: $text, prompt: promptText)
            .font(Typeface.rounded(fontSize, fontWeight))
            .foregroundStyle(Palette.snow)
            .tint(Palette.firelight)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.horizontal, Metrics.listGutter)
            .frame(height: height)
            .background(glassBackground)
            .accessibilityLabel(accessibilityTitle)
    }

    private var promptText: Text {
        Text(placeholder).foregroundColor(Palette.faint)
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Palette.glass)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            }
    }
}
