import SwiftUI

/// A gate a five-year-old loses interest in. Reading four two-digit numbers and ordering them
/// is trivial for an adult and beyond a pre-reader, so the vault stays shut without a parent
/// inventing another PIN.
struct ParentGateView: View {
    @Environment(AppState.self) private var state

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        VStack(spacing: 0) {
            BackLabelButton(title: "Back", action: state.leaveVault)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Circle()
                .fill(Color(hex: 0xF5B14C, opacity: 0.14))
                .overlay { Circle().stroke(Color(hex: 0xF5B14C, opacity: 0.3), lineWidth: 1) }
                .frame(width: 76, height: 76)
                .overlay { LockIcon(width: 30, height: 34) }

            Text("Grown-ups only")
                .font(Typeface.rounded(26, .bold))
                .tracking(-0.4)
                .foregroundStyle(Palette.cream)
                .padding(.top, 20)

            Text("Tap the four numbers from smallest to largest.")
                .font(Typeface.rounded(16, .regular))
                .foregroundStyle(Palette.secondary)
                .lineHeight(1.5, size: 16)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 10)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(state.gateNumbers, id: \.self) { number in
                    GateTile(
                        number: number,
                        order: state.gatePicked.firstIndex(of: number),
                        action: { state.tapGate(number) }
                    )
                }
            }
            .padding(.top, 28)

            Text(state.gateHint)
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(state.gateFailed ? Palette.destructive : Palette.faint)
                .frame(minHeight: 20)
                .padding(.top, 18)

            Spacer()

            Text("Reading four two-digit numbers is nothing for an adult and beyond a pre-reader. No PIN to remember, nothing to forget.")
                .font(Typeface.rounded(13, .regular))
                .foregroundStyle(Palette.faint)
                .lineHeight(1.5, size: 13)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, Metrics.navTop)
        .padding(.bottom, Metrics.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An 88pt tile with 34pt numerals, badged with its position once tapped.
private struct GateTile: View {
    let number: Int
    let order: Int?
    let action: () -> Void

    private var isPicked: Bool { order != nil }

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(Typeface.rounded(34, .bold))
                .foregroundStyle(isPicked ? Palette.onAmber : Palette.snow)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.childTarget)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.Radius.sheet - 6, style: .continuous)
                        .fill(isPicked ? Color(hex: 0xF5B14C, opacity: 0.9) : Palette.glass)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.Radius.sheet - 6, style: .continuous)
                                .stroke(isPicked ? Color(hex: 0xF5B14C, opacity: 0.9) : Palette.stroke,
                                        lineWidth: 1)
                        }
                }
                .overlay(alignment: .topTrailing) {
                    if let order {
                        Text("\(order + 1)")
                            .font(Typeface.rounded(13, .bold))
                            .foregroundStyle(Palette.onAmber.opacity(0.6))
                            .padding(.top, Metrics.Space.s)
                            .padding(.trailing, 10)
                    }
                }
                .scaleEffect(isPicked ? 0.96 : 1)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Number \(number)")
    }
}
