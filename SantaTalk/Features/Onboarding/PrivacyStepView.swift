import SwiftUI

/// Step 6 of 6, and the last thing between the parent and the dashboard: four plain claims
/// about where the call goes, in the order a worried adult asks them.
///
/// No numbered cards and no policy voice — four ticked lines, each one checkable, naming the
/// child so it reads as being about them rather than about a company. "Agree and continue"
/// rather than a consent checkbox the app does not need.
struct PrivacyStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBand()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ShieldTile()
                        .padding(.bottom, 22)

                    Text("Where the call goes.")
                        .font(Typeface.rounded(26, .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.snow)
                        .lineHeight(1.25, size: 26)

                    VStack(alignment: .leading, spacing: Metrics.Space.l) {
                        ForEach(state.dataClaims, id: \.self) { claim in
                            DataClaimRow(text: claim)
                        }
                    }
                    .padding(.top, Metrics.Space.xl)
                    .padding(.bottom, Metrics.Space.m)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.xl)
            }
            .scrollIndicators(.hidden)

            AmberButton(title: "Agree and continue", action: state.finishSetup)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.Space.s)
                .padding(.bottom, Metrics.bottom)
        }
    }
}

/// The one flourish on the screen: a shield in an amber-lit tile, sized to be read
/// rather than admired.
private struct ShieldTile: View {
    var body: some View {
        ZStack {
            DataShieldOutline()
                .stroke(Palette.firelight, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            DataShieldTick()
                .stroke(Palette.amberTop,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 38, height: 44)
        .frame(width: 76, height: 76)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Palette.firelight.opacity(0.28), location: 0),
                            .init(color: Palette.firelight.opacity(0.08), location: 0.6),
                            .init(color: Color.white.opacity(0.04), location: 1)
                        ],
                        center: UnitPoint(x: 0.3, y: 0),
                        startRadius: 0,
                        endRadius: 91
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.firelight.opacity(0.34), lineWidth: 1)
                }
                .shadow(color: Color(hex: 0x040818, opacity: 0.45), radius: 15, y: 12)
        }
        .accessibilityHidden(true)
    }
}

private struct DataClaimRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("✓")
                .font(Typeface.rounded(16, .bold))
                .foregroundStyle(Palette.firelight)
                .lineHeight(1.45, size: 16)

            Text(text)
                .font(Typeface.rounded(16, .regular))
                .foregroundStyle(Palette.snow)
                .lineHeight(1.45, size: 16)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
