import SwiftUI

/// The language Santa speaks, changed after onboarding.
///
/// Native name leads, exactly as it does on the onboarding step — a Greek parent
/// scans Ελληνικά, not "Greek".
struct LanguageSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        BottomSheetContainer(
            maxHeightFraction: 0.8,
            background: Palette.sheet.opacity(0.98),
            onDismiss: { state.vaultSheet = nil }
        ) {
            SheetHeader(title: "Language Santa speaks") { state.vaultSheet = nil }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Catalog.languages) { language in
                        LanguageRow(
                            language: language,
                            isActive: state.language == language,
                            action: { state.selectLanguage(language) }
                        )
                    }
                }
                .padding(.horizontal, Metrics.Space.m)
                .padding(.bottom, Metrics.sheetBottom)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct LanguageRow: View {
    let language: Language
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.m) {
                Text(language.flag)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 1) {
                    Text(language.native)
                        .font(Typeface.rounded(16, .regular))
                        .foregroundStyle(Palette.snow)

                    if !language.subtitle.isEmpty {
                        Text(language.subtitle)
                            .font(Typeface.rounded(13, .regular))
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    Text("✓")
                        .font(Typeface.rounded(15, .bold))
                        .foregroundStyle(Palette.firelight)
                }
            }
            .padding(Metrics.Space.m)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                    .fill(isActive ? Color(hex: 0xF5B14C, opacity: 0.14) : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.subtitle.isEmpty ? language.native : language.subtitle)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
