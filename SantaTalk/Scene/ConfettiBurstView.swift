import SwiftUI

/// Tier 3 celebratory motion. Fires in exactly one place in this build — the moment the call
/// connects — and nowhere else. Suppressed entirely under Reduce Motion.
struct ConfettiBurstView: View {
    /// Changing this token restarts the burst.
    let token: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = .distantPast

    private let duration: TimeInterval = 3.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed >= 0, elapsed <= duration else { return }

                for piece in Piece.burst {
                    let progress = piece.progress(at: elapsed)
                    guard progress > 0 else { continue }

                    let origin = CGPoint(x: piece.x * size.width, y: piece.y * size.height)
                    var transform = CGAffineTransform(
                        translationX: origin.x + piece.driftX * progress,
                        y: origin.y + 620 * progress
                    )
                    transform = transform.rotated(by: .pi * 4 * progress)

                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2,
                                      width: piece.width, height: piece.height)
                    let path = Path(roundedRect: rect, cornerRadius: 2).applying(transform)

                    context.opacity = 1 - progress
                    context.fill(path, with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(reduceMotion ? 0 : 1)
        .onAppear { if !reduceMotion { start = .now } }
        .onChange(of: token) { if !reduceMotion { start = .now } }
    }
}

private struct Piece {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let driftX: CGFloat
    let color: Color
    let duration: TimeInterval
    let delay: TimeInterval

    /// `cubic-bezier(.2,.6,.35,1)` approximated with an ease-out curve.
    func progress(at elapsed: TimeInterval) -> CGFloat {
        let t = (elapsed - delay) / duration
        guard t > 0 else { return 0 }
        guard t < 1 else { return 1 }
        return CGFloat(1 - pow(1 - t, 2.2))
    }

    static let burst: [Piece] = {
        let colors: [Color] = [
            Palette.firelight, Palette.firelightSoft, Palette.snow, Palette.firelight, Palette.santa
        ]
        var generator = SystemRandomNumberGenerator()
        return (0..<46).map { index in
            let width = CGFloat.random(in: 5...11, using: &generator)
            return Piece(
                x: .random(in: 0.06...0.94, using: &generator),
                y: .random(in: 0.06...0.34, using: &generator),
                width: width,
                height: width * .random(in: 0.4...1, using: &generator),
                driftX: .random(in: -90...90, using: &generator),
                color: colors[index % colors.count],
                duration: .random(in: 1.6...2.6, using: &generator),
                delay: .random(in: 0...0.35, using: &generator)
            )
        }
    }()
}
