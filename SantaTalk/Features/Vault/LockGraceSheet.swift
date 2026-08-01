import SwiftUI

/// How long the vault stays open after the parent leaves it.
///
/// There is no "Never". The gate is the only thing standing between a child and
/// the recordings, the wish list and a price — an option that switches it off
/// permanently is one nobody should be able to tap by accident.
struct LockGraceSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        BottomSheetContainer(
            maxHeightFraction: 0.62,
            background: Palette.sheet.opacity(0.98),
            onDismiss: { state.vaultSheet = nil }
        ) {
            SheetHeader(title: "Ask again after") { state.vaultSheet = nil }

            VStack(spacing: 0) {
                ForEach(LockGrace.options) { option in
                    SheetOptionRow(
                        label: option.label,
                        isActive: state.lockGraceSeconds == option.seconds,
                        action: { state.selectLockGrace(option) }
                    )
                }

                Text("However long you pick, closing the app locks the vault straight away.")
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.faint)
                    .lineHeight(1.5, size: 13)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.Space.m)
                    .padding(.top, Metrics.Space.m)
            }
            .padding(.horizontal, Metrics.Space.m)
            .padding(.bottom, Metrics.sheetBottom)
        }
    }
}
