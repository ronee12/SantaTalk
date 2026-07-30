import SwiftUI

/// The night scene that runs behind every screen a child sees: aurora, moon, stars, a sleigh
/// crossing the sky, drifting snow and two snow drifts. Parent screens sit still instead.
///
/// All of it is native SwiftUI — no animation dependency, per the design system.
struct NightSceneView: View {
    /// Drives the sleigh's horizontal position; it flies further with every answered step.
    var sleighProgress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                skyGradient(size: size)
                aurora(size: size)
                moon(size: size)
                StarfieldView()
                sleigh(size: size)
                SnowfallView()
                drifts(size: size)
                vignette
            }
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Layers

    /// `radial-gradient(130% 88% at 50% -16%, #24376F, #131F4C 40%, #0A1132 70%, #05091E 100%)`
    private func skyGradient(size: CGSize) -> some View {
        RadialGradient(
            stops: [
                .init(color: Palette.nightTop, location: 0),
                .init(color: Palette.nightUpper, location: 0.40),
                .init(color: Palette.nightLower, location: 0.70),
                .init(color: Palette.nightFloor, location: 1)
            ],
            center: UnitPoint(x: 0.5, y: -0.16),
            startRadius: 0,
            endRadius: max(size.width * 0.65, size.height * 0.88)
        )
    }

    private func aurora(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0.5 : auroraPhase(at: timeline.date)

            ZStack {
                auroraBlob(color: Color(hex: 0x4FD3A0, opacity: 0.22), center: UnitPoint(x: 0.28, y: 0.55))
                auroraBlob(color: Color(hex: 0x967CFF, opacity: 0.20), center: UnitPoint(x: 0.66, y: 0.42))
                auroraBlob(color: Color(hex: 0xF5B14C, opacity: 0.14), center: UnitPoint(x: 0.88, y: 0.62))
            }
            .frame(width: size.width * 1.5, height: size.height * 0.66)
            .blur(radius: 34)
            .scaleEffect(x: 1, y: 1 + 0.15 * phase, anchor: .center)
            .opacity(0.6 + 0.4 * phase)
            .offset(x: size.width * (-0.04 + 0.08 * phase), y: size.height * 0.03 * phase)
            .position(x: size.width * 0.5, y: size.height * 0.09)
        }
    }

    /// A 24s ease-in-out alternating loop, expressed as a 0...1 phase.
    private func auroraPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 48) / 48
        return CGFloat((1 - cos(t * 2 * .pi)) / 2)
    }

    private func auroraBlob(color: Color, center: UnitPoint) -> some View {
        RadialGradient(colors: [color, color.opacity(0)], center: center, startRadius: 0, endRadius: 160)
    }

    private func moon(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: 0xFFD79A, opacity: 0.26), location: 0),
                            .init(color: Color(hex: 0xFFD79A, opacity: 0.11), location: 0.40),
                            .init(color: Color(hex: 0xFFD79A, opacity: 0), location: 0.70)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .position(x: size.width + 56 - 140, y: -70 + 140)

            Circle()
                .fill(Color(hex: 0xFFF3DC))
                .frame(width: 10, height: 10)
                .shadow(color: Color(hex: 0xFFD79A, opacity: 0.9), radius: 11)
                .shadow(color: Color(hex: 0xFFD79A, opacity: 0.5), radius: 24)
                .position(x: size.width - 74 - 5, y: 34 + 5)
        }
    }

    private func sleigh(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let bob: CGFloat = reduceMotion ? 0 : -7 * bobPhase(at: timeline.date)

            SleighMark()
                .frame(width: 86, height: 30)
                .offset(y: bob)
                .position(x: size.width * sleighProgress + 43, y: 98 + 15)
                .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.1), value: sleighProgress)
        }
    }

    /// A 5s ease-in-out bob, expressed as a 0...1 phase.
    private func bobPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5
        return CGFloat((1 - cos(t * 2 * .pi)) / 2)
    }

    private func drifts(size: CGSize) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x16235A), Color(hex: 0x0B1236)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size.width * 0.96, height: 640)
                .position(x: size.width * 0.22, y: size.height + 140 - 160)

            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x101A46), Color(hex: 0x070C24)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size.width * 1.04, height: 680)
                .position(x: size.width * 0.78, y: size.height + 160 - 170)
        }
    }

    private var vignette: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x05091E, opacity: 0.50), location: 0),
                .init(color: Color(hex: 0x05091E, opacity: 0.15), location: 0.16),
                .init(color: Color(hex: 0x05091E, opacity: 0), location: 0.34),
                .init(color: Color(hex: 0x05091E, opacity: 0.50), location: 0.80),
                .init(color: Color(hex: 0x05091E, opacity: 0.78), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The dotted trail, sleigh body, antlers and lantern from the comp's inline SVG.
private struct SleighMark: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 86, sy = size.height / 30
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

            var trail = Path()
            trail.move(to: point(2, 22))
            trail.addCurve(to: point(15, 19), control1: point(8, 22), control2: point(11, 19))
            trail.addCurve(to: point(26, 22), control1: point(19, 19), control2: point(21, 22))
            trail.addLine(to: point(56, 22))
            trail.addCurve(to: point(71, 16), control1: point(62, 22), control2: point(65, 16))
            context.stroke(
                trail,
                with: .color(Color(hex: 0xFFD79A, opacity: 0.55)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 6])
            )

            var body = Path()
            body.move(to: point(56, 20))
            body.addCurve(to: point(65, 13), control1: point(57, 15), control2: point(61, 13))
            body.addCurve(to: point(72, 15), control1: point(68, 13), control2: point(69, 15))
            body.addCurve(to: point(77, 12), control1: point(74, 15), control2: point(75, 14))
            body.addLine(to: point(81, 16))
            body.addCurve(to: point(72, 22), control1: point(79, 19), control2: point(76, 22))
            body.closeSubpath()
            context.fill(body, with: .color(Color(hex: 0xEDF2FF, opacity: 0.75)))

            var antlers = Path()
            antlers.move(to: point(70, 13))
            antlers.addLine(to: point(74, 7))
            antlers.addLine(to: point(76, 10))
            antlers.addLine(to: point(79, 6))
            antlers.addLine(to: point(81, 11))
            context.stroke(
                antlers,
                with: .color(Color(hex: 0xEDF2FF, opacity: 0.7)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )

            let lantern = Path(ellipseIn: CGRect(x: 57.6 * sx, y: 14.6 * sy, width: 4.8 * sx, height: 4.8 * sy))
            context.fill(lantern, with: .color(Palette.firelight))
        }
        .opacity(0.9)
    }
}
