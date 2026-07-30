import SwiftUI

/// Step 2 of 8. Language before anything else, so every later screen is already in the
/// parent's language. Flag first, native name above the English one.
struct LanguageStepView: View {
    @Environment(AppState.self) private var state

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: state.step, onBack: state.previousStep)

            VStack(alignment: .leading, spacing: Metrics.Space.s) {
                Text("What language should Santa speak?").questionStyle()
                Text("He calls in this voice and accent. You can change it before any call.")
                    .subtitleStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.Space.xl)
            .padding(.bottom, Metrics.Space.m)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Catalog.languages) { language in
                        LanguageTile(
                            language: language,
                            isSelected: state.language == language,
                            action: { state.language = language }
                        )
                    }
                }
                .padding(.horizontal, Metrics.listGutter)
            }
            .scrollIndicators(.hidden)

            AmberButton(title: "Continue in \(state.language.native)", action: state.nextStep)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.m)
                .padding(.bottom, Metrics.bottom)
        }
    }
}

private struct LanguageTile: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.Space.xs) {
                Text(language.flag)
                    .font(.system(size: 28))
                Text(language.native)
                    .font(Typeface.rounded(14, .semibold))
                    .foregroundStyle(isSelected ? Palette.onAmber : Palette.snow)
                    .lineHeight(1.2, size: 14)
                if !language.subtitle.isEmpty {
                    Text(language.subtitle)
                        .font(Typeface.rounded(11, .regular))
                        .foregroundStyle(isSelected ? Palette.onAmber.opacity(0.62) : Palette.tertiary)
                        .lineHeight(1.2, size: 11)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96)
            .padding(.horizontal, 6)
            .padding(.vertical, Metrics.Space.m)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Gradients.amberChip) : AnyShapeStyle(Palette.glassSunk))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Palette.firelightSoft : Palette.hairline, lineWidth: 1)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.english)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
