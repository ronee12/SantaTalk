import SwiftUI

/// Every parent screen sits still: a flat gradient with no scene behind it, so nothing
/// competes with a recording, a wish list or a price.
struct ParentBackdrop: View {
    var body: some View {
        Gradients.parentBackdrop
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// The firelight halo that flickers behind Santa's portrait on the home screen.
struct FirelightHalo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            let flicker = reduceMotion ? Flicker.rest : Flicker.value(at: timeline.date)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xF5B14C, opacity: 0.34), Color(hex: 0xF5B14C, opacity: 0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 78
                    )
                )
                .opacity(flicker.opacity)
                .scaleEffect(flicker.scale)
        }
        .accessibilityHidden(true)
    }

    /// The comp's six-second `flicker` keyframe, sampled continuously.
    private enum Flicker {
        static let rest: (opacity: Double, scale: CGFloat) = (opacity: 0.82, scale: 1)

        static func value(at date: Date) -> (opacity: Double, scale: CGFloat) {
            let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
            let a = sin(t * 2 * .pi)
            let b = sin(t * 4 * .pi)
            return (0.82 + 0.10 * a - 0.03 * b, 1 + 0.02 * a)
        }
    }
}

/// The pulsing ring behind the Accept button on the incoming-call screen.
struct AcceptHalo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0.0 : haloPhase(at: timeline.date)

            Circle()
                .fill(Palette.accept.opacity(0.5 * (1 - phase)))
                .scaleEffect(1 + 0.09 * (1 - abs(phase * 2 - 1)))
        }
        .accessibilityHidden(true)
    }

    private func haloPhase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 2.8
    }
}
