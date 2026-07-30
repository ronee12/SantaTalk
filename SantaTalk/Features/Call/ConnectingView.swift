import SwiftUI

/// The seconds between tapping Accept and Santa's voice arriving.
///
/// It deliberately keeps the ringing screen's portrait and gradient, so answering
/// dissolves the buttons rather than cutting to a new screen — for a four-year-old
/// the call has already been answered, and a loading screen would say otherwise.
/// Nothing here reads as machinery: no spinner, no percentage, no status.
struct ConnectingView: View {
    @Environment(AppState.self) private var state

    /// The way out appears only if the line is slow. Offering it immediately
    /// would put a cancel button under a child's thumb during the half-second
    /// they are lifting the phone to their ear.
    @State private var showsWayOut = false

    var body: some View {
        ZStack {
            FullBleedImage(name: "SantaPortrait")

            // The ringing screen's stops, unchanged — the crossfade has to be invisible.
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

                    Text("North Pole · Connecting")
                        .font(Typeface.rounded(20, .regular))
                        .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.82))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                ConnectingDots()
                    .padding(.bottom, Metrics.Space.xl)

                Text("Putting you through to the North Pole")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.7))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Connecting to Santa")

                // Reserved whether or not it is showing, so the dots and the
                // line above them do not jump when it arrives.
                OutlinePill(title: "Cancel", action: state.cancelConnecting)
                    .opacity(showsWayOut ? 1 : 0)
                    .allowsHitTesting(showsWayOut)
                    .accessibilityHidden(!showsWayOut)
                    .padding(.top, Metrics.Space.xxl)
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 44)
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.4)) { showsWayOut = true }
        }
    }
}

/// Three firelight dots brightening in sequence while the line opens.
///
/// Same construction as `SpeakingIndicator` — a continuous function of the
/// timeline date rather than a repeating animation — so it cannot drift out of
/// step or keep running off-screen. Amber because this is Santa arriving; green
/// and red stay reserved for answer and decline.
struct ConnectingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let count = 3
    private let period: Double = 1.6
    private let restingGlow = 0.55

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            HStack(spacing: Metrics.Space.m) {
                ForEach(0..<count, id: \.self) { index in
                    let intensity = reduceMotion ? restingGlow : glow(for: index, at: timeline.date)

                    Circle()
                        .fill(Palette.firelight)
                        .frame(width: 10, height: 10)
                        .opacity(0.3 + 0.7 * intensity)
                        .scaleEffect(0.86 + 0.24 * intensity)
                        .shadow(color: Palette.firelight.opacity(0.45 * intensity), radius: 8)
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    /// Each dot runs the same eased swell, offset by a third of the period, so
    /// the brightness travels left to right like a line being picked up.
    private func glow(for index: Int, at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate / period
        let offset = Double(index) / Double(count)
        let t = (elapsed - offset).truncatingRemainder(dividingBy: 1)
        let wrapped = t < 0 ? t + 1 : t
        return (1 - cos(wrapped * 2 * .pi)) / 2
    }
}
