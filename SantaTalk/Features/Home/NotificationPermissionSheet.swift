import SwiftUI

/// Asked only when a call is actually scheduled, in our own words first, naming exactly what
/// we will send.
struct NotificationPermissionSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        BottomSheetContainer(
            maxHeightFraction: 0.8,
            background: Palette.sheet.opacity(0.98),
            onDismiss: { state.sheet = nil }
        ) {
            VStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: 0xF5B14C, opacity: 0.14))
                    .overlay { Circle().stroke(Color(hex: 0xF5B14C, opacity: 0.32), lineWidth: 1) }
                    .frame(width: 64, height: 64)
                    .overlay {
                        BellIcon(size: 28, color: Palette.firelight, clapperColor: Palette.firelightSoft)
                    }

                Text("May we remind you?")
                    .font(Typeface.rounded(21, .semibold))
                    .foregroundStyle(Palette.cream)
                    .lineHeight(1.3, size: 21)

                Text("Santa is set to call \(state.notificationWhen). With notifications on we send one reminder five minutes before, and one when he rings — nothing else, ever.")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Palette.secondary)
                    .lineHeight(1.55, size: 16)
                    .fixedSize(horizontal: false, vertical: true)

                AmberButton(
                    title: "Allow notifications",
                    height: 54,
                    cornerRadius: Metrics.Radius.tile,
                    fontSize: 17,
                    action: state.allowNotifications
                )
                .padding(.top, 6)

                AmberLink(title: "Not now", color: Palette.secondary, action: state.skipNotifications)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 26)
            .padding(.bottom, Metrics.sheetBottom)
        }
    }
}
