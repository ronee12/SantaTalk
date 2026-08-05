import SwiftUI

/// A shape defined in an SVG viewBox and scaled to fit its frame, so every glyph keeps the
/// exact proportions it has in the design comp.
protocol VectorGlyph: Shape {
    static var viewBox: CGSize { get }
    func draw(into path: inout Path)
}

extension VectorGlyph {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        draw(into: &path)
        let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
        let width = Self.viewBox.width * scale
        let height = Self.viewBox.height * scale
        return path.applying(
            CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(.init(translationX: (rect.width - width) / 2,
                                     y: (rect.height - height) / 2))
        )
    }
}

// MARK: - Microphone

/// `rect 8,1 8×15 r4` — the capsule of the onboarding microphone.
struct MicCapsule: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 34)
    func draw(into path: inout Path) {
        path.addRoundedRect(in: CGRect(x: 8, y: 1, width: 8, height: 15), cornerSize: CGSize(width: 4, height: 4))
    }
}

/// `M5 13a7 7 0 0 0 14 0` plus the stand and the base.
struct MicCradle: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 34)
    func draw(into path: inout Path) {
        path.addArc(center: CGPoint(x: 12, y: 13), radius: 7,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.move(to: CGPoint(x: 12, y: 20))
        path.addLine(to: CGPoint(x: 12, y: 26))
        path.move(to: CGPoint(x: 8, y: 30))
        path.addLine(to: CGPoint(x: 16, y: 30))
    }
}

/// `rect 9,2.5 6×11 r3` — the solid microphone used in call controls and the topic row.
struct MicSolidCapsule: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addRoundedRect(in: CGRect(x: 9, y: 2.5, width: 6, height: 11), cornerSize: CGSize(width: 3, height: 3))
    }
}

struct MicSolidCradle: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addArc(center: CGPoint(x: 12, y: 11), radius: 6.5,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.move(to: CGPoint(x: 12, y: 17.5))
        path.addLine(to: CGPoint(x: 12, y: 21))
    }
}

// MARK: - Data step shield

/// `M19 2.5 34.5 8v13.2c0 9.6-6.3 16.9-15.5 20.3C9.8 38.1 3.5 30.8 3.5 21.2V8L19 2.5Z`
/// — the outline of the shield on the last onboarding screen. Smaller and drawn
/// in its own viewBox, so it is not the safety page's `ShieldOutline`.
struct DataShieldOutline: VectorGlyph {
    static let viewBox = CGSize(width: 38, height: 44)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 19, y: 2.5))
        path.addLine(to: CGPoint(x: 34.5, y: 8))
        path.addLine(to: CGPoint(x: 34.5, y: 21.2))
        path.addCurve(to: CGPoint(x: 19, y: 41.5),
                      control1: CGPoint(x: 34.5, y: 30.8),
                      control2: CGPoint(x: 28.2, y: 38.1))
        path.addCurve(to: CGPoint(x: 3.5, y: 21.2),
                      control1: CGPoint(x: 9.8, y: 38.1),
                      control2: CGPoint(x: 3.5, y: 30.8))
        path.addLine(to: CGPoint(x: 3.5, y: 8))
        path.closeSubpath()
    }
}

/// `M13 21.4l4.3 4.3L25.6 17` — the tick inside the shield, in the same viewBox
/// so the two paths stack without either being re-fitted.
struct DataShieldTick: VectorGlyph {
    static let viewBox = CGSize(width: 38, height: 44)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 13, y: 21.4))
        path.addLine(to: CGPoint(x: 17.3, y: 25.7))
        path.addLine(to: CGPoint(x: 25.6, y: 17))
    }
}

// MARK: - Stars, sparkles, holly

/// The five-pointed star used on the wish-list note and the ratings row.
struct StarGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 20, height: 20)
    func draw(into path: inout Path) {
        let points: [CGPoint] = [
            .init(x: 10, y: 1), .init(x: 12.6, y: 6.7), .init(x: 18.8, y: 7.4),
            .init(x: 14.2, y: 11.6), .init(x: 15.5, y: 17.7), .init(x: 10, y: 14.6),
            .init(x: 4.5, y: 17.7), .init(x: 5.8, y: 11.6), .init(x: 1.2, y: 7.4),
            .init(x: 7.4, y: 6.7)
        ]
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
    }
}

/// The left half of a star, for the four-and-a-half rating.
struct HalfStarGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 20, height: 20)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 10, y: 1))
        path.addLine(to: CGPoint(x: 12.6, y: 6.7))
        path.addLine(to: CGPoint(x: 18.8, y: 7.4))
        path.addLine(to: CGPoint(x: 14.2, y: 11.6))
        path.addLine(to: CGPoint(x: 15.5, y: 17.7))
        path.addLine(to: CGPoint(x: 10, y: 14.6))
        path.closeSubpath()
    }
}

