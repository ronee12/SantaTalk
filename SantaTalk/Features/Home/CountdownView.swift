import SwiftUI

/// The countdown is for the grown-up, not the child — it is the window in which the phone
/// gets handed over. No child-facing content on this screen at all.
struct CountdownView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 28) {
            Text("\(state.countdown)")
                .font(Typeface.rounded(96, .bold))
                .tracking(-3)
                .foregroundStyle(Palette.cream)
                .shadow(color: Palette.firelight.opacity(0.5), radius: 30)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.25), value: state.countdown)

            VStack(spacing: 10) {
                Text("Santa is dialling \(state.childName)")
                    .font(Typeface.rounded(20, .semibold))
                    .foregroundStyle(Palette.snow)

                Text("Put the phone down and let it ring. Keep the app open until it does.")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .lineHeight(1.5, size: 15)
            }
            .multilineTextAlignment(.center)

            OutlinePill(title: "Cancel", action: state.cancelCall)
        }
        .padding(.horizontal, Metrics.Space.xxl)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
