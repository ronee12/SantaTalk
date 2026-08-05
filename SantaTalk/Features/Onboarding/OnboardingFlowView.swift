import SwiftUI

/// Six steps in two sections, with the sleigh overhead flying further across the sky with
/// every answer.
///
/// Steps 1 to 3 are personalisation and can be skipped in one tap; the language and the data
/// screen close it out. Nothing here asks for a permission: the microphone and the camera are
/// requested at the moment a call is armed, in the parent's hands, rather than four screens
/// before anyone needs them.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            switch state.step {
            case 0: WelcomeStepView()
            case 1: NameStepView()
            case 2: AgeStepView()
            case 3: InterestsStepView()
            case 4: LanguageStepView()
            default: PrivacyStepView()
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
