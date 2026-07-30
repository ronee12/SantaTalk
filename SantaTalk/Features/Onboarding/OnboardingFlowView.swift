import SwiftUI

/// Eight steps, one question per screen, with the sleigh overhead flying further across the
/// sky with every answer.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.step {
            case 0: WelcomeStepView()
            case 1: LanguageStepView()
            case 2: NameStepView()
            case 3: AgeStepView()
            case 4: InterestsStepView()
            case 5: SecretStepView()
            case 6: MicrophoneStepView()
            default: ReadyStepView()
            }
        }
        .riseIn(id: state.step)
    }
}

/// The comp's `riseIn` entrance: 14px up and faded, settling over 420ms.
struct RiseIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: hasAppeared || reduceMotion ? 0 : 14)
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.42)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Re-runs the entrance whenever `id` changes.
    func riseIn(id: some Hashable) -> some View {
        modifier(RiseIn()).id(id)
    }
}
