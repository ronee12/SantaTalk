import Foundation
import Testing
@testable import SantaScheduling

@Suite("ScheduleWindow")
struct ScheduleWindowTests {

    private let fireAt = TestClock.date(hour: 18, minute: 30)

    @Test("before its moment a call is waiting")
    func waiting() {
        let standing = ScheduleWindow.standing(fireAt: fireAt, now: TestClock.date(hour: 18))

        #expect(standing == .waiting)
    }

    @Test("at its moment a call is due")
    func dueOnTheDot() {
        let standing = ScheduleWindow.standing(fireAt: fireAt, now: fireAt)

        #expect(standing == .due)
    }

    /// The whole point of the grace window: a parent who reaches the phone at
    /// 7:15 still gets the call they booked for 6:30.
    @Test("inside the grace window a late tap still rings")
    func lateButDue() {
        let standing = ScheduleWindow.standing(fireAt: fireAt, now: TestClock.date(hour: 19, minute: 0))

        #expect(standing == .due)
    }

    @Test("the last second of the grace window still rings")
    func graceBoundary() {
        let standing = ScheduleWindow.standing(
            fireAt: fireAt,
            now: fireAt.addingTimeInterval(ScheduleRules.graceWindow)
        )

        #expect(standing == .due)
    }

    @Test("past the grace window the call is missed")
    func missed() {
        let standing = ScheduleWindow.standing(fireAt: fireAt, now: TestClock.date(hour: 19, minute: 1))

        #expect(standing == .missed)
    }

    @Test("the reminder lands five minutes before the call")
    func reminder() {
        let reminder = ScheduleWindow.reminderDate(forCallAt: fireAt, now: TestClock.date(hour: 12))

        #expect(reminder == TestClock.date(hour: 18, minute: 25))
    }

    /// Booking a call four minutes out must not schedule a reminder into the
    /// past — iOS would simply drop it, and the parent would be told a reminder
    /// was coming that never arrives.
    @Test("a call sooner than the lead time gets no reminder")
    func noReminderWhenTooSoon() {
        let reminder = ScheduleWindow.reminderDate(
            forCallAt: fireAt,
            now: TestClock.date(hour: 18, minute: 27)
        )

        #expect(reminder == nil)
    }

    @Test("a minute out is schedulable, less than that is not")
    func schedulingThreshold() {
        let now = TestClock.date(hour: 18)

        #expect(ScheduleWindow.isSchedulable(fireAt: now.addingTimeInterval(60), now: now))
        #expect(ScheduleWindow.isSchedulable(fireAt: now.addingTimeInterval(300), now: now))
        #expect(!ScheduleWindow.isSchedulable(fireAt: now.addingTimeInterval(30), now: now))
    }
}
