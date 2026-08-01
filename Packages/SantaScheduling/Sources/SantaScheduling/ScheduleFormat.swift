import Foundation

/// How a booked call reads: `Tonight · 6:30 PM`, `Tomorrow · 6:30 PM`,
/// `Sat 8 Aug · 6:30 PM`.
///
/// The date is the record and this is the only thing that turns it into words,
/// so a call cannot say one time in the vault and another on the confirmation
/// screen — which is exactly what a stored display string allowed.
public enum ScheduleFormat {

    /// Evening is where nearly every Santa call lands, and "Tonight" is what a
    /// parent would say out loud.
    private static let eveningHour = 17

    public static func label(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        "\(dayLabel(for: date, now: now, calendar: calendar)) · \(timeLabel(for: date, locale: locale, calendar: calendar))"
    }

    public static func dayLabel(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case 0:
            let hour = calendar.component(.hour, from: date)
            return hour >= eveningHour ? "Tonight" : "Today"
        case 1:
            return "Tomorrow"
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "EEE d MMM"
            return formatter.string(from: date)
        }
    }

    public static func timeLabel(
        for date: Date,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
