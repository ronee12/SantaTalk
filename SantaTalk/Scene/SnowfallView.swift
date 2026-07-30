import SwiftUI

/// Tier 1 ambient motion: slow falling snow, always running behind the kid zone.
/// With Reduce Motion on the snow becomes static, as the design system requires.
struct SnowfallView: View {
    var count: Int = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for flake in flakes {
                    let point = position(of: flake, at: now, in: size)
                    let rect = CGRect(x: point.x, y: point.y, width: flake.size, height: flake.size)
                    context.opacity = flake.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.snow))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var flakes: [Flake] {
        reduceMotion ? Flake.still : Flake.falling(count: count)
    }

    /// The comp's keyframe is `translate3d(0,-40px) → translate3d(14px,900px)` over 7–15s.
    private func position(of flake: Flake, at now: TimeInterval, in size: CGSize) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: flake.x * size.width, y: flake.y * size.height)
        }
        let travel = size.height + 120
        let cycle = (now / flake.duration + flake.phase).truncatingRemainder(dividingBy: 1)
        return CGPoint(
            x: flake.x * size.width + 14 * cycle,
            y: -40 + travel * cycle
        )
    }
}

/// One snowflake. The set is generated once and reused so the field does not reshuffle
/// on every redraw.
private struct Flake {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let duration: TimeInterval
    let phase: Double

    static func falling(count: Int) -> [Flake] {
        if let cached = Cache.falling[count] { return cached }
        var generator = SystemRandomNumberGenerator()
        let made = (0..<count).map { _ in
            Flake(
                x: .random(in: -0.02...1, using: &generator),
                y: 0,
                size: .random(in: 2...5.5, using: &generator),
                opacity: .random(in: 0.18...0.8, using: &generator),
                duration: .random(in: 7...15, using: &generator),
                phase: .random(in: 0...1, using: &generator)
            )
        }
        Cache.falling[count] = made
        return made
    }

    static let still: [Flake] = {
        var generator = SystemRandomNumberGenerator()
        return (0..<26).map { _ in
            Flake(
                x: .random(in: -0.02...1, using: &generator),
                y: .random(in: 0...1, using: &generator),
                size: .random(in: 2...5.5, using: &generator),
                opacity: .random(in: 0.18...0.8, using: &generator),
                duration: 1,
                phase: 0
            )
        }
    }()

    private enum Cache {
        static var falling: [Int: [Flake]] = [:]
    }
}
