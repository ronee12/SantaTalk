import SwiftUI

/// The rounded translucent container every grouped list in the vault sits in.
struct VaultGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Palette.glassSunk)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.group, style: .continuous))
    }
}

/// The half-point rule between rows inside a group.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 0.5)
    }
}

/// The uppercase caption that labels a group.
struct VaultSectionCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .sectionCaptionStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.Space.xs)
            .padding(.bottom, Metrics.Space.s)
    }
}

/// A settings row: title, optional detail line, optional trailing value, optional chevron.
struct VaultRow<Accessory: View>: View {
    let title: String
    var detail: String?
    var value: String?
    var showsChevron: Bool = true
    var leading: AnyView?
    var action: (() -> Void)?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        let row = HStack(spacing: Metrics.Space.m) {
            if let leading { leading }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typeface.rounded(17, .regular))
                    .foregroundStyle(Palette.snow)
                if let detail {
                    Text(detail)
                        .font(Typeface.rounded(14, .regular))
                        .foregroundStyle(Palette.secondary)
                        .lineHeight(1.4, size: 14)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value {
                Text(value)
                    .font(Typeface.rounded(15, .regular))
                    .foregroundStyle(Palette.secondary)
            }

            accessory

            if showsChevron { DisclosureChevron() }
        }
        .padding(.horizontal, Metrics.listGutter)
        .padding(.vertical, Metrics.Space.m)
        .frame(minHeight: 52)
        .contentShape(.rect)

        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

extension VaultRow where Accessory == EmptyView {
    init(
        title: String,
        detail: String? = nil,
        value: String? = nil,
        showsChevron: Bool = true,
        leading: AnyView? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            detail: detail,
            value: value,
            showsChevron: showsChevron,
            leading: leading,
            action: action,
            accessory: { EmptyView() }
        )
    }
}

/// The system-styled switch used for recording, reminders and reaction video.
struct IOSToggle: View {
    let isOn: Bool
    var accessibilityTitle: String
    var action: (() -> Void)?

    var body: some View {
        let track = Capsule()
            .fill(isOn ? Palette.accept : Color.white.opacity(0.18))
            .frame(width: 51, height: 31)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.18), value: isOn)

        if let action {
            Button(action: action) { track }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityTitle)
                .accessibilityValue(isOn ? "On" : "Off")
        } else {
            track
                .accessibilityLabel(accessibilityTitle)
                .accessibilityValue(isOn ? "On" : "Off")
        }
    }
}

/// The circular initial that stands in for a child's avatar.
struct ChildInitial: View {
    let name: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)))
                    .font(Typeface.rounded(size * 0.425, .bold))
                    .foregroundStyle(Palette.onTint)
            }
    }
}
