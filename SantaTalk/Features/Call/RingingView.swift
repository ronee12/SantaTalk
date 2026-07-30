import SwiftUI

/// The iOS contact-poster call screen, unmodified in structure. Santa is the one calling, and
/// Accept is nearly twice the size of Not now — with no swipe-to-answer for small hands.
struct RingingView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            FullBleedImage(name: "SantaPortrait")

            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x070C1E, opacity: 0.62), location: 0),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.18), location: 0.30),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.72), location: 0.68),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Metrics.Space.xs) {
                    Text("Santa")
                        .font(Typeface.rounded(40, .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(Palette.cream)
                        .shadow(color: .black.opacity(0.45), radius: 9, y: 2)

                    Text("North Pole · Audio call")
                        .font(Typeface.rounded(20, .regular))
                        .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.82))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text(state.ringingTopic)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.66))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 26)

                HStack {
                    SecondaryCallAction(title: "Remind Me", accessibilityLabel: "Remind me later") {
                        ClockGlyph()
                            .stroke(Palette.snow, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .frame(width: 24, height: 24)
                    } action: {}

                    Spacer()

                    SecondaryCallAction(title: "Message", accessibilityLabel: "Message Santa") {
                        ChatBubbleGlyph().fill(Palette.snow).frame(width: 24, height: 24)
                    } action: { state.openChat() }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)

                HStack {
                    PrimaryCallAction(
                        title: "Not now",
                        accessibilityLabel: "Not now",
                        tint: Palette.decline,
                        isHungUp: true,
                        pulses: false,
                        action: state.declineCall
                    )

                    Spacer()

                    PrimaryCallAction(
                        title: "Accept",
                        accessibilityLabel: "Answer Santa",
                        tint: Palette.accept,
                        isHungUp: false,
                        pulses: true,
                        action: state.acceptCall
                    )
                }
                .padding(.horizontal, 14)
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 10)
        }
    }
}

/// The 56pt glass controls above the answer row.
private struct SecondaryCallAction<Icon: View>: View {
    let title: String
    let accessibilityLabel: String
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Button(action: action) {
                Circle()
                    .fill(Color(hex: 0xEDF2FF, opacity: 0.16))
                    .background(.ultraThinMaterial, in: .circle)
                    .frame(width: 56, height: 56)
                    .overlay { icon }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            Text(title)
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.86))
        }
    }
}

/// The 88pt answer and decline buttons, in system red and green.
private struct PrimaryCallAction: View {
    let title: String
    let accessibilityLabel: String
    let tint: Color
    let isHungUp: Bool
    let pulses: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                ZStack {
                    // Accept is the only thing on the screen that pulses.
                    if pulses {
                        AcceptHalo().frame(width: Metrics.childTarget, height: Metrics.childTarget)
                    }

                    Circle()
                        .fill(tint)
                        .frame(width: Metrics.childTarget, height: Metrics.childTarget)
                        .shadow(color: tint.opacity(pulses ? 0.38 : 0.32), radius: 15, y: 12)
                        .overlay { HandsetIcon(isHungUp: isHungUp) }
                }
                .frame(width: Metrics.childTarget, height: Metrics.childTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            Text(title)
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.9))
        }
    }
}
