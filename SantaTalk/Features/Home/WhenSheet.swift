import SantaScheduling
import SwiftUI

/// When should Santa call? A countdown, tonight, or any date and time.
struct WhenSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        BottomSheetContainer(maxHeightFraction: 0.74, onDismiss: { state.sheet = nil }) {
            SheetHeader(title: "When should Santa call?") { state.sheet = nil }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        switch item.kind {
                        case .header:
                            Text(item.label)
                                .font(Typeface.rounded(12, .regular))
                                .tracking(0.6)
                                .foregroundStyle(Palette.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Metrics.Space.m)
                                .padding(.top, 14)
                                .padding(.bottom, 6)

                        case .row(let isActive, let select):
                            SheetOptionRow(label: item.label, isActive: isActive, action: select)
                        }
                    }
                }
                .padding(.horizontal, Metrics.Space.m)
                .padding(.bottom, Metrics.sheetBottom)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Options

    private struct Item: Identifiable {
        enum Kind {
            case header
            case row(isActive: Bool, select: () -> Void)
        }

        let id = UUID()
        let label: String
        let kind: Kind
    }

    private var items: [Item] {
        var items: [Item] = []

        items.append(Item(label: "RIGHT NOW", kind: .header))
        for timing in Catalog.timings where !timing.isLater {
            items.append(timingItem(timing))
        }

        items.append(Item(label: "LATER", kind: .header))
        for timing in Catalog.timings where timing.isLater {
            items.append(timingItem(timing))
        }

        // Presets whose moment has already gone are not offered — booking one
        // would create a call that is missed the instant it is made.
        for preset in state.availablePresets {
            items.append(Item(label: preset.label, kind: .row(
                isActive: isSelected(preset),
                select: { state.selectPreset(preset) }
            )))
        }

        items.append(Item(label: "Pick any date and time…", kind: .row(
            isActive: isCustomTime,
            select: { state.sheet = .picker }
        )))

        return items
    }

    /// A preset is ticked when the booked instant is the one it resolves to.
    private func isSelected(_ preset: PresetSchedule) -> Bool {
        guard let scheduledAt = state.scheduledAt,
              let presetDate = ScheduleClock.date(for: preset, now: .now)
        else { return false }
        return scheduledAt == presetDate
    }

    /// A booked time that is not one of the presets came from the picker.
    private var isCustomTime: Bool {
        guard state.scheduledAt != nil else { return false }
        return !state.availablePresets.contains(where: isSelected)
    }

    private func timingItem(_ timing: CallTiming) -> Item {
        Item(label: timing.label, kind: .row(
            isActive: state.scheduledAt == nil && state.timingSeconds == timing.seconds,
            select: { state.selectTiming(timing) }
        ))
    }
}

/// A selectable row inside a sheet: label plus a check when it is the current choice.
struct SheetOptionRow: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.m) {
                Text(label)
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Palette.snow)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    Text("✓")
                        .font(Typeface.rounded(15, .bold))
                        .foregroundStyle(Palette.firelight)
                }
            }
            .padding(Metrics.Space.m)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous)
                    .fill(isActive ? Color(hex: 0xF5B14C, opacity: 0.14) : .clear)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
