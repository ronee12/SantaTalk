import SwiftUI

/// The page that closes the sale. Parents install this app suspicious, and rightly so — four
/// plain claims, each one checkable, in the order a worried adult asks them.
struct SafetyView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    intro
                    claims.padding(.top, 36)
                    contact.padding(.top, 34)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.xxl)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(Palette.nightDeep.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: state.leaveSafetyPage) {
                ChevronShape()
                    .stroke(Palette.cream,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 20)
                    .padding(.leading, 10)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Why our app is safe")
                .font(Typeface.rounded(20, .semibold))
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 54)
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.Space.s)
        .padding(.bottom, 14)
        .background(Gradients.santaHeader.ignoresSafeArea(edges: .top))
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 0) {
            SafetyShieldIcon()

            Text("Santa Call is safe, and we never collect data from you.")
                .font(Typeface.rounded(26, .semibold))
                .foregroundStyle(Palette.cream)
                .lineHeight(1.3, size: 26)
                .multilineTextAlignment(.center)
                .padding(.top, 22)

            Text("We are a registered company in Seoul, Korea, making apps for all ages. We are parents ourselves and we build this the way we would want it built for our own children.")
                .font(Typeface.rounded(16, .regular))
                .foregroundStyle(Palette.secondary)
                .lineHeight(1.6, size: 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Metrics.Space.l)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Claims

    private var claims: some View {
        VStack(spacing: 0) {
            SafetyClaim(
                title: "No stranger is ever on the line",
                detail: "Santa is a synthetic voice. There is no person on the other end, no operator listening in, and no way for anyone to join your child's call.",
                isLast: false
            ) {
                ZStack {
                    MicSolidCapsule().stroke(Palette.santaBright, lineWidth: 1.7)
                    MicSolidCradle().stroke(Palette.santaBright,
                                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                }
                .frame(width: 26, height: 26)
            }

            SafetyClaim(
                title: "The camera is never used",
                detail: "Calls are voice only. We ask for the microphone so Santa can hear your child answer, and for nothing else — there is no video, ever.",
                isLast: false
            ) {
                ZStack {
                    EyeOutline().stroke(Palette.santaBright, lineWidth: 1.7)
                    SlashGlyph().stroke(Palette.santaBright,
                                        style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                }
                .frame(width: 26, height: 26)
            }

            SafetyClaim(
                title: "Recordings are yours alone",
                detail: "Every recording stays on this phone for you to keep or share. Nothing is uploaded, and you can switch recording off in Settings at any time.",
                isLast: false
            ) {
                VideoIcon(size: 26, color: Palette.santaBright, isOff: false, lineWidth: 1.7)
            }

            SafetyClaim(
                title: "We never collect names or numbers",
                detail: "The name and details you type stay on the device so Santa can use them during the call. We do not ask for your phone number, and we do not sell or share anything.",
                isLast: true
            ) {
                PersonSearchGlyph()
                    .stroke(Palette.santaBright, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                    .frame(width: 26, height: 26)
            }
        }
    }

    private var contact: some View {
        Text("Questions about any of this? Write to us at hello@santacall.app — a parent answers, usually the same day.")
            .font(Typeface.rounded(14, .regular))
            .foregroundStyle(Palette.secondary)
            .lineHeight(1.6, size: 14)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Metrics.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                    .fill(Palette.glassSunk)
            }
    }
}

/// One claim on the timeline: a ringed icon with a connector, and the text beside it.
private struct SafetyClaim<Icon: View>: View {
    let title: String
    let detail: String
    let isLast: Bool
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.l) {
            Circle()
                .stroke(Palette.santaBright, lineWidth: 1.6)
                .frame(width: 56, height: 56)
                .overlay { icon }

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Typeface.rounded(21, .semibold))
                    .foregroundStyle(Palette.cream)
                    .lineHeight(1.25, size: 21)

                Text(detail)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.secondary)
                    .lineHeight(1.55, size: 15)
                    .padding(.top, Metrics.Space.s)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : 34)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .topLeading) {
            // Drawn behind the row so it spans whatever height the copy needs, starting
            // just below the icon and centred on it.
            if !isLast {
                Rectangle()
                    .fill(Color(hex: 0xEDF2FF, opacity: 0.16))
                    .frame(width: 1)
                    .padding(.top, 56 + Metrics.Space.s)
                    .padding(.leading, 27.5)
            }
        }
    }
}
