import SwiftUI

/// The dashboard. Inverted from a dialler: Santa is the caller, the child is the one who
/// answers. A parent picks who the call is for, when it lands, and the one thing Santa
/// should bring up.
struct HomeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                content
                footer
            }

            sheets
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Metrics.Space.m) {
            Button(action: state.openVault) {
                Circle()
                    .fill(Color(hex: 0xF5B14C, opacity: 0.14))
                    .overlay { Circle().stroke(Color(hex: 0xF5B14C, opacity: 0.34), lineWidth: 1) }
                    .frame(width: 44, height: 44)
                    .overlay { LockIcon() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Parent vault")

            Text("Santa Call")
                .font(Typeface.rounded(20, .bold))
                .tracking(-0.2)
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)

            ProPill(action: state.openPaywall)
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.listGutter)
    }

    // MARK: Body

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                SantaPortrait()

                if state.children.count > 1 {
                    FlowLayout(spacing: Metrics.Space.s, lineSpacing: Metrics.Space.s, alignment: .center) {
                        ForEach(state.children.indices, id: \.self) { index in
                            ChildChip(
                                name: state.children[index].name,
                                isActive: index == state.activeChildIndex,
                                action: { state.selectChild(at: index) }
                            )
                        }
                    }
                    .padding(.top, Metrics.Space.l)
                }

                Text("Santa calls \(state.childName) — you decide when")
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                SettingRow(
                    caption: "When",
                    value: state.whenValue,
                    icon: AnyView(AlarmIcon()),
                    action: { state.sheet = .when }
                )
                .padding(.top, 22)

                SettingRow(
                    caption: "What Santa brings up",
                    value: state.topicValue,
                    icon: AnyView(MicrophoneSolidIcon(
                        size: 22,
                        capsuleColor: Palette.firelight,
                        cradleColor: Palette.firelightSoft
                    )),
                    action: { state.sheet = .topic }
                )
                .padding(.top, Metrics.Space.m)

                CallModeRow(
                    isVideo: state.wantsVideoCall,
                    detail: state.callModeDetail,
                    action: state.toggleCallMode
                )
                .padding(.top, Metrics.Space.m)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Metrics.Space.m) {
            // The red button is a commitment, so it says exactly what it will do.
            CallToActionButton(label: state.callToActionLabel, action: state.armCall)

            Text(state.callToActionHint)
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.tertiary)
                .lineHeight(1.4, size: 13)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ChatEntryRow(action: state.openChat)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, Metrics.bottom)
    }

    // MARK: Sheets

    @ViewBuilder
    private var sheets: some View {
        switch state.sheet {
        case .when: WhenSheet()
        case .topic: TopicSheet()
        case .picker: DateTimePickerSheet()
        case .notification: NotificationPermissionSheet()
        case nil: EmptyView()
        }
    }
}

// MARK: - Pieces

/// The upgrade pill. The only place a price is reachable from the dashboard.
private struct ProPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CrownGlyph().fill(Palette.onAmber).frame(width: 14, height: 12)
                Text("PRO").font(Typeface.rounded(13, .bold))
            }
            .foregroundStyle(Palette.onAmber)
            .padding(.horizontal, Metrics.Space.m)
            .frame(height: 36)
            .background(Capsule().fill(Gradients.amberChip))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Pro")
    }
}

/// Santa's portrait inside a flickering firelight halo.
private struct SantaPortrait: View {
    var body: some View {
        ZStack {
            FirelightHalo()
                .frame(width: 156, height: 156)

            Image("SantaPortrait")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 128, height: 128)
                .clipShape(.circle)
                .overlay {
                    Circle().stroke(Color(hex: 0xF5B14C, opacity: 0.55), lineWidth: 2)
                }
        }
        .frame(width: 128, height: 128)
        .accessibilityHidden(true)
    }
}

/// One chip per child, so a parent picks who the call is for.
private struct ChildChip: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(Typeface.rounded(15, .semibold))
                .foregroundStyle(isActive ? Palette.onAmber : Palette.secondary)
                .padding(.horizontal, Metrics.listGutter)
                .frame(minHeight: 38)
                .background {
                    Capsule()
                        .fill(isActive ? Palette.firelight : Palette.glassRaised)
                        .overlay {
                            Capsule().stroke(isActive ? Palette.firelight : Palette.stroke, lineWidth: 1)
                        }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isActive)
        .accessibilityLabel("Set up a call for \(name)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// The When and Topic rows: a caption, the current value, and a chevron into a sheet.
private struct SettingRow: View {
    let caption: String
    let value: String
    let icon: AnyView
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon

                VStack(alignment: .leading, spacing: 2) {
                    Text(caption)
                        .font(Typeface.rounded(12, .regular))
                        .foregroundStyle(Palette.tertiary)
                    Text(value)
                        .font(Typeface.rounded(15, .semibold))
                        .foregroundStyle(Palette.snow)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ChevronDownGlyph()
                    .stroke(Color(hex: 0xEDF2FF, opacity: 0.5),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                    .fill(Palette.glassRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(caption), \(value)")
    }
}

/// Video call or audio call, chosen before the phone rings.
///
/// It lives here rather than on the in-call screen because a child mid-conversation
/// with Santa should not be deciding whether they are on camera — and because a
/// call that changes kind halfway through is a recording that changes kind halfway
/// through.
private struct CallModeRow: View {
    let isVideo: Bool
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Slashed when the call is audio — the state is drawn, not just
            // written, so a glance at the row is enough.
            VideoIcon(
                size: 22,
                color: isVideo ? Palette.firelight : Color(hex: 0xEDF2FF, opacity: 0.34),
                isOff: !isVideo
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(isVideo ? "Video call" : "Audio call")
                    .font(Typeface.rounded(15, .semibold))
                    .foregroundStyle(Palette.snow)
                Text(detail)
                    .font(Typeface.rounded(12, .regular))
                    .foregroundStyle(Palette.tertiary)
                    .lineHeight(1.35, size: 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            IOSToggle(isOn: isVideo, accessibilityTitle: "Video call", action: action)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background {
            RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                .fill(Palette.glassRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                }
        }
    }
}

/// The one red thing on the screen.
private struct CallToActionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.m) {
                Text(label)
                    .font(Typeface.rounded(18, .bold))
                    .foregroundStyle(Palette.cream)

                ZStack {
                    Circle().fill(Color.white.opacity(0.9))
                    ArrowRightGlyph()
                        .stroke(Palette.santa,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 13, height: 12)
                }
                .frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.tile + 2, style: .continuous)
                    .fill(Gradients.callButton)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                    }
                    .shadow(color: Palette.santa.opacity(0.4), radius: 17, y: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.tile + 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Second entry point for the days there is no time for a call.
private struct ChatEntryRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.m) {
                Image("SantaPortrait")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat with Santa")
                        .font(Typeface.rounded(16, .semibold))
                        .foregroundStyle(Palette.snow)
                    Text("Write to him instead of calling")
                        .font(Typeface.rounded(13, .regular))
                        .foregroundStyle(Palette.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DisclosureChevron(color: Color(hex: 0xEDF2FF, opacity: 0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                    .fill(Palette.glass)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                            .stroke(Color(hex: 0xEDF2FF, opacity: 0.12), lineWidth: 1)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
