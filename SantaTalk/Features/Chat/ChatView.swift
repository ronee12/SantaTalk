import SwiftUI

/// The low-effort path. Not every night has room for a phone call — chat keeps the
/// relationship warm, and everything typed here feeds the next call.
struct ChatView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            thread
            composer
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: state.closeChat) {
                ChevronShape()
                    .stroke(Palette.firelight,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 18)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Image("SantaPortrait")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 0) {
                Text("Santa")
                    .font(Typeface.rounded(17, .semibold))
                    .foregroundStyle(Palette.snow)
                Text("At the workshop · replies fast")
                    .font(Typeface.rounded(13, .regular))
                    .foregroundStyle(Palette.pine)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .padding(.top, Metrics.navTop)
        .padding(.horizontal, Metrics.Space.m)
        .padding(.bottom, 10)
        .translucentNavBackground()
    }

    // MARK: Thread

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(state.chat) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Metrics.listGutter)
                .padding(.top, Metrics.listGutter)
                .padding(.bottom, Metrics.Space.s)
            }
            .scrollIndicators(.hidden)
            .onChange(of: state.chat.count) {
                withAnimation { proxy.scrollTo(state.chat.last?.id, anchor: .bottom) }
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(spacing: 10) {
            GlassTextField(
                placeholder: "Write to Santa…",
                text: Binding(get: { state.draft }, set: { state.draft = $0 }),
                height: 48,
                fontSize: 16,
                fontWeight: .regular,
                cornerRadius: 24,
                accessibilityTitle: "Message Santa"
            )

            Button(action: state.sendChatMessage) {
                Circle()
                    .fill(Gradients.amberChip)
                    .frame(width: 48, height: 48)
                    .overlay {
                        SendGlyph()
                            .fill(Palette.onAmber)
                            .frame(width: 20, height: 18)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Metrics.Space.m)
        .padding(.top, Metrics.Space.s)
        .padding(.bottom, Metrics.Space.m)
    }
}

/// Santa's bubbles are glass and left-aligned; the parent's are amber and right-aligned.
private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if !message.isFromSanta { Spacer(minLength: 0) }

            Text(message.text)
                .font(Typeface.rounded(16, .regular))
                .foregroundStyle(message.isFromSanta ? Palette.snow : Palette.onAmber)
                .lineHeight(1.4, size: 16)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, Metrics.Space.m)
                .background {
                    bubbleShape
                        .fill(message.isFromSanta
                              ? AnyShapeStyle(Color.white.opacity(0.09))
                              : AnyShapeStyle(Gradients.amberChip))
                }
                .frame(maxWidth: 300, alignment: message.isFromSanta ? .leading : .trailing)

            if message.isFromSanta { Spacer(minLength: 0) }
        }
    }

    /// One corner is tucked in on the side the message came from.
    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: message.isFromSanta ? 4 : 16,
            bottomTrailingRadius: message.isFromSanta ? 16 : 4,
            topTrailingRadius: 16,
            style: .continuous
        )
    }
}