/// `M1 10L2 2l3.2 3L7 1l1.8 4L12 2l1 8z` — the crown on the PRO pill.
struct CrownGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 14, height: 12)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 1, y: 10))
        path.addLine(to: CGPoint(x: 2, y: 2))
        path.addLine(to: CGPoint(x: 5.2, y: 5))
        path.addLine(to: CGPoint(x: 7, y: 1))
        path.addLine(to: CGPoint(x: 8.8, y: 5))
        path.addLine(to: CGPoint(x: 12, y: 2))
        path.addLine(to: CGPoint(x: 13, y: 10))
        path.closeSubpath()
    }
}

/// The curved branch flanking "Loved by Santa" on the paywall.
struct HollyBranchGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 26, height: 52)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 20, y: 3))
        path.addCurve(to: CGPoint(x: 6, y: 26),
                      control1: CGPoint(x: 10, y: 10), control2: CGPoint(x: 6, y: 18))
        path.addCurve(to: CGPoint(x: 20, y: 49),
                      control1: CGPoint(x: 6, y: 34), control2: CGPoint(x: 10, y: 42))
    }
}

/// The four leaves along the branch.
struct HollyLeavesGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 26, height: 52)
    func draw(into path: inout Path) {
        let leaves: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (14, 9, 7, 5), (10, 18, 3, 5), (9, 28, 2, 5), (11, 37, 4, 5)
        ]
        for (x, y, dx, _) in leaves {
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(to: CGPoint(x: x - 7, y: y + 5),
                          control1: CGPoint(x: x - 4, y: y), control2: CGPoint(x: x - 6, y: y + 2))
            path.addCurve(to: CGPoint(x: x, y: y),
                          control1: CGPoint(x: x - 4, y: y + 6), control2: CGPoint(x: x - dx + 3, y: y + 5))
            path.closeSubpath()
        }
    }
}

// MARK: - Lock

struct LockShackle: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 18)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 4, y: 7))
        path.addLine(to: CGPoint(x: 4, y: 5))
        path.addArc(center: CGPoint(x: 8, y: 5), radius: 4,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: 12, y: 7))
    }
}

struct LockBody: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 18)
    func draw(into path: inout Path) {
        path.addRoundedRect(in: CGRect(x: 1.6, y: 7, width: 12.8, height: 9.4),
                            cornerSize: CGSize(width: 2.4, height: 2.4))
    }
}

struct LockKeyhole: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 18)
    func draw(into path: inout Path) {
        path.addEllipse(in: CGRect(x: 6.5, y: 9.9, width: 3, height: 3))
        path.addRoundedRect(in: CGRect(x: 7.2, y: 11.6, width: 1.6, height: 2.6),
                            cornerSize: CGSize(width: 0.8, height: 0.8))
    }
}

// MARK: - Phone, bell, chat

/// The handset used for Accept, Not now, End and the premium calls row.
struct HandsetGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 6.6, y: 2.2))
        path.addCurve(to: CGPoint(x: 9.4, y: 2.7),
                      control1: CGPoint(x: 7.5, y: 1.6), control2: CGPoint(x: 8.7, y: 1.8))
        path.addLine(to: CGPoint(x: 11.4, y: 5.3))
        path.addCurve(to: CGPoint(x: 11.2, y: 7.9),
                      control1: CGPoint(x: 12, y: 6.1), control2: CGPoint(x: 11.9, y: 7.2))
        path.addLine(to: CGPoint(x: 10.2, y: 8.9))
        path.addCurve(to: CGPoint(x: 10, y: 10.1),
                      control1: CGPoint(x: 9.9, y: 9.2), control2: CGPoint(x: 9.8, y: 9.7))
        path.addCurve(to: CGPoint(x: 16, y: 16.1),
                      control1: CGPoint(x: 11.2, y: 12.7), control2: CGPoint(x: 13.4, y: 14.9))
        path.addCurve(to: CGPoint(x: 17.2, y: 15.9),
                      control1: CGPoint(x: 16.4, y: 16.3), control2: CGPoint(x: 16.9, y: 16.2))
        path.addLine(to: CGPoint(x: 18.2, y: 14.9))
        path.addCurve(to: CGPoint(x: 20.8, y: 14.7),
                      control1: CGPoint(x: 18.9, y: 14.2), control2: CGPoint(x: 20, y: 14.1))
        path.addLine(to: CGPoint(x: 23.4, y: 16.7))
        path.addCurve(to: CGPoint(x: 23.9, y: 19.5),
                      control1: CGPoint(x: 24.3, y: 17.4), control2: CGPoint(x: 24.5, y: 18.6))
        path.addCurve(to: CGPoint(x: 15.9, y: 21.1),
                      control1: CGPoint(x: 21.9, y: 22.5), control2: CGPoint(x: 18.9, y: 22.5))
        path.addCurve(to: CGPoint(x: 5, y: 10.2),
                      control1: CGPoint(x: 11.2, y: 18.6), control2: CGPoint(x: 7.4, y: 14.8))
        path.addCurve(to: CGPoint(x: 6.6, y: 2.2),
                      control1: CGPoint(x: 3.6, y: 7.2), control2: CGPoint(x: 3.6, y: 4.2))
        path.closeSubpath()
    }
}

