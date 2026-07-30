import SwiftUI

/// Multiple children with separate memories, plus Santa's language.
struct PersonalizeTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                VaultSectionCaption(text: "CHILDREN")

                VaultGroup {
                    ForEach(state.children) { child in
                        VaultRow(
                            title: child.name,
                            detail: child.detail,
                            leading: AnyView(ChildInitial(name: child.name, tint: child.tint)),
                            action: {},
                            accessory: {
                                if !child.badge.isEmpty {
                                    Text(child.badge)
                                        .font(Typeface.rounded(13, .regular))
                                        .foregroundStyle(Palette.pine)
                                }
                            }
                        )
                        RowDivider()
                    }

                    AddChildRow(action: state.addChild)
                }

                Text("Santa keeps a separate memory for each child and never mixes them up.")
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.faint)
                    .lineHeight(1.5, size: 13)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.Space.xs)
                    .padding(.top, Metrics.Space.s)
            }

            VStack(spacing: 0) {
                VaultSectionCaption(text: "SANTA")

                VaultGroup {
                    VaultRow(
                        title: "Language Santa speaks",
                        detail: "He greets and jokes like a native speaker",
                        value: state.language.native,
                        action: {}
                    )
                }
            }
        }
    }
}

private struct AddChildRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.m) {
                Circle()
                    .stroke(Color(hex: 0xF5B14C, opacity: 0.5),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: 40, height: 40)
                    .overlay {
                        PlusGlyph()
                            .stroke(Palette.firelight,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 16, height: 16)
                    }

                Text("Add another child")
                    .font(Typeface.rounded(17, .regular))
                    .foregroundStyle(Palette.firelight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Metrics.listGutter)
            .padding(.vertical, Metrics.Space.m)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
