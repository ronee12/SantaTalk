import SwiftUI

/// One recording, two faces. Santa and the child were never two files — they are one moment,
/// so the layout is identical to the live call and replay reads as the same event.
struct PlayerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            navBar
            titleBlock
            stage
            controls
        }
        .background(Palette.nightDeep.ignoresSafeArea())
    }

    // MARK: Nav

    private var navBar: some View {
        HStack(spacing: 0) {
            BackLabelButton(title: "Recordings", action: state.closePlayer)
                .accessibilityLabel("Back to recordings")

            Spacer()

            NavTextButton(title: "Delete", color: Palette.destructive,
                          action: state.deleteCurrentRecording)
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.Space.s)
        .padding(.bottom, Metrics.Space.s)
    }

    private var titleBlock: some View {
        VStack(spacing: 0) {
            Text(state.currentRecording?.title ?? "")
                .font(Typeface.rounded(26, .bold))
                .tracking(-0.4)
                .foregroundStyle(Palette.cream)

            Text(state.currentRecording?.meta ?? "")
                .font(Typeface.rounded(14, .regular))
                .monospacedDigit()
                .foregroundStyle(Palette.dim)
                .padding(.top, 5)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 6)
    }

    // MARK: Stage

    private var stage: some View {
        VStack(spacing: 0) {
            ZStack {
                Palette.stage

                Image("SantaPortrait")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(state.isPlaying ? 1 : 0.55)
                    .animation(.easeInOut(duration: 0.3), value: state.isPlaying)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            }
            .overlay(alignment: .bottomLeading) {
                TileNameBadge(name: "Santa", fontSize: 12)
                    .padding(Metrics.Space.m)
            }
            .overlay(alignment: .topTrailing) {
                reactionTile.padding(14)
            }

            scrubber.padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    /// Same frame whether reactions were on or off — the recording is still worth keeping.
    private var reactionTile: some View {
        ImageSlot(
            label: state.currentRecording?.hasReaction == true ? "Reaction" : "Reactions off",
            cornerRadius: Metrics.Radius.tile
        )
        .frame(width: 88, height: 132)
        .overlay(alignment: .bottomLeading) {
            TileNameBadge(name: state.childName, fontSize: 10)
                .padding(7)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                .stroke(Color(hex: 0xEDF2FF, opacity: 0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 13, y: 10)
    }

    private var scrubber: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 5)
                    Capsule()
                        .fill(Gradients.amberTrack)
                        .frame(width: proxy.size.width * state.playbackFraction, height: 5)
                }
                .frame(height: 22)
                .contentShape(.rect)
                .onTapGesture { location in
                    state.seek(toFraction: location.x / proxy.size.width)
                }
            }
            .frame(height: 22)
            .accessibilityLabel("Scrub the recording")

            HStack {
                Text(Format.duration(state.playPosition))
                Spacer()
                Text(state.playbackRemaining)
            }
            .font(Typeface.rounded(13, .regular))
            .monospacedDigit()
            .foregroundStyle(Palette.dim)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 26) {
            GlassCircleButton(size: 56, accessibilityLabel: "Back fifteen seconds",
                              action: state.skipBackFifteen) {
                ReplayGlyph()
                    .stroke(Palette.snow,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 24, height: 24)
            }

            Button(action: state.togglePlayback) {
                Circle()
                    .fill(Palette.firelight)
                    .frame(width: Metrics.childTarget, height: Metrics.childTarget)
                    .shadow(color: Palette.firelight.opacity(0.32), radius: 17, y: 14)
                    .overlay {
                        if state.isPlaying {
                            PauseBars().fill(Palette.onAmber).frame(width: 30, height: 32)
                        } else {
                            PlayTriangle().fill(Palette.onAmber).frame(width: 30, height: 32)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")

            GlassCircleButton(size: 56, accessibilityLabel: "Share this recording", action: {}) {
                ShareGlyph()
                    .stroke(Palette.snow,
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 21, height: 22)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, Metrics.bottom)
    }
}

/// A translucent circular button, used either side of the play control.
struct GlassCircleButton<Icon: View>: View {
    let size: CGFloat
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: 0xEDF2FF, opacity: 0.1))
                .frame(width: size, height: size)
                .overlay { icon }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
