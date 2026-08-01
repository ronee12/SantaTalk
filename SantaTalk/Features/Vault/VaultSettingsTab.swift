import StoreKit
import SwiftUI

/// Recording switch, plan, lock, and the safety page.
struct VaultSettingsTab: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 20) {
            scheduledCalls
            recording
            callsAndPlan
            lock
            about
            dangerZone
        }
    }

    // MARK: Scheduled calls

    private var scheduledCalls: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "SCHEDULED CALLS")

            VaultGroup {
                // The rule sits above every row but the first, so the group never
                // ends on a divider with nothing under it.
                ForEach(Array(state.vaultSchedules.enumerated()), id: \.element.id) { index, schedule in
                    if index > 0 { RowDivider() }
                    ScheduleRow(
                        schedule: schedule,
                        tint: tint(forChild: schedule.childName),
                        onChange: { state.changeSchedule(schedule) },
                        onCancel: { state.cancelSchedule(schedule) }
                    )
                }

                if state.schedules.isEmpty {
                    Text("Nothing scheduled. Set a time on the home screen and it will appear here.")
                        .font(Typeface.rounded(15, .regular))
                        .foregroundStyle(Palette.secondary)
                        .lineHeight(1.5, size: 15)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.listGutter)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    private func tint(forChild name: String) -> Color {
        state.children.first { $0.name == name }?.tint ?? Palette.childTint(at: 0)
    }

    // MARK: Recording

    private var recording: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "RECORDING")

            VaultGroup {
                VaultRow(
                    title: "Record calls",
                    detail: "Kept on this phone, never uploaded",
                    showsChevron: false,
                    accessory: {
                        IOSToggle(isOn: state.isRecordingEnabled, accessibilityTitle: "Record calls") {
                            state.isRecordingEnabled.toggle()
                        }
                    }
                )
                RowDivider()
                VaultRow(
                    title: "Keep the reaction video",
                    detail: "A second track of just your child, for the album",
                    showsChevron: false,
                    accessory: {
                        IOSToggle(isOn: state.keepsReactionVideo,
                                  accessibilityTitle: "Keep the reaction video") {
                            state.keepsReactionVideo.toggle()
                        }
                    }
                )
            }
        }
    }

    // MARK: Plan and lock

    private var callsAndPlan: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "CALLS & PLAN")
            VaultGroup {
                VaultRow(
                    title: "Subscription",
                    value: state.isPro ? "Santa Pro" : "Free",
                    action: state.openPaywall
                )
            }
        }
    }

    private var lock: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "LOCK")
            VaultGroup {
                VaultRow(
                    title: "Ask again after",
                    detail: "How long the vault stays open once you leave it",
                    value: state.lockGraceLabel,
                    action: { state.vaultSheet = .lockGrace }
                )
            }
        }
    }

    // MARK: About

    private var about: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "ABOUT")

            VaultGroup {
                VaultRow(
                    title: "Why this app is safe",
                    leading: AnyView(SafetyBadge()),
                    action: state.openSafetyPage
                )
                RowDivider()
                VaultRow(title: "Privacy policy", action: { openURL(SupportLinks.privacyPolicy) })
                RowDivider()
                VaultRow(title: "Contact us", action: { openURL(SupportLinks.contactEmail) })
                RowDivider()
                // Apple caps this at three showings a year and gives no signal
                // when it declines to appear, so there is nothing honest to fall
                // back to — offering an App Store link as well would double-open
                // on the occasions it does work.
                VaultRow(title: "Rate the app", action: { requestReview() })
            }
        }
    }

    /// Deletes the library and nothing else. Children, wishes and settings are
    /// untouched — clearing an album is not the same decision as forgetting a
    /// child, and the two used to share one button.
    private var dangerZone: some View {
        VStack(spacing: Metrics.Space.s) {
            VaultGroup {
                Button(action: { state.isConfirmingRecordingWipe = true }) {
                    Text("Delete all recordings")
                        .font(Typeface.rounded(17, .regular))
                        .foregroundStyle(hasRecordings ? Palette.destructive : Palette.faint)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!hasRecordings)
            }

            Text(hasRecordings
                 ? "Removes every recorded call from this phone, audio and video. Nothing was ever uploaded, so there is nothing to delete anywhere else. This cannot be undone."
                 : "There are no recordings to delete.")
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.secondary)
                .lineHeight(1.5, size: 13)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.Space.xs)
        }
    }

    private var hasRecordings: Bool { !state.recordings.isEmpty }
}

// MARK: - Rows

private struct ScheduleRow: View {
    let schedule: ScheduledCall
    let tint: Color
    let onChange: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Space.m) {
            ChildInitial(name: schedule.childName, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.Space.s) {
                    Text(schedule.whenLabel)
                        .font(Typeface.rounded(17, .regular))
                        .foregroundStyle(schedule.isPending ? Palette.snow : Palette.secondary)

                    // State is never colour-only — a missed call says so.
                    if !schedule.isPending {
                        Text("Missed")
                            .font(Typeface.rounded(12, .semibold))
                            .foregroundStyle(Palette.dim)
                            .padding(.horizontal, Metrics.Space.s)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().fill(Color(hex: 0xEDF2FF, opacity: 0.07))
                            }
                    }
                }

                Text(schedule.detail)
                    .font(Typeface.rounded(14, .regular))
                    .foregroundStyle(Palette.secondary)
                    .lineHeight(1.4, size: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onChange) {
                Text(schedule.isPending ? "Change" : "Rebook")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.firelight)
                    .padding(.horizontal, Metrics.Space.xs)
                    .frame(minHeight: Metrics.parentTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.destructive)
                    .padding(.horizontal, Metrics.Space.xs)
                    .frame(minHeight: Metrics.parentTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.listGutter)
        .padding(.vertical, 14)
    }
}

/// The small red shield that marks the safety page in the About group.
private struct SafetyBadge: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.Space.s, style: .continuous)
            .fill(Color(hex: 0xE8394F, opacity: 0.16))
            .frame(width: 30, height: 30)
            .overlay {
                ZStack {
                    ShieldOutline()
                        .stroke(Palette.santaBright, style: StrokeStyle(lineWidth: 6, lineJoin: .round))
                    CheckGlyph()
                        .stroke(Palette.santaBright,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        .scaleEffect(0.42)
                }
                .frame(width: 17, height: 17)
            }
    }
}
