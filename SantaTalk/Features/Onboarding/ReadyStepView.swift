import SwiftUI

/// Step 8 of 8. The meter summarises what Santa knows and quietly names what is missing —
/// the only nudge the parent zone gets. Then a single sentence hands the phone over.
struct ReadyStepView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Santa is ready to call \(state.childName).").questionStyle()

                    Text("Your first call is free. Nothing renews, nothing expires today.")
                        .subtitleStyle()
                        .padding(.top, Metrics.Space.s)
                        .padding(.bottom, Metrics.Space.xl)

                    KnowledgeMeterCard(
                        percent: state.meterPercent(inVault: false),
                        label: state.meterLabel(inVault: false),
                        rows: state.meterRows
                    )

                    WishListPromise()
                        .padding(.top, 20)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Metrics.Space.m) {
                AmberButton(
                    title: "Hand the phone to \(state.childName)",
                    height: 56,
                    action: state.handOverToChild
                )
                AmberLink(title: "Open the vault instead of \(state.childName)'s profile first",
                          action: state.openVault)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.Space.l)
            .padding(.bottom, Metrics.bottom)
        }
    }
}

/// What Santa knows: a percentage, a fill, and a checklist naming the gaps.
struct KnowledgeMeterCard: View {
    let percent: Int
    let label: String
    let rows: [AppState.MeterRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("What Santa knows")
                    .font(Typeface.rounded(18, .semibold))
                    .foregroundStyle(Palette.snow)
                Spacer()
                Text("\(percent)%")
                    .font(Typeface.rounded(16, .semibold))
                    .foregroundStyle(Palette.firelight)
            }

            MeterTrack(percent: percent)
                .padding(.top, 14)

            Text(label)
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Palette.snow)
                .lineHeight(1.45, size: 15)
                .padding(.top, Metrics.Space.m)

            VStack(alignment: .leading, spacing: Metrics.Space.s) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Text(row.mark)
                            .font(Typeface.rounded(15, .bold))
                            .frame(width: 14)
                        Text(row.text)
                            .font(Typeface.rounded(15, .regular))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(row.color)
                }
            }
            .padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                .fill(Palette.glass)
        }
    }
}

/// The 10pt amber fill. Animates over 400ms ease-in-out — no confetti; setup is not one of
/// the three sanctioned bursts.
private struct MeterTrack: View {
    let percent: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Gradients.amberTrack)
                    .frame(width: proxy.size.width * CGFloat(percent) / 100)
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.4), value: percent)
        .accessibilityElement()
        .accessibilityLabel("Santa knows \(percent) percent")
    }
}

/// The bordered note under the meter: the payoff the parent gets after the call.
private struct WishListPromise: View {
    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.m) {
            StarGlyph()
                .fill(Palette.firelight)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            Text("After the call you get a wish list of everything she asked for, in her own words.")
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(Palette.snow)
                .lineHeight(1.45, size: 15)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Metrics.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        }
    }
}
