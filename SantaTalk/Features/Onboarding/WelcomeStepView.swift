import SwiftUI

/// Step 1 of 6. One object, four words, one button — the only screen with no chrome at all.
///
/// Nothing is known about the child yet, so nothing is claimed: a living photograph of a
/// phone about to ring, a line with no promise in it, and the tap itself. No face, because a
/// stranger's face on screen one is the fastest way to lose a cautious parent.
///
/// The clip plays through once and holds its last frame. A loop draws the eye back every few
/// seconds, which is the wrong pull on the one screen whose job is to be read and tapped.
struct WelcomeStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            LoopingVideoView(resource: "WelcomeLoop", loops: false)
                .ignoresSafeArea()

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

                // One line, kept on one line — the comp sets it `nowrap`.
                Text("Calls from the North Pole")
                    .font(Typeface.rounded(28, .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.cream)
                    .lineHeight(1.14, size: 28)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .shadow(color: Color(hex: 0x040818, opacity: 0.7), radius: 15, y: 2)

                AmberButton(
                    title: "Begin",
                    height: 56,
                    cornerRadius: Metrics.Radius.tile,
                    action: state.nextStep
                )
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 6)
        }
    }
}
