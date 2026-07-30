import SwiftUI

/// A receipt, then get out of the way. No celebration burst — the sanctioned bursts belong to
/// the child's screens.
struct PurchaseConfirmedView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                Circle()
                    .fill(Color(hex: 0x4FD3A0, opacity: 0.14))
                    .overlay { Circle().stroke(Color(hex: 0x4FD3A0, opacity: 0.34), lineWidth: 1) }
                    .frame(width: 64, height: 64)
                    .overlay {
                        CheckGlyph()
                            .stroke(Palette.pine,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .frame(width: 26, height: 20)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Santa Pro is on.")
                        .font(Typeface.rounded(25, .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.snow)
                        .lineHeight(1.25, size: 25)

                    // Repeats the renewal date and price so nothing is a surprise later.
                    Text(state.pricing.receipt(for: state.plan))
                        .font(Typeface.rounded(16, .regular))
                        .foregroundStyle(Palette.secondary)
                        .lineHeight(1.5, size: 16)
                        .padding(.top, Metrics.Space.s)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Two exits: back to the dashboard, or straight to what they just paid for.
            VStack(spacing: 10) {
                AmberButton(title: "Back to the dashboard", height: 56, action: state.returnToDashboard)
                AmberLink(title: "See the wish list now", action: state.openVault)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 20)
        .padding(.bottom, Metrics.bottom)
    }
}
