import SwiftUI

/// Step 1 of 8. One picture, four words, one button — the only screen with no chrome at all.
/// Nothing is known about the child yet, so nothing is claimed.
struct WelcomeStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            FullBleedImage(name: "WelcomeHero")

            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x040818, opacity: 0.34), location: 0),
                    .init(color: Color(hex: 0x040818, opacity: 0), location: 0.30),
                    .init(color: Color(hex: 0x040818, opacity: 0.72), location: 0.66),
                    .init(color: Color(hex: 0x040818, opacity: 0.95), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("Santa is still awake.")
                    .font(Typeface.rounded(38, .bold))
                    .tracking(-1)
                    .foregroundStyle(Palette.cream)
                    .lineHeight(1.08, size: 38)
                    .shadow(color: Color(hex: 0x040818, opacity: 0.7), radius: 15, y: 2)
                    .fixedSize(horizontal: false, vertical: true)

                AmberButton(
                    title: "Wake him up",
                    height: 56,
                    cornerRadius: 14,
                    action: state.nextStep
                )
                .accessibilityLabel("Wake Santa up")
                .padding(.top, 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 6)
        }
    }
}
