import SwiftUI

/// Every failure a child sees. Never an error — a story beat and one visible way
/// forward. No status codes, no prices, and no retry loop that spends money
/// without a grown-up choosing to.
struct CallFailedView: View {
    @Environment(AppState.self) private var state
    let error: SantaCallError

    var body: some View {
        VStack(spacing: Metrics.Space.xl) {
            Image("SantaPortrait")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 128, height: 128)
                .clipShape(.circle)
                .overlay { Circle().stroke(Color(hex: 0xF5B14C, opacity: 0.55), lineWidth: 2) }
                .opacity(0.6)

            Text(error.childFacingMessage)
                .font(Typeface.rounded(24, .semibold))
                .tracking(-0.3)
                .foregroundStyle(Palette.snow)
                .lineHeight(1.3, size: 24)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            OutlinePill(title: "Try again", action: state.cancelCall)
        }
        .padding(.horizontal, Metrics.Space.xxl)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
