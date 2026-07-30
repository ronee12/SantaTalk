import SwiftUI

/// Step 4 of 8. A grid of tappable ages beats a wheel picker: one tap, no scrolling, every
/// option visible. The reason for asking is stated, so it does not read as data collection.
struct AgeStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: state.step, onBack: state.previousStep)

            VStack(alignment: .leading, spacing: 0) {
                Text("How old is \(state.childName)?").questionStyle()

                Text("Santa changes how he talks — shorter sentences and more patience for the little ones.")
                    .subtitleStyle()
                    .padding(.top, Metrics.Space.s)
                    .padding(.bottom, Metrics.Space.xl)

                FlowLayout(spacing: Metrics.Space.m, lineSpacing: Metrics.Space.m) {
                    ForEach(Catalog.ages, id: \.self) { age in
                        AgeTile(
                            age: age,
                            isSelected: state.age == age,
                            action: { state.age = age }
                        )
                    }
                }

                Text("Over 10? Santa will still call — he just stops explaining what reindeer eat.")
                    .footnoteStyle()
                    .padding(.top, 20)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 28)

            Spacer(minLength: 0)

            AmberButton(title: "Continue", action: state.nextStep)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.m)
                .padding(.bottom, Metrics.bottom)
        }
    }
}

private struct AgeTile: View {
    let age: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(age)")
                .font(Typeface.rounded(24, .semibold))
                .foregroundStyle(isSelected ? Palette.onAmber : Palette.chevron)
                .frame(width: 64, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Gradients.amberChip) : AnyShapeStyle(Palette.glassRaised))
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                                .stroke(isSelected ? Palette.firelightSoft : Palette.strokeStrong, lineWidth: 1)
                        }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityLabel("\(age) years old")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
