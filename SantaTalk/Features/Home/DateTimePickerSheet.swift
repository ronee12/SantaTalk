import SwiftUI

/// Four scrolling columns instead of a system wheel, so the whole sheet stays in the app's
/// own visual language. Reached from "Pick any date and time…".
struct DateTimePickerSheet: View {
    @Environment(AppState.self) private var state

    private var days: [String] { Format.dayLabels() }

    var body: some View {
        BottomSheetContainer(
            maxHeightFraction: 0.8,
            background: Palette.sheet.opacity(0.97),
            onDismiss: { state.sheet = nil }
        ) {
            header

            HStack(spacing: 6) {
                PickerColumn(
                    title: "DAY",
                    options: days.enumerated().map { PickerOption(value: $0.offset, label: $0.element) },
                    selection: state.pickerDay,
                    select: { state.pickerDay = $0 }
                )

                PickerColumn(
                    title: "HOUR",
                    options: (1...12).map { PickerOption(value: $0, label: String($0)) },
                    selection: state.pickerHour,
                    select: { state.pickerHour = $0 }
                )

                PickerColumn(
                    title: "MIN",
                    options: stride(from: 0, through: 55, by: 5)
                        .map { PickerOption(value: $0, label: String(format: "%02d", $0)) },
                    selection: state.pickerMinute,
                    select: { state.pickerMinute = $0 }
                )

                PickerColumn(
                    title: "",
                    options: [PickerOption(value: 0, label: "AM"), PickerOption(value: 1, label: "PM")],
                    selection: state.pickerMeridiem == "AM" ? 0 : 1,
                    select: { state.pickerMeridiem = $0 == 0 ? "AM" : "PM" }
                )
            }
            .frame(height: 236)
            .padding(.horizontal, Metrics.Space.m)
            .padding(.top, 6)

            // A time already behind us cannot be booked — the Today column puts
            // one a single tap away. The button says why rather than going dead
            // or, worse, accepting a call that is missed the moment it is made.
            HStack(spacing: 6) {
                Text(state.pickerConfirmLabel)
                if state.isPickedDateBookable {
                    Text(state.pickerSummary)
                }
            }
            .font(Typeface.rounded(17, .bold))
            .foregroundStyle(state.isPickedDateBookable ? Palette.onAmber : Palette.faint)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: Metrics.Radius.tile, style: .continuous)
                    .fill(state.isPickedDateBookable
                          ? AnyShapeStyle(Gradients.amberButton)
                          : AnyShapeStyle(Palette.glass))
            }
            .contentShape(.rect)
            .onTapGesture(perform: state.confirmPickedDateTime)
            .accessibilityAddTraits(state.isPickedDateBookable ? .isButton : .isStaticText)
            .animation(.easeOut(duration: 0.16), value: state.isPickedDateBookable)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, Metrics.sheetBottom)
        }
    }

    private var header: some View {
        HStack(spacing: Metrics.Space.m) {
            Button(action: { state.sheet = .when }) {
                Text("Back")
                    .font(Typeface.rounded(16, .regular))
                    .foregroundStyle(Palette.secondary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Text("Pick a time")
                .font(Typeface.rounded(17, .semibold))
                .foregroundStyle(Palette.snow)
                .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

/// One entry in a picker column.
private struct PickerOption: Identifiable {
    let value: Int
    let label: String

    var id: Int { value }
}

/// One scrollable column of the picker.
private struct PickerColumn: View {
    let title: String
    let options: [PickerOption]
    let selection: Int
    let select: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Typeface.rounded(11, .regular))
                .tracking(0.6)
                .foregroundStyle(Palette.tertiary)
                .frame(height: 13)
                .padding(.bottom, Metrics.Space.s)

            ScrollView {
                VStack(spacing: Metrics.Space.xs) {
                    ForEach(options) { option in
                        let selected = option.value == selection
                        Button(action: { select(option.value) }) {
                            Text(option.label)
                                .font(Typeface.rounded(16, .medium))
                                .foregroundStyle(selected ? Palette.onAmber : Palette.snow)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected
                                              ? AnyShapeStyle(Gradients.amberChip)
                                              : AnyShapeStyle(Palette.glassSunk))
                                }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, Metrics.Space.xs)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
    }
}
