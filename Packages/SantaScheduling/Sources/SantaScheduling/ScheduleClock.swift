import Foundation

/// One of the fixed "Tonight, 6:30 PM" choices on the When sheet.
///
/// Stored as parts rather than a date so the same preset means 6:30 this evening
/// today and 6:30 tomorrow evening tomorrow, instead of drifting into the past
/// the moment the app has been open a while.
public struct PresetSchedule: Sendable, Hashable, Identifiable {
    public let label: String
    public let dayOffset: Int
    /// 24-hour, so there is no meridiem to get wrong.
    public let hour: Int
    public let minute: Int

    public var id: String { label }

    public init(label: String, dayOffset: Int, hour: Int, minute: Int) {
        self.label = label
        self.dayOffset = dayOffset
        self.hour = hour
        self.minute = minute
    }
}

/// Turns the choices a parent can make into the instant Santa should ring.
///
/// Every entry point is pure and takes its `now` and `Calendar`, which is what
/// makes "is 6:30 PM still ahead of us?" a testable question rather than
/// something only reproducible at 6:29 in the evening.
public enum ScheduleClock {

    /// The instant a preset means, relative to `now`. Nil only if the calendar
    /// cannot form the date — a daylight-saving gap, say.
    public static func date(
        for preset: PresetSchedule,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: preset.dayOffset, to: now) else {
            return nil
        }
        return calendar.date(
            bySettingHour: preset.hour,
            minute: preset.minute,
            second: 0,
            of: day
        )
    }

    /// The instant the custom picker means.
    ///
    /// `hour12` is 1...12 with `isPM` alongside, because that is what the four
    /// columns collect. Noon and midnight are the two the arithmetic gets wrong
    /// if written the obvious way: 12 AM is hour 0, 12 PM is hour 12.
    public static func date(
        dayOffset: Int,
        hour12: Int,
        minute: Int,
        isPM: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let normalised = hour12 % 12
        let hour24 = isPM ? normalised + 12 : normalised

        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
            return nil
        }
        return calendar.date(bySettingHour: hour24, minute: minute, second: 0, of: day)
    }

    /// Whether a preset has already happened today and should drop off the sheet.
    ///
    /// A parent must not be able to book a time that is behind them — the call
    /// would be born missed.
    public static func hasPassed(
        _ preset: PresetSchedule,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let date = date(for: preset, now: now, calendar: calendar) else { return true }
        return date <= now
    }
}