struct BellBody: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 12, y: 2))
        path.addCurve(to: CGPoint(x: 6, y: 8),
                      control1: CGPoint(x: 8.7, y: 2), control2: CGPoint(x: 6, y: 4.7))
        path.addCurve(to: CGPoint(x: 3.5, y: 14.5),
                      control1: CGPoint(x: 6, y: 12), control2: CGPoint(x: 4.5, y: 13.5))
        path.addLine(to: CGPoint(x: 20.5, y: 14.5))
        path.addCurve(to: CGPoint(x: 18, y: 8),
                      control1: CGPoint(x: 19.5, y: 13.5), control2: CGPoint(x: 18, y: 12))
        path.addCurve(to: CGPoint(x: 12, y: 2),
                      control1: CGPoint(x: 18, y: 4.7), control2: CGPoint(x: 15.3, y: 2))
        path.closeSubpath()
    }
}

struct ChatBubbleGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 12, y: 4))
        path.addCurve(to: CGPoint(x: 20.5, y: 10.8),
                      control1: CGPoint(x: 16.7, y: 4), control2: CGPoint(x: 20.5, y: 7))
        path.addCurve(to: CGPoint(x: 12, y: 17.5),
                      control1: CGPoint(x: 20.5, y: 14.5), control2: CGPoint(x: 16.7, y: 17.5))
        path.addCurve(to: CGPoint(x: 9.4, y: 17.2),
                      control1: CGPoint(x: 11.1, y: 17.5), control2: CGPoint(x: 10.2, y: 17.4))
        path.addLine(to: CGPoint(x: 5, y: 19))
        path.addLine(to: CGPoint(x: 6, y: 15.9))
        path.addCurve(to: CGPoint(x: 3.5, y: 11.1),
                      control1: CGPoint(x: 4.4, y: 14.7), control2: CGPoint(x: 3.5, y: 13))
        path.addCurve(to: CGPoint(x: 12, y: 4),
                      control1: CGPoint(x: 3.5, y: 7), control2: CGPoint(x: 7.3, y: 4))
        path.closeSubpath()
    }
}

struct SendGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 20, height: 18)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 1, y: 1))
        path.addLine(to: CGPoint(x: 19, y: 9))
        path.addLine(to: CGPoint(x: 1, y: 17))
        path.addLine(to: CGPoint(x: 5, y: 9))
        path.closeSubpath()
    }
}

// MARK: - Playback and media

struct PlayTriangle: VectorGlyph {
    static let viewBox = CGSize(width: 28, height: 32)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 5, y: 3))
        path.addLine(to: CGPoint(x: 24, y: 16))
        path.addLine(to: CGPoint(x: 5, y: 29))
        path.closeSubpath()
    }
}

struct PauseBars: VectorGlyph {
    static let viewBox = CGSize(width: 30, height: 32)
    func draw(into path: inout Path) {
        path.addRoundedRect(in: CGRect(x: 4, y: 3, width: 8, height: 26), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: 18, y: 3, width: 8, height: 26), cornerSize: CGSize(width: 2, height: 2))
    }
}

/// `M12 5V2L7 5.5 12 9V6a6.5 6.5 0 1 1-6.4 7.8` — skip back fifteen seconds.
struct ReplayGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 12, y: 5))
        path.addLine(to: CGPoint(x: 12, y: 2))
        path.addLine(to: CGPoint(x: 7, y: 5.5))
        path.addLine(to: CGPoint(x: 12, y: 9))
        path.addLine(to: CGPoint(x: 12, y: 6))
        path.addArc(center: CGPoint(x: 12, y: 12.5), radius: 6.5,
                    startAngle: .degrees(-90), endAngle: .degrees(115), clockwise: false)
    }
}

