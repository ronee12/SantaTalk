import SwiftUI

/// The two-tone microphone on the permission step.
struct MicrophoneIcon: View {
    var width: CGFloat = 34
    var height: CGFloat = 48

    var body: some View {
        ZStack {
            MicCapsule().fill(Palette.firelight)
            MicCradle().stroke(Palette.firelightSoft,
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: width, height: height)
    }
}

/// The solid microphone used in call controls and on the topic row.
struct MicrophoneSolidIcon: View {
    var size: CGFloat = 28
    var capsuleColor: Color = Palette.snow
    var cradleColor: Color = Palette.snow

    var body: some View {
        ZStack {
            MicSolidCapsule().fill(capsuleColor)
            MicSolidCradle().stroke(cradleColor,
                                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The amber padlock on the vault entrance and the grown-ups-only gate.
struct LockIcon: View {
    var width: CGFloat = 17
    var height: CGFloat = 19

    var body: some View {
        ZStack {
            LockShackle().stroke(Palette.firelight,
                                 style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            LockBody().fill(Palette.firelight)
            LockKeyhole().fill(Palette.onAmber)
        }
        .frame(width: width, height: height)
    }
}

/// The handset. Rotated 135° it becomes the decline and end-call mark.
struct HandsetIcon: View {
    var size: CGFloat = 36
    var color: Color = .white
    var isHungUp: Bool = false

    var body: some View {
        HandsetGlyph()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isHungUp ? 135 : 0))
    }
}

/// The bell used on the ringtone rows and the notification sheet.
struct BellIcon: View {
    var size: CGFloat = 18
    var color: Color = Palette.firelight
    var clapperColor: Color?

    var body: some View {
        ZStack {
            BellBody().fill(color)
            Circle()
                .fill(clapperColor ?? color)
                .frame(width: size * 0.19, height: size * 0.19)
                .offset(y: size * 0.30)
        }
        .frame(width: size, height: size)
    }
}

/// The circle-in-a-circle badge next to a recording's reaction state.
struct RingBadgeIcon: View {
    var color: Color
    var size: CGFloat = 11

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.4)
            .frame(width: size * 0.84, height: size * 0.84)
            .frame(width: size, height: size)
    }
}

/// A camera with an optional strike-through, for Hide me and the safety page.
struct VideoIcon: View {
    var size: CGFloat = 28
    var color: Color = Palette.snow
    var isOff: Bool = true
    var lineWidth: CGFloat = 1.8

    var body: some View {
        ZStack {
            VideoCameraGlyph().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
            if isOff {
                SlashGlyph().stroke(color, style: StrokeStyle(lineWidth: lineWidth + 0.1, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// The speaker on the in-call control row.
struct SpeakerIcon: View {
    var size: CGFloat = 28
    var color: Color = Palette.stage

    var body: some View {
        ZStack {
            SpeakerCone().fill(color)
            SpeakerWaves().stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The alarm clock on the When row.
struct AlarmIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            AlarmGlyph().stroke(Palette.firelight, lineWidth: 2)
            AlarmHands().stroke(Palette.firelightSoft,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
            AlarmCrown().stroke(Palette.firelight,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The shield with a heart, the hero of the safety page.
struct SafetyShieldIcon: View {
    var width: CGFloat = 84
    var height: CGFloat = 94

    var body: some View {
        ZStack {
            ShieldOutline().stroke(Palette.santaBright,
                                   style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))
            ShieldHeart().stroke(Palette.santaBright,
                                 style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }
}

/// A five-star row with the last star half filled — the paywall's ratings line.
struct RatingStars: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { _ in
                StarGlyph().fill(Palette.firelightSoft).frame(width: 19, height: 19)
            }
            ZStack {
                HalfStarGlyph().fill(Palette.firelightSoft)
                StarGlyph().stroke(Palette.firelightSoft, lineWidth: 1.2)
            }
            .frame(width: 19, height: 19)
        }
        .accessibilityElement()
        .accessibilityLabel("Rated four and a half stars")
    }
}

/// The curved holly branch that flanks "Loved by Santa".
struct HollyBranch: View {
    var mirrored: Bool = false

    var body: some View {
        ZStack {
            HollyBranchGlyph().stroke(Color(hex: 0xFFF6E6, opacity: 0.85),
                                      style: StrokeStyle(lineWidth: 2, lineCap: .round))
            HollyLeavesGlyph().fill(Color(hex: 0xFFF6E6, opacity: 0.8))
        }
        .frame(width: 26, height: 52)
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .accessibilityHidden(true)
    }
}
