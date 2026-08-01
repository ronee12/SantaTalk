import SwiftUI

/// A quiet list — title, date, time, length. The summary is a button, not a wall of text, and
/// tapping the row opens the full player.
struct RecordingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: Metrics.Space.m) {
            if state.recordings.isEmpty {
                emptyState
            } else {
                header
                list
                footnote
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(state.recordingCountLabel)
                .sectionCaptionStyle()
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {}) {
                Text("Edit")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.firelight)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.Space.xs)
    }

    private var list: some View {
        ForEach(state.recordings) { recording in
            RecordingCard(
                recording: recording,
                shareURL: state.recordingURL(for: recording),
                isExpanded: state.expandedRecordingID == recording.id,
                onOpen: { state.openPlayer(for: recording) },
                onToggleSummary: { state.toggleSummary(for: recording) },
                onDelete: { state.deleteRecording(recording) }
            )
        }
    }

    private var footnote: some View {
        Text("Recordings stay on this phone. Nothing is uploaded, and turning recording off in Settings stops new ones.")
            .font(Typeface.rounded(13, .regular))
            .foregroundStyle(Palette.faint)
            .lineHeight(1.5, size: 13)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.Space.xs)
            .padding(.top, Metrics.Space.xs)
    }

    /// Before the first call. The promise about staying on the phone is made
    /// here instead of in the footnote, so it is never printed twice on one
    /// screen.
    private var emptyState: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Palette.glass)
                .frame(width: 96, height: 96)
                .overlay {
                    AvatarSilhouette()
                        .fill(Color(hex: 0xEDF2FF, opacity: 0.26))
                        .frame(width: 46, height: 46)
                }

            Text("No recordings yet")
                .font(Typeface.rounded(20, .semibold))
                .foregroundStyle(Palette.snow)
                .padding(.top, Metrics.Space.l)

            Text("When Santa calls, the whole conversation is saved here — his voice, your child's, and their face if the camera is on. Nothing leaves this phone.")
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Palette.secondary)
                .lineHeight(1.55, size: 15)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metrics.Space.s)
                .padding(.horizontal, Metrics.Space.m)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, Metrics.listGutter)
        .background(Palette.glassSunk)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous))
    }
}

private struct RecordingCard: View {
    let recording: CallRecording
    let shareURL: URL?
    let isExpanded: Bool
    let onOpen: () -> Void
    let onToggleSummary: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Palette.firelight)
                        .frame(width: 48, height: 48)
                        .overlay {
                            PlayTriangle()
                                .fill(Palette.onAmber)
                                .frame(width: 15, height: 17)
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(recording.title)
                            .font(Typeface.rounded(17, .semibold))
                            .foregroundStyle(Palette.snow)
                            .lineLimit(1)

                        Text(recording.meta)
                            .font(Typeface.rounded(13, .regular))
                            .monospacedDigit()
                            .foregroundStyle(Palette.faint)
                            .padding(.top, 3)

                        // State is never colour-only — the badge carries a word too.
                        HStack(spacing: 5) {
                            RingBadgeIcon(color: recording.badgeColor)
                            Text(recording.badge)
                                .font(Typeface.rounded(12, .regular))
                                .foregroundStyle(recording.badgeColor)
                        }
                        .padding(.horizontal, Metrics.Space.s)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(recording.badgeBackground)
                        }
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DisclosureChevron()
                }
                .padding(.horizontal, Metrics.listGutter)
                .padding(.vertical, 14)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(recording.title)")

            if isExpanded {
                Text(recording.summaryText)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.secondary)
                    .lineHeight(1.55, size: 15)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, Metrics.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Palette.glassSunk)
                    }
                    .padding(.horizontal, Metrics.listGutter)
                    .padding(.bottom, 14)
            }

            RowDivider()

            // Share and Delete live here and in the player, nowhere else.
            HStack(spacing: 0) {
                CardAction(title: isExpanded ? "Hide" : "Summary", action: onToggleSummary) {
                    SummaryLinesGlyph()
                        .stroke(Palette.secondary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 15, height: 15)
                }
                verticalRule
                if let shareURL {
                    ShareLink(item: shareURL) {
                        HStack(spacing: 7) {
                            ShareGlyph()
                                .stroke(Palette.snow,
                                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                                .frame(width: 15, height: 16)
                            Text("Share")
                                .font(Typeface.rounded(15, .regular))
                                .foregroundStyle(Palette.snow)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                verticalRule
                CardAction(title: "Delete", tint: Palette.destructive, action: onDelete) {
                    TrashGlyph()
                        .stroke(Palette.destructive,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 16)
                }
            }
        }
        .background(Palette.glassSunk)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous))
    }

    private var verticalRule: some View {
        Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 46)
    }
}

private struct CardAction<Icon: View>: View {
    let title: String
    var tint: Color = Palette.snow
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                icon
                Text(title)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
