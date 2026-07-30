import SwiftUI

/// Step 6 of 8. The screen the product lives or dies on. One specific detail turns a novelty
/// into a memory — so it is skippable, examples are one tap away, and the privacy sentence
/// sits directly under the field where the hesitation happens.
struct SecretStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                step: state.step,
                onBack: state.previousStep,
                trailing: .init(title: "Skip", action: state.nextStep)
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tell Santa one thing only you would know.").questionStyle()

                    Text("This is the difference between a nice call and a call she talks about for a year.")
                        .subtitleStyle()
                        .padding(.top, Metrics.Space.s)
                        .padding(.bottom, Metrics.Space.l)

                    GlassTextEditor(
                        placeholder: "She lost her first tooth on Tuesday…",
                        text: Binding(get: { state.secret }, set: { state.secret = $0 }),
                        accessibilityTitle: "Something only Santa would know"
                    )

                    // Dashed borders mark these as fill-ins, not selections.
                    FlowLayout(spacing: Metrics.Space.s, lineSpacing: Metrics.Space.s) {
                        ForEach(Catalog.secretExamples, id: \.self) { example in
                            ExampleChip(label: example) { state.secret = example }
                        }
                    }
                    .padding(.top, Metrics.Space.m)

                    Text("Stored on this device, sent to Santa's voice for the call and nothing else.")
                        .footnoteStyle()
                        .lineHeight(1.5, size: 13)
                        .padding(.top, Metrics.Space.l)
                        .padding(.bottom, Metrics.Space.s)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.xl)
            }
            .scrollIndicators(.hidden)

            AmberButton(title: "Continue", action: state.nextStep)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.m)
                .padding(.bottom, Metrics.bottom)
        }
    }
}

private struct ExampleChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.firelight)
                .padding(.horizontal, Metrics.Space.m)
                .frame(minHeight: 36)
                .background {
                    Capsule()
                        .fill(Palette.glassSunk)
                        .overlay {
                            Capsule().stroke(
                                Color(hex: 0xF5B14C, opacity: 0.4),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                        }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
