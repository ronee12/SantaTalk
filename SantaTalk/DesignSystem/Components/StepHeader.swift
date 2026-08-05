import SwiftUI

/// The chevron that returns to the previous onboarding step.
struct BackChevron: View {
    var color: Color = Palette.chevron
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChevronShape()
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 20)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// The `M10 2L2 10l8 8` path the comp uses for every back chevron.
struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.width / 12, y = rect.height / 20
        path.move(to: CGPoint(x: 10 * x, y: 2 * y))
        path.addLine(to: CGPoint(x: 2 * x, y: 10 * y))
        path.addLine(to: CGPoint(x: 10 * x, y: 18 * y))
        return path
    }
}

/// The small right-facing disclosure chevron on list rows.
struct DisclosureChevron: View {
    var color: Color = Color(hex: 0xEDF2FF, opacity: 0.42)

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1, y: 1))
            path.addLine(to: CGPoint(x: 7, y: 7))
            path.addLine(to: CGPoint(x: 1, y: 13))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 8, height: 14)
    }
}

/// Three segments: the personalisation section only.
///
/// It counts the section rather than the whole flow on purpose — Skip jumps all
/// three of these screens, and a bar counting nine would make it read as
/// skipping one.
struct ProgressSegments: View {
    let step: Int

    var body: some View {
        HStack(spacing: Metrics.Space.xs) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index <= step
                          ? AnyShapeStyle(Gradients.segmentOn)
                          : AnyShapeStyle(Color(hex: 0xEDF2FF, opacity: 0.16)))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of 3")
    }
}

/// The band above the setup screens, which carry no header at all.
///
/// The comp reserves 56pt there; on device the status-bar inset covers all but the 4pt an
/// onboarding header would sit on, so that is what is left to add.
struct OnboardingTopBand: View {
    var body: some View {
        Color.clear
            .frame(height: Metrics.stepTop)
            .accessibilityHidden(true)
    }
}

/// Back chevron, progress, and an optional trailing action — the personalisation header.
struct OnboardingStepHeader: View {
    let step: Int
    let onBack: () -> Void
    var trailing: TrailingAction?

    struct TrailingAction {
        let title: String
        var accessibilityLabel: String?
        let action: () -> Void
    }

    var body: some View {
        HStack(spacing: Metrics.Space.m) {
            BackChevron(action: onBack)
                .padding(.leading, -10)

            ProgressSegments(step: step)

            if let trailing {
                Button(action: trailing.action) {
                    Text(trailing.title)
                        .font(Typeface.rounded(16, .medium))
                        .foregroundStyle(Palette.firelight)
                        .frame(minWidth: 34, minHeight: 44, alignment: .trailing)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(trailing.accessibilityLabel ?? trailing.title)
            } else {
                Color.clear.frame(width: 34, height: 1)
            }
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.stepTop)
        .padding(.horizontal, Metrics.listGutter)
    }
}
