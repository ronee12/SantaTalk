import SwiftUI

/// Recording switch, ringtone, plan, lock, and the safety page.
struct VaultSettingsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 20) {
            scheduledCalls
            recording
            ringtone
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
                ForEach(state.schedules) { schedule in
                    ScheduleRow(
                        schedule: schedule,
                        tint: tint(forChild: schedule.childName),
                        onChange: state.changeSchedule,
                        onCancel: { state.cancelSchedule(schedule) }
                    )
                    RowDivider()
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
                } else {
                    VaultRow(
                        title: "Remind me five minutes before",
                        detail: "So the phone is in the right hands",
                        showsChevron: false,
                        accessory: {
                            IOSToggle(isOn: state.remindsBeforeCall,
                                      accessibilityTitle: "Remind me five minutes before") {
                                state.remindsBeforeCall.toggle()
                            }
                        }
                    )
                }
            }
        }
    }

    private func tint(forChild name: String) -> Color {
        state.children.first { $0.name == name }?.tint ?? Palette.tintGirl
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

    // MARK: Ringtone

    private var ringtone: some View {
        VStack(spacing: 0) {
            VaultSectionCaption(text: "RINGTONE")

            VaultGroup {
                ForEach(Catalog.ringtones) { tone in
                    let isSelected = state.ringtoneID == tone.id
                    VaultRow(
                        title: tone.name,
                        detail: tone.detail,
                        showsChevron: false,
                        leading: AnyView(
                            BellIcon(
                                size: 18,
                                color: isSelected ? Palette.firelight : Color(hex: 0xEDF2FF, opacity: 0.34)
                            )
                        ),
                        action: { state.ringtoneID = tone.id },
                        accessory: {
                            Text("✓")
                                .font(Typeface.rounded(17, .bold))
                                .foregroundStyle(isSelected ? Palette.firelight : .clear)
                        }
                    )
                    RowDivider()
                }

                VaultRow(title: "Vibrate too", value: "On", action: {})
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
                VaultRow(title: "Ask again after", value: "2 minutes", action: {})
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
                VaultRow(title: "Privacy policy", action: {})
                RowDivider()
                VaultRow(title: "Contact us", action: {})
                RowDivider()
                VaultRow(title: "Rate the app", action: {})
            }
        }
    }

    private var dangerZone: some View {
        VStack(spacing: Metrics.Space.s) {
            VaultGroup {
                Button(action: {}) {
                    Text("Delete everything Santa knows")
                        .font(Typeface.rounded(17, .regular))
                        .foregroundStyle(Palette.destructive)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Text("Deleting removes recordings, wishes and every profile from this device and the server within 24 hours.")
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.secondary)
                .lineHeight(1.5, size: 13)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.Space.xs)
        }
    }
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
                Text(schedule.when)
                    .font(Typeface.rounded(17, .regular))
                    .foregroundStyle(Palette.snow)
                Text(schedule.detail)
                    .font(Typeface.rounded(14, .regular))
                    .foregroundStyle(Palette.secondary)
                    .lineHeight(1.4, size: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onChange) {
                Text("Change")
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
