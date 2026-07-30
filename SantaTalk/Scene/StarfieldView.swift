import SwiftUI

/// Fifty-four twinkling stars in the upper half of the sky. Tier 1 ambient motion.
struct StarfieldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for star in Star.field {
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.size,
                        height: star.size
                    )
                    let twinkle: (opacity: Double, scale: CGFloat) =
                        reduceMotion ? (opacity: 1, scale: 1) : star.twinkle(at: now)
                    context.opacity = star.opacity * twinkle.opacity
                    var path = Path(ellipseIn: rect)
                    path = path.applying(
                        CGAffineTransform(translationX: rect.midX, y: rect.midY)
                            .scaledBy(x: twinkle.scale, y: twinkle.scale)
                            .translatedBy(x: -rect.midX, y: -rect.midY)
                    )
                    context.fill(path, with: .color(star.warm ? Palette.firelightSoft : Palette.snow))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let warm: Bool
    let duration: TimeInterval
    let phase: Double

    /// `twinkle` runs opacity .25 → 1 and scale .8 → 1.25 on an ease-in-out loop.
    func twinkle(at now: TimeInterval) -> (opacity: Double, scale: CGFloat) {
        let t = (now / duration + phase).truncatingRemainder(dividingBy: 1)
        let eased = (1 - cos(t * 2 * .pi)) / 2
        return (0.25 + 0.75 * eased, 0.8 + 0.45 * eased)
    }

    static let field: [Star] = {
        var generator = SystemRandomNumberGenerator()
        return (0..<54).map { index in
            Star(
                x: .random(in: 0.01...0.99, using: &generator),
                y: .random(in: 0.01...0.46, using: &generator),
                size: .random(in: 1.2...2.8, using: &generator),
                opacity: .random(in: 0.25...0.9, using: &generator),
                warm: index % 7 == 0,
                duration: .random(in: 2.6...6.5, using: &generator),
                phase: .random(in: 0...1, using: &generator)
            )
        }
    }()
}
