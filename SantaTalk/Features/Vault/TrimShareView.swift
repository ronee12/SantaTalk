import SwiftUI

/// Choose a piece of a call, watch exactly what will be sent, send it.
///
/// The preview is not a mock-up of the export — it is the export's own
/// composition running in an `AVPlayer`. What a parent watches here is made by
/// the code that makes the file, so the two cannot disagree.
struct TrimShareView: View {
    @Environment(AppState.self) private var state

    let recording: CallRecording

    @State private var model = TrimShareModel()

    var body: some View {
        VStack(spacing: 0) {
            navBar
            preview
            timeline
            Spacer(minLength: Metrics.Space.m)
            footer
        }
        .background(Palette.nightDeep.ignoresSafeArea())
        .task {
            guard let url = state.recordingURL(for: recording) else { return }
            await model.prepare(
                url: url,
                childName: recording.childName.isEmpty ? state.childName : recording.childName,
                showsWordmark: !state.isPro
            )
        }
        .onDisappear { model.teardown() }
        .sheet(item: $model.exported) { ShareSheet(url: $0.url) }
    }

    // MARK: Nav

    private var navBar: some View {
        ZStack {
            Text("Trim & Share")
                .font(Typeface.rounded(17, .semibold))
                .foregroundStyle(Palette.snow)

            HStack {
                NavTextButton(title: "Cancel", action: state.closeShare)
                Spacer()
            }
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.Space.s)
        .padding(.bottom, Metrics.Space.s)
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.stage)

            if model.phase == .preparing {
                VStack(spacing: Metrics.Space.m) {
                    ProgressView().tint(Palette.firelight)
                    Text("Putting the call back together…")
                        .font(Typeface.rounded(14, .regular))
                        .foregroundStyle(Palette.dim)
                }
            } else {
                VideoLayerView(player: model.player)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .aspectRatio(
            ExportGeometry.pixelSize.width / ExportGeometry.pixelSize.height,
            contentMode: .fit
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 1)
        }
        .overlay { playControl }
        .contentShape(.rect)
        .onTapGesture { model.togglePlayback() }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var playControl: some View {
        if model.phase != .preparing, !model.isPlaying {
            Circle()
                .fill(Color(hex: 0x070C1E, opacity: 0.5))
                .frame(width: 68, height: 68)
                .overlay {
                    PlayTriangle()
                        .fill(Palette.snow)
                        .frame(width: 24, height: 26)
                        .offset(x: 2)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Timeline

    private var timeline: some View {
        VStack(spacing: Metrics.Space.s) {
            HStack {
                Text(stamp(model.start))
                Spacer()
                Text("\(stamp(model.selectedLength)) selected")
                    .foregroundStyle(Palette.snow)
                Spacer()
                Text(stamp(model.end))
            }
            .font(Typeface.rounded(13, .regular))
            .monospacedDigit()
            .foregroundStyle(Palette.dim)

            TrimStrip(
                thumbnails: model.thumbnails,
                waveform: model.waveform,
                duration: model.duration,
                start: model.start,
                end: model.end,
                position: model.position,
                onStartChanged: model.setStart,
                onEndChanged: model.setEnd,
                onScrub: model.scrub
            )

            HStack {
                Text(model.hasCamera
                     ? "Pinch to zoom, drag the handles to trim."
                     : "The camera was off, so the reaction tile shows a placeholder.")
                    .font(Typeface.rounded(12, .regular))
                    .foregroundStyle(Palette.faint)

                Spacer()

                if !model.isWholeCall {
                    Button("Whole call", action: model.resetSelection)
                        .font(Typeface.rounded(12, .regular))
                        .foregroundStyle(Palette.firelight)
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Metrics.Space.s) {
            switch model.phase {
            case .preparing:
                AmberButton(title: "Export & Share", isEnabled: false, action: {})

            case .ready:
                AmberButton(title: "Export & Share") {
                    Task {
                        await model.export(
                            title: recording.title, dateLabel: recording.dateLabel
                        )
                    }
                }
                if !state.isPro { wordmarkNote }

            case .exporting(let fraction):
                progressBar(fraction)
                AmberLink(title: "Cancel", color: Palette.dim, fontSize: 15) {
                    model.cancelExport()
                }

            case .failed(let message):
                Text(message)
                    .font(Typeface.rounded(14, .regular))
                    .foregroundStyle(Palette.destructive)
                    .multilineTextAlignment(.center)
                AmberButton(title: "Try again") {
                    model.dismissFailure()
                    Task {
                        await model.export(
                            title: recording.title, dateLabel: recording.dateLabel
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, Metrics.Space.l)
        .padding(.bottom, Metrics.bottom)
    }

    private func progressBar(_ fraction: Double) -> some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.glass)
                    Capsule()
                        .fill(Gradients.amberTrack)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 6)

            Text("Preparing your video — \(Int(fraction * 100))%")
                .font(Typeface.rounded(14, .regular))
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
        }
        .frame(height: 52)
    }

    /// Honest about the mark before it appears in someone's video, and the only
    /// place in the app where removing it is worth mentioning.
    private var wordmarkNote: some View {
        HStack(spacing: 5) {
            Text("Shared videos carry a small SantaTalk mark.")
                .font(Typeface.rounded(12, .regular))
                .foregroundStyle(Palette.faint)

            Button("Remove it") {
                state.closeShare()
                state.openPaywall()
            }
            .font(Typeface.rounded(12, .regular))
            .foregroundStyle(Palette.firelight)
            .buttonStyle(.plain)
        }
    }

    /// Tenths, because a second is a long time when the clip is eight of them.
    private func stamp(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        let minutes = Int(safe) / 60
        let remainder = safe - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, remainder)
    }
}
