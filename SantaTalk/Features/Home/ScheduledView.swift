import SwiftUI

/// A promise with a receipt. Never "booked" or "confirmed" — plain words a tired parent
/// reads once.
struct ScheduledView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: Metrics.Space.xl) {
            Circle()
                .fill(Color(hex: 0x4FD3A0, opacity: 0.16))
                .overlay { Circle().stroke(Color(hex: 0x4FD3A0, opacity: 0.45), lineWidth: 1) }
                .frame(width: 96, height: 96)
                .overlay {
                    CheckGlyph()
                        .stroke(Palette.pine,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 40, height: 30)
                }

            VStack(spacing: 0) {
                Text("Santa will call \(state.childName)")
                    .font(Typeface.rounded(24, .semibold))
                    .foregroundStyle(Palette.snow)

                Text(state.confirmedWhenLabel)
                    .font(Typeface.rounded(18, .regular))
                    .foregroundStyle(Palette.firelightSoft)
                    .padding(.top, 10)

                // Only promised when it can actually be kept. With notifications
                // refused there is no reminder to send, and saying otherwise is
                // how a parent misses the call they booked.
                Text(state.scheduleReminderLine)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .lineHeight(1.5, size: 15)
                    .padding(.top, Metrics.Space.m)

                Text("It is saved under Scheduled calls in the vault — change or cancel it there any time.")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .lineHeight(1.5, size: 15)
                    .padding(.top, 14)
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Metrics.Space.m) {
                OutlinePill(title: "Change it", action: state.changeJustBookedCall)
                AmberLink(title: "See it in the vault", action: state.openScheduledCalls)
                    .fixedSize()
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Metrics.Space.xxl)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
