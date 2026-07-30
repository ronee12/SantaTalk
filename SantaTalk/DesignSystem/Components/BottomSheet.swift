import SwiftUI

/// The dimmed backdrop plus rounded panel every sheet in the app shares.
/// Presented as an overlay rather than a system sheet so the night scene stays behind it.
struct BottomSheetContainer<Content: View>: View {
    var maxHeightFraction: CGFloat = 0.8
    var background: Color = Palette.sheet.opacity(0.96)
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color(hex: 0x040818, opacity: 0.6)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: 0) { content }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: proxy.size.height * maxHeightFraction, alignment: .top)
                    .background(background)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Palette.strokeStrong)
                            .frame(height: 1)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: Metrics.Radius.sheet,
                            topTrailingRadius: Metrics.Radius.sheet,
                            style: .continuous
                        )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
    }
}

/// Title on the left, Done on the right — the header on the when and topic sheets.
struct SheetHeader: View {
    let title: String
    var onDone: () -> Void

    var body: some View {
        HStack(spacing: Metrics.Space.m) {
            Text(title)
                .font(Typeface.rounded(17, .semibold))
                .foregroundStyle(Palette.snow)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDone) {
                Text("Done")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Palette.firelight)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}