struct ShareGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 14, height: 15)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 7, y: 10))
        path.addLine(to: CGPoint(x: 7, y: 1))
        path.move(to: CGPoint(x: 3.5, y: 4.5))
        path.addLine(to: CGPoint(x: 7, y: 1))
        path.addLine(to: CGPoint(x: 10.5, y: 4.5))
        path.move(to: CGPoint(x: 1.5, y: 9))
        path.addLine(to: CGPoint(x: 1.5, y: 13.5))
        path.addLine(to: CGPoint(x: 12.5, y: 13.5))
        path.addLine(to: CGPoint(x: 12.5, y: 9))
    }
}

struct TrashGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 14, height: 16)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 2, y: 4))
        path.addLine(to: CGPoint(x: 12, y: 4))
        path.move(to: CGPoint(x: 5.5, y: 4))
        path.addLine(to: CGPoint(x: 5.5, y: 2.5))
        path.addLine(to: CGPoint(x: 8.5, y: 2.5))
        path.addLine(to: CGPoint(x: 8.5, y: 4))
        path.move(to: CGPoint(x: 3, y: 4))
        path.addLine(to: CGPoint(x: 3.7, y: 13.5))
        path.addLine(to: CGPoint(x: 10.3, y: 13.5))
        path.addLine(to: CGPoint(x: 11, y: 4))
    }
}

struct SummaryLinesGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 16)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 2.5, y: 4)); path.addLine(to: CGPoint(x: 13.5, y: 4))
        path.move(to: CGPoint(x: 2.5, y: 8)); path.addLine(to: CGPoint(x: 13.5, y: 8))
        path.move(to: CGPoint(x: 2.5, y: 12)); path.addLine(to: CGPoint(x: 9.5, y: 12))
    }
}

struct SpeakerCone: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 4, y: 9))
        path.addLine(to: CGPoint(x: 7.5, y: 9))
        path.addLine(to: CGPoint(x: 12, y: 5))
        path.addLine(to: CGPoint(x: 12, y: 19))
        path.addLine(to: CGPoint(x: 7.5, y: 15))
        path.addLine(to: CGPoint(x: 4, y: 15))
        path.closeSubpath()
    }
}

struct SpeakerWaves: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addArc(center: CGPoint(x: 15.5, y: 12), radius: 4,
                    startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
        path.addArc(center: CGPoint(x: 18, y: 12), radius: 7.5,
                    startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
    }
}

struct VideoCameraGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addRoundedRect(in: CGRect(x: 2.5, y: 6.5, width: 13, height: 11),
                            cornerSize: CGSize(width: 2.5, height: 2.5))
        path.move(to: CGPoint(x: 16.5, y: 11))
        path.addLine(to: CGPoint(x: 21.5, y: 8))
        path.addLine(to: CGPoint(x: 21.5, y: 16))
        path.addLine(to: CGPoint(x: 16.5, y: 13))
        path.closeSubpath()
    }
}

/// The diagonal that turns an icon into its "off" state.
struct SlashGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: 21, y: 21))
    }
}

// MARK: - Small utility marks

struct CheckGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 26, height: 20)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 2, y: 10))
        path.addLine(to: CGPoint(x: 9.5, y: 17.5))
        path.addLine(to: CGPoint(x: 24, y: 3))
    }
}

struct CloseGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 16)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 2, y: 2)); path.addLine(to: CGPoint(x: 14, y: 14))
        path.move(to: CGPoint(x: 14, y: 2)); path.addLine(to: CGPoint(x: 2, y: 14))
    }
}

struct PlusGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 16, height: 16)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 8, y: 2)); path.addLine(to: CGPoint(x: 8, y: 14))
        path.move(to: CGPoint(x: 2, y: 8)); path.addLine(to: CGPoint(x: 14, y: 8))
    }
}

struct ArrowRightGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 13, height: 12)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 1, y: 6)); path.addLine(to: CGPoint(x: 11, y: 6))
        path.move(to: CGPoint(x: 7, y: 2))
        path.addLine(to: CGPoint(x: 11, y: 6))
        path.addLine(to: CGPoint(x: 7, y: 10))
    }
}

struct ChevronDownGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 12, height: 7)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 1, y: 1))
        path.addLine(to: CGPoint(x: 6, y: 6))
        path.addLine(to: CGPoint(x: 11, y: 1))
    }
}

/// The alarm clock on the When row.
struct AlarmGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addEllipse(in: CGRect(x: 4, y: 5, width: 16, height: 16))
    }
}

