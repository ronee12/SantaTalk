import SwiftUI

/// Says once that a booked call came and went.
///
/// Phrased as Santa waiting rather than the parent failing — the person reading
/// this already knows they missed it, and the app is not the right thing to be
/// disappointed in them. One offer to try again, one way to dismiss it, and it
/// never comes back.
struct MissedCallNote: View {
    let call: ScheduledCall
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Santa waited for \(call.childName)")
                    .font(Typeface.rounded(15, .semibold))
                    .foregroundStyle(Palette.snow)

                Text("The call was set for \(call.whenLabel).")
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .lineHeight(1.4, size: 13)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onRetry) {
                    Text("Set it up again")
                        .font(Typeface.rounded(14, .semibold))
                        .foregroundStyle(Palette.firelight)
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Text("✕")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                .fill(Palette.glassRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                        .stroke(Color(hex: 0xF5B14C, opacity: 0.28), lineWidth: 1)
                }
        }
    }
}
