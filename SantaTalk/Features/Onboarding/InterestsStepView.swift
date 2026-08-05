import SwiftUI

/// Step 4 of 6. Multi-select chips, no minimum. The counter underneath is encouragement,
/// not validation — being blocked here would be the wrong lesson before a paywall.
///
/// The end of the personalisation section: Continue crosses into setup, where Skip
/// disappears because nothing there is optional.
struct InterestsStepView: View {
    @Environment(AppState.self) private var state

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

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What is \(state.childName) into?").questionStyle()

                    Text("Pick two or three. Santa brings them up himself, which is the moment that lands.")
                        .subtitleStyle()
                        .padding(.top, 10)
                        .padding(.bottom, 20)

                    FlowLayout(spacing: 10, lineSpacing: 10) {
                        ForEach(Catalog.interests, id: \.self) { interest in
                            InterestChip(
                                label: interest,
                                isSelected: state.isInterestSelected(interest),
                                action: { state.toggleInterest(interest) }
                            )
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.xl)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Text(state.interestCountLabel)
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.secondary)

                AmberButton(title: "Continue", action: state.nextStep)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.Space.m)
            .padding(.bottom, Metrics.bottom)
        }
    }
}

/// A 44pt chip with a leading `+` or `✓`, so state is never colour-only.
private struct InterestChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.s) {
                Text(isSelected ? "✓" : "+")
                    .font(Typeface.rounded(15, .bold))
                    .foregroundStyle(isSelected ? Color(hex: 0x1B2338) : Color(hex: 0x8A6420))
                    .frame(width: 12)

                Text(label)
                    .font(Typeface.rounded(16, .medium))
                    .foregroundStyle(isSelected ? Palette.onAmber : Palette.snow)
            }
            .padding(.horizontal, Metrics.listGutter)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Gradients.amberChip) : AnyShapeStyle(Palette.glassRaised))
                    .overlay {
                        Capsule().stroke(isSelected ? Palette.firelightSoft : Palette.strokeStrong, lineWidth: 1)
                    }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
