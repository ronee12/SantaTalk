import SwiftUI

/// Step 7 of 8. A pre-permission screen states the reason, then hands over to the system
/// alert. The recording promise is made here, before the ask, because that is the actual
/// objection.
struct MicrophoneStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: state.step, onBack: state.previousStep)

            VStack(spacing: 0) {
                Circle()
                    .fill(Palette.glass)
                    .frame(width: 96, height: 96)
                    .overlay { MicrophoneIcon() }
                    .padding(.top, Metrics.Space.m)

                Text("Santa needs to hear \(state.childName).")
                    .questionStyle()
                    .multilineTextAlignment(.center)
                    .padding(.top, Metrics.Space.xl)

                Text("iOS will ask for the microphone next. Without it the call is one-sided, and a four-year-old will not understand why Santa is ignoring her.")
                    .subtitleStyle()
                    .multilineTextAlignment(.center)
                    .padding(.top, Metrics.Space.m)

                // Pine green for the promises. Never adjacent to santa red.
                VStack(alignment: .leading, spacing: Metrics.Space.m) {
                    PromiseRow("Audio is used live, during the call.")
                    PromiseRow("Nothing is recorded unless you switch on reaction clips — and you can hear the recording before it is kept.")
                }
                .padding(Metrics.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                        .fill(Palette.glass)
                }
                .padding(.top, Metrics.Space.xl)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 28)

            Spacer(minLength: 0)

            VStack(spacing: Metrics.Space.m) {
                AmberButton(title: "Continue", action: state.askForMicrophone)
                AmberLink(title: "Not now", color: Palette.secondary, action: state.nextStep)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.Space.m)
            .padding(.bottom, Metrics.bottom)
        }
    }
}

private struct PromiseRow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.m) {
            Text("✓")
                .font(Typeface.rounded(15, .bold))
                .foregroundStyle(Palette.pine)
            Text(text)
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Palette.snow)
                .lineHeight(1.4, size: 15)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
