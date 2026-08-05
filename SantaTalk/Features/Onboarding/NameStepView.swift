import SwiftUI

/// Step 2 of 6. Name first — the highest-value, lowest-effort answer, and hearing it spoken
/// back is what sells the rest of the setup.
///
/// Skip in the corner jumps the whole three-screen personalisation section: a parent who
/// wants to hear Santa now should not be blocked by a form.
struct NameStepView: View {
    @Environment(AppState.self) private var state
    @FocusState private var isFocused: Bool

    private var isNameEntered: Bool { !state.childName.trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                step: state.step,
                onBack: state.previousStep,
                trailing: .init(
                    title: "Skip",
                    accessibilityLabel: "Skip personalisation",
                    action: state.skipPersonalisation
                )
            )

            VStack(alignment: .leading, spacing: 0) {
                Text("Who is Santa calling?").questionStyle()

                Text("He will say this out loud, so spell it the way it sounds.")
                    .subtitleStyle()
                    .padding(.top, Metrics.Space.s)
                    .padding(.bottom, Metrics.Space.xl)

                GlassTextField(
                    placeholder: "First name",
                    text: Binding(get: { state.childName }, set: { state.childName = $0 }),
                    accessibilityTitle: "Child's first name"
                )
                .focused($isFocused)

                Text("Nicknames work better than full names. “Maya”, not “Mayabella Rose”.")
                    .footnoteStyle()
                    .padding(.top, Metrics.Space.m)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 28)

            Spacer(minLength: 0)

            // Disabled is flat glass, never a greyed amber — amber always means go.
            AmberButton(title: "Continue", isEnabled: isNameEntered, action: state.nextStep)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.m)
                .padding(.bottom, Metrics.bottom)
        }
        .onAppear { isFocused = true }
    }
}
