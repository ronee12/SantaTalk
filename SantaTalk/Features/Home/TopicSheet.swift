import SwiftUI

/// A predefined list, because free text is where a parent stalls — with one field for the
/// parents who have something of their own.
struct TopicSheet: View {
    @Environment(AppState.self) private var state

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    private var hasCustomTopic: Bool { !state.customTopic.trimmed.isEmpty }

    var body: some View {
        BottomSheetContainer(maxHeightFraction: 0.8, onDismiss: { state.sheet = nil }) {
            SheetHeader(title: "What should Santa bring up?") { state.sheet = nil }

            HStack(spacing: 10) {
                GlassTextField(
                    placeholder: "Something of your own…",
                    text: Binding(get: { state.customTopic }, set: { state.customTopic = $0 }),
                    height: 48,
                    fontSize: 16,
                    fontWeight: .regular,
                    accessibilityTitle: "Your own topic"
                )

                Button(action: state.addCustomTopic) {
                    Text("Add")
                        .font(Typeface.rounded(16, .semibold))
                        .foregroundStyle(hasCustomTopic ? Palette.onAmber : Palette.faint)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background {
                            RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                                .fill(hasCustomTopic
                                      ? AnyShapeStyle(Gradients.amberChip)
                                      : AnyShapeStyle(Color.white.opacity(0.08)))
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use this topic")
            }
            .padding(.horizontal, Metrics.listGutter)
            .padding(.bottom, Metrics.Space.m)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Catalog.topics, id: \.self) { topic in
                        TopicTile(
                            label: topic,
                            isSelected: state.topic == topic,
                            minHeight: 76,
                            alignment: .leading,
                            action: {
                                state.topic = topic
                                state.sheet = nil
                            }
                        )
                    }
                }

                TopicTile(
                    label: "Nothing in particular",
                    isSelected: state.topic == nil,
                    minHeight: 56,
                    alignment: .center,
                    action: {
                        state.topic = nil
                        state.sheet = nil
                    }
                )
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, Metrics.listGutter)
            .padding(.bottom, Metrics.sheetBottom)
        }
    }
}

private struct TopicTile: View {
    let label: String
    let isSelected: Bool
    let minHeight: CGFloat
    let alignment: Alignment
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typeface.rounded(15, .regular))
                .foregroundStyle(isSelected ? Palette.onAmber : Palette.snow)
                .lineHeight(1.35, size: 15)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: alignment)
                .frame(minHeight: minHeight)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                        .fill(isSelected ? Palette.firelight : Palette.glass)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                                .stroke(isSelected ? Palette.firelight : Palette.stroke, lineWidth: 1)
                        }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
