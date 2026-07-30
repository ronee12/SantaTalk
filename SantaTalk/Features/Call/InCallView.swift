import SwiftUI

/// The calmest screen in the app. One burst on connect, then stillness — the child should be
/// listening to Santa, not watching sparkles. The only exit is the visible button.
struct InCallView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Palette.nightDeep.ignoresSafeArea()

            FullBleedImage(name: "SantaPortrait")

            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x070C1E, opacity: 0.60), location: 0),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.12), location: 0.26),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.10), location: 0.46),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.80), location: 0.76),
                    .init(color: Color(hex: 0x070C1E, opacity: 0.96), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Tier 3 fires once here — one of three sanctioned bursts in the whole app.
            ConfettiBurstView(token: state.burstToken)

            reactionTile

            VStack(alignment: .leading, spacing: 0) {
                callerInfo
                Spacer()
                controlGrid
                endCallButton
            }
            .padding(.horizontal, 26)
            .padding(.top, 18)
            .padding(.bottom, Metrics.bottom)
        }
    }

    // MARK: Pieces

    /// The child's camera in a 2:3 tile at top right — the position every video-calling app
    /// has trained parents to expect.
    private var reactionTile: some View {
        VStack {
            HStack {
                Spacer()
                ImageSlot(label: "Camera", cornerRadius: Metrics.Radius.tile + 2)
                    .frame(width: 104, height: 156)
                    .overlay(alignment: .bottomLeading) {
                        TileNameBadge(name: state.childName)
                            .padding(8)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.Radius.tile + 2, style: .continuous)
                            .stroke(Color(hex: 0xEDF2FF, opacity: 0.22), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 15, y: 12)
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.trailing, Metrics.listGutter)
    }

    private var callerInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Santa")
                .font(Typeface.rounded(32, .semibold))
                .tracking(-0.6)
                .foregroundStyle(Palette.cream)
                .shadow(color: .black.opacity(0.5), radius: 9, y: 2)

            Text(state.callTimerLabel)
                .font(Typeface.rounded(17, .regular))
                .monospacedDigit()
                .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.8))
                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)

            HStack(spacing: 10) {
                SpeakingIndicator(isActive: state.callService.isSantaSpeaking)
                Text(state.callService.isSantaSpeaking ? "Santa is talking" : "Santa is listening")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.82))
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Three glass controls at 70pt, in the iOS grid.
    private var controlGrid: some View {
        HStack(spacing: Metrics.Space.m) {
            CallControl(title: "Mute", accessibilityLabel: "Mute the microphone", isActive: false) {
                MicrophoneSolidIcon()
            } action: {}

            CallControl(title: "Speaker", accessibilityLabel: "Speaker on", isActive: true) {
                SpeakerIcon()
            } action: {}

            CallControl(title: "Hide me", accessibilityLabel: "Hide the reaction camera", isActive: false) {
                VideoIcon()
            } action: {}
        }
        .padding(.bottom, 30)
    }

    private var endCallButton: some View {
        VStack(spacing: 10) {
            Button(action: state.endCall) {
                Circle()
                    .fill(Palette.decline)
                    .frame(width: Metrics.childTarget, height: Metrics.childTarget)
                    .shadow(color: Palette.decline.opacity(0.34), radius: 15, y: 12)
                    .overlay { HandsetIcon(isHungUp: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End the call with Santa")

            Text("Say bye")
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.88))
        }
        .frame(maxWidth: .infinity)
    }
}

/// The four amber bars that show Santa is speaking.
struct SpeakingIndicator: View {
    /// Bars move only while Santa actually has the floor; they rest while he listens.
    var isActive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The comp's `speak1`, `speak2`, `speak3`, `speak2` keyframes.
    private struct Bar: Identifiable {
        let id: Int
        let low: CGFloat
        let high: CGFloat
        let period: Double
    }

    private let bars: [Bar] = [
        Bar(id: 0, low: 10, high: 34, period: 1.1),
        Bar(id: 1, low: 26, high: 12, period: 1.4),
        Bar(id: 2, low: 16, high: 40, period: 0.9),
        Bar(id: 3, low: 26, high: 12, period: 1.4)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !isActive)) { timeline in
            HStack(alignment: .bottom, spacing: Metrics.Space.xs) {
                ForEach(bars) { bar in
                    Capsule()
                        .fill(Palette.firelight)
                        .frame(width: 4, height: height(for: bar, at: timeline.date))
                }
            }
            .frame(height: 26, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }

    private func height(for bar: Bar, at date: Date) -> CGFloat {
        guard isActive, !reduceMotion else { return (bar.low + bar.high) / 2 }
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: bar.period) / bar.period
        let eased = CGFloat((1 - cos(t * 2 * .pi)) / 2)
        return bar.low + (bar.high - bar.low) * eased
    }
}

/// One 70pt glass control.
private struct CallControl<Icon: View>: View {
    let title: String
    let accessibilityLabel: String
    let isActive: Bool
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.s) {
            Button(action: action) {
                Circle()
                    .fill(isActive
                          ? Color(hex: 0xEDF2FF, opacity: 0.92)
                          : Color(hex: 0xEDF2FF, opacity: 0.16))
                    .background(.ultraThinMaterial, in: .circle)
                    .frame(width: 70, height: 70)
                    .overlay { icon }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)

            Text(title)
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Color(hex: 0xEDF2FF, opacity: 0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

/// The small blurred name chip on a picture-in-picture tile.
struct TileNameBadge: View {
    let name: String
    var fontSize: CGFloat = 11

    var body: some View {
        Text(name)
            .font(Typeface.rounded(fontSize, .regular))
            .foregroundStyle(Palette.snow)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: 0x070C1E, opacity: 0.6))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
    }
}
