import Foundation
import Testing
@testable import SantaScheduling

@Suite("ScheduleFormat")
struct ScheduleFormatTests {

    private let calendar = TestClock.calendar
    private let locale = TestClock.locale

    @Test("an evening call today reads as tonight")
    func tonight() {
        let label = ScheduleFormat.dayLabel(
            for: TestClock.date(hour: 18, minute: 30),
            now: TestClock.date(hour: 9),
            calendar: calendar
        )

        #expect(label == "Tonight")
    }

    @Test("a morning call today reads as today")
    func today() {
        let label = ScheduleFormat.dayLabel(
            for: TestClock.date(hour: 9, minute: 30),
            now: TestClock.date(hour: 8),
            calendar: calendar
        )

        #expect(label == "Today")
    }

    @Test("the next day reads as tomorrow")
    func tomorrow() {
        let label = ScheduleFormat.dayLabel(
            for: TestClock.date(hour: 18, minute: 30, day: 2),
            now: TestClock.date(hour: 9),
            calendar: calendar
        )

        #expect(label == "Tomorrow")
    }

    /// "Tomorrow" has to mean the next calendar day, not twenty-four hours —
    /// 11pm tonight and 1am tonight are hours apart but different days.
    @Test("late tonight is still tonight, and just after midnight is tomorrow")
    func dayBoundary() {
        let now = TestClock.date(hour: 23)

        #expect(ScheduleFormat.dayLabel(for: TestClock.date(hour: 23, minute: 30), now: now, calendar: calendar) == "Tonight")
        #expect(ScheduleFormat.dayLabel(for: TestClock.date(hour: 0, minute: 30, day: 2), now: now, calendar: calendar) == "Tomorrow")
    }

    @Test("further out reads as a date")
    func laterDate() {
        let label = ScheduleFormat.dayLabel(
            for: TestClock.date(hour: 18, minute: 30, day: 8),
            now: TestClock.date(hour: 9),
            calendar: calendar
        )

        #expect(label == "Sat 8 Aug")
    }

    /// Asserted by composition rather than against a literal: `DateFormatter`
    /// separates the time from the meridiem with a narrow no-break space, not an
    /// ASCII one, and which codepoint Apple picks is not this function's promise.
    @Test("the full label joins the day and the time with a middot")
    func fullLabel() {
        let date = TestClock.date(hour: 18, minute: 30)
        let now = TestClock.date(hour: 9)

        let label = ScheduleFormat.label(for: date, now: now, calendar: calendar, locale: locale)
        let time = ScheduleFormat.timeLabel(for: date, locale: locale, calendar: calendar)

        #expect(label == "Tonight · \(time)")
        #expect(time.hasPrefix("6:30"))
        #expect(time.hasSuffix("PM"))
    }
}