struct AlarmHands: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 12, y: 9))
        path.addLine(to: CGPoint(x: 12, y: 13))
        path.addLine(to: CGPoint(x: 14.6, y: 15))
    }
}

struct AlarmCrown: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 9, y: 2)); path.addLine(to: CGPoint(x: 15, y: 2))
    }
}

/// The plain clock on Remind Me.
struct ClockGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
        path.move(to: CGPoint(x: 12, y: 7))
        path.addLine(to: CGPoint(x: 12, y: 12.4))
        path.addLine(to: CGPoint(x: 15.4, y: 14.4))
    }
}

// MARK: - Safety page

struct ShieldOutline: VectorGlyph {
    static let viewBox = CGSize(width: 72, height: 82)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 36, y: 3))
        path.addLine(to: CGPoint(x: 66, y: 14))
        path.addLine(to: CGPoint(x: 66, y: 38))
        path.addCurve(to: CGPoint(x: 36, y: 78),
                      control1: CGPoint(x: 66, y: 56), control2: CGPoint(x: 53.4, y: 69.6))
        path.addCurve(to: CGPoint(x: 6, y: 38),
                      control1: CGPoint(x: 18.6, y: 69.6), control2: CGPoint(x: 6, y: 56))
        path.addLine(to: CGPoint(x: 6, y: 14))
        path.closeSubpath()
    }
}

struct ShieldHeart: VectorGlyph {
    static let viewBox = CGSize(width: 72, height: 82)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 36, y: 28))
        path.addCurve(to: CGPoint(x: 23, y: 28.8),
                      control1: CGPoint(x: 33.4, y: 22.4), control2: CGPoint(x: 25, y: 22.6))
        path.addCurve(to: CGPoint(x: 36, y: 45.2),
                      control1: CGPoint(x: 21.4, y: 33.8), control2: CGPoint(x: 27.6, y: 39.4))
        path.addCurve(to: CGPoint(x: 49, y: 28.8),
                      control1: CGPoint(x: 44.4, y: 39.4), control2: CGPoint(x: 50.6, y: 33.8))
        path.addCurve(to: CGPoint(x: 36, y: 28),
                      control1: CGPoint(x: 47, y: 22.6), control2: CGPoint(x: 38.6, y: 22.4))
        path.closeSubpath()
    }
}

struct EyeOutline: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 2.5, y: 12))
        path.addCurve(to: CGPoint(x: 12, y: 6),
                      control1: CGPoint(x: 4.5, y: 8.5), control2: CGPoint(x: 7.5, y: 6))
        path.addCurve(to: CGPoint(x: 21.5, y: 12),
                      control1: CGPoint(x: 16.5, y: 6), control2: CGPoint(x: 19.5, y: 8.5))
        path.addCurve(to: CGPoint(x: 12, y: 18),
                      control1: CGPoint(x: 19.5, y: 15.5), control2: CGPoint(x: 16.5, y: 18))
        path.addCurve(to: CGPoint(x: 2.5, y: 12),
                      control1: CGPoint(x: 7.5, y: 18), control2: CGPoint(x: 4.5, y: 15.5))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: 9.4, y: 9.4, width: 5.2, height: 5.2))
    }
}

struct PersonSearchGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 24, height: 24)
    func draw(into path: inout Path) {
        path.addEllipse(in: CGRect(x: 6.4, y: 4.4, width: 7.2, height: 7.2))
        path.move(to: CGPoint(x: 3.5, y: 20))
        path.addCurve(to: CGPoint(x: 13.5, y: 14.9),
                      control1: CGPoint(x: 3.5, y: 16.4), control2: CGPoint(x: 8.7, y: 14))
        path.addEllipse(in: CGRect(x: 13.5, y: 13.5, width: 8, height: 8))
        path.move(to: CGPoint(x: 14.9, y: 20.1))
        path.addLine(to: CGPoint(x: 20.1, y: 14.9))
    }
}

struct PeopleGlyph: VectorGlyph {
    static let viewBox = CGSize(width: 18, height: 18)
    func draw(into path: inout Path) {
        path.move(to: CGPoint(x: 1.6, y: 15.4))
        path.addCurve(to: CGPoint(x: 11.2, y: 15.4),
                      control1: CGPoint(x: 2, y: 12.8), control2: CGPoint(x: 8.9, y: 11.3))
        path.move(to: CGPoint(x: 12, y: 11.5))
        path.addCurve(to: CGPoint(x: 16.1, y: 15.4),
                      control1: CGPoint(x: 14.2, y: 11.6), control2: CGPoint(x: 15.7, y: 13))
    }
}
