import Foundation
import Testing
@testable import SantaScheduling

/// A fixed calendar, so "is 6:30 PM still ahead of us?" has the same answer in
/// every timezone the suite ever runs in.
enum TestClock {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static var locale: Locale { Locale(identifier: "en_US_POSIX") }

    /// 1 August 2026, at the given time, UTC.
    static func date(hour: Int, minute: Int = 0, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }
}

@Suite("ScheduleClock")
struct ScheduleClockTests {

    private let tonight = PresetSchedule(label: "Tonight, 6:30 PM", dayOffset: 0, hour: 18, minute: 30)
    private let tomorrow = PresetSchedule(label: "Tomorrow, 6:30 PM", dayOffset: 1, hour: 18, minute: 30)

    @Test("a preset resolves to that time on the offset day")
    func presetResolves() {
        let now = TestClock.date(hour: 9)
        let resolved = ScheduleClock.date(for: tonight, now: now, calendar: TestClock.calendar)

        #expect(resolved == TestClock.date(hour: 18, minute: 30))
    }

    @Test("a tomorrow preset lands on the next day, not today")
    func tomorrowPresetResolves() {
        let now = TestClock.date(hour: 9)
        let resolved = ScheduleClock.date(for: tomorrow, now: now, calendar: TestClock.calendar)

        #expect(resolved == TestClock.date(hour: 18, minute: 30, day: 2))
    }

    @Test("a preset earlier than now has passed")
    func passedPreset() {
        let now = TestClock.date(hour: 20)

        #expect(ScheduleClock.hasPassed(tonight, now: now, calendar: TestClock.calendar))
        #expect(!ScheduleClock.hasPassed(tomorrow, now: now, calendar: TestClock.calendar))
    }

    @Test("a preset exactly now counts as passed, so it cannot be booked")
    func presetAtThisInstant() {
        let now = TestClock.date(hour: 18, minute: 30)

        #expect(ScheduleClock.hasPassed(tonight, now: now, calendar: TestClock.calendar))
    }

    @Test("the picker converts 12-hour parts to the right instant")
    func pickerResolves() {
        let now = TestClock.date(hour: 9)
        let resolved = ScheduleClock.date(
            dayOffset: 0, hour12: 7, minute: 15, isPM: true,
            now: now, calendar: TestClock.calendar
        )

        #expect(resolved == TestClock.date(hour: 19, minute: 15))
    }

    /// The two the obvious arithmetic gets wrong.
    @Test("noon is 12:00 and midnight is 00:00")
    func meridiemEdges() {
        let now = TestClock.date(hour: 9)

        let noon = ScheduleClock.date(
            dayOffset: 0, hour12: 12, minute: 0, isPM: true,
            now: now, calendar: TestClock.calendar
        )
        let midnight = ScheduleClock.date(
            dayOffset: 0, hour12: 12, minute: 0, isPM: false,
            now: now, calendar: TestClock.calendar
        )

        #expect(noon == TestClock.date(hour: 12))
        #expect(midnight == TestClock.date(hour: 0))
    }
}
