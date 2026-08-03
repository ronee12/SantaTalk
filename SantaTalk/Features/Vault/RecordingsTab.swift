import SantaCallSummary
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
                isExpanded: state.expandedRecordingID == recording.id,
                summaryPhase: state.summaryPhase[recording.id],
                onOpen: { state.openPlayer(for: recording) },
                onToggleSummary: { state.toggleSummary(for: recording) },
                onCreateSummary: { state.requestSummary(for: recording) },
                onShare: { state.openShare(for: recording) },
                onDelete: { state.deleteRecording(recording) }
            )
        }
    }

    /// The old copy here promised that nothing is uploaded. Summaries make that
    /// untrue, and a privacy promise that is *nearly* kept is worse than one
    /// that states its exception.
    private var footnote: some View {
        Text("Recordings stay on this phone, and turning recording off in Settings stops new ones. Asking for a summary is the exception — that call's audio is sent away to be listened to.")
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

            Text("When Santa calls, the whole conversation is saved here — his voice, your child's, and their face if the camera is on. It stays on this phone unless you ask for a summary.")
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
    let isExpanded: Bool
    let summaryPhase: AppState.SummaryPhase?
    let onOpen: () -> Void
    let onToggleSummary: () -> Void
    let onCreateSummary: () -> Void
    let onShare: () -> Void
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
                SummaryPanel(
                    childName: recording.childName,
                    summary: recording.summary,
                    phase: summaryPhase,
                    onCreate: onCreateSummary
                )
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
                // Opens the trim screen rather than sharing the file. What is on
                // disk is the child's face and both voices with none of the call
                // around it — see `ShareComposition`.
                CardAction(title: "Share", action: onShare) {
                    ShareGlyph()
                        .stroke(Palette.snow,
                                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                        .frame(width: 15, height: 16)
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

/// What sits under an expanded card.
///
/// Five things can be true here, and each of them is a different sentence: the
/// parent has never asked, the model is listening, it failed, it found nothing,
/// or it found something. Only the last one draws lists.
private struct SummaryPanel: View {
    let childName: String
    let summary: CallSummary?
    let phase: AppState.SummaryPhase?
    let onCreate: () -> Void

    var body: some View {
        // Section spacing, not paragraph spacing — the three lists are the usual
        // case and they need air between them to stay scannable.
        VStack(alignment: .leading, spacing: Metrics.Space.l) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, Metrics.Space.m)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.glassSunk)
        }
    }

    @ViewBuilder
    private var content: some View {
        // A phase in flight outranks what is on disk: a parent who just tapped
        // Try again should see the spinner, not the summary they are replacing.
        if let phase {
            switch phase {
            case .working: working
            case .failed(let error): failure(error)
            }
        } else if let summary {
            if summary.isEmpty {
                note("Nothing to note from this call.")
            } else {
                lists(summary)
            }
        } else {
            invitation
        }
    }

    // MARK: Before anything has been asked for

    /// Says what the button does *and* what it costs, on the same screen as the
    /// button. A parent should not have to find the footnote to learn that
    /// tapping this sends the call away.
    private var invitation: some View {
        VStack(alignment: .leading, spacing: Metrics.Space.s) {
            note("See what \(name) asked for, what they promised, and anything else worth knowing.")

            Text("This sends the call's audio away to be listened to. Only the summary comes back.")
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.faint)
                .lineHeight(1.5, size: 13)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            action("Create summary")
        }
    }

    // MARK: While it is happening, and when it did not

    private var working: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Palette.firelight)

            Text("Listening to the call…")
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Palette.secondary)
        }
        .frame(minHeight: Metrics.parentTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func failure(_ error: CallSummaryError) -> some View {
        VStack(alignment: .leading, spacing: Metrics.Space.s) {
            note(error.message)
            // Not offered for the two failures that will fail again the same
            // way — a missing file and a silent one do not improve on a retry.
            if error != .recordingMissing, error != .noSound {
                action("Try again")
            }
        }
    }

    // MARK: What came back

    @ViewBuilder
    private func lists(_ summary: CallSummary) -> some View {
        if !summary.wishes.isEmpty {
            SummaryList(title: "WISHES", items: summary.wishes)
        }
        if !summary.promises.isEmpty {
            SummaryList(title: "PROMISES", items: summary.promises)
        }
        if !summary.notable.isEmpty {
            SummaryList(title: "WORTH KNOWING", items: summary.notable)
        }
    }

    // MARK: Pieces

    private var name: String {
        let trimmed = childName.trimmed
        return trimmed.isEmpty ? "your child" : trimmed
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typeface.rounded(15, .regular))
            .foregroundStyle(Palette.secondary)
            .lineHeight(1.55, size: 15)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ title: String) -> some View {
        Button(action: onCreate) {
            Text(title)
                .font(Typeface.rounded(15, .semibold))
                .foregroundStyle(Palette.firelight)
                .frame(minHeight: Metrics.parentTarget, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// One heading and its entries. The view draws the bullets, which is why
/// `CallSummaryDecoder` takes any the model sent back off again.
private struct SummaryList: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .sectionCaptionStyle()

            // `id: \.self` is safe because the decoder deduplicates entries.
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle()
                        .fill(Palette.dim)
                        .frame(width: 4, height: 4)
                        .alignmentGuide(.firstTextBaseline) { _ in 6 }

                    Text(item)
                        .font(Typeface.rounded(15, .regular))
                        .foregroundStyle(Palette.snow)
                        .lineHeight(1.45, size: 15)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
