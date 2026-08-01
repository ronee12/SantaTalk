import Foundation

/// Where a booked call stands relative to the clock.
public enum ScheduleStanding: Sendable, Hashable {
    /// Its moment has not arrived. Nothing to do but wait.
    case waiting
    /// Now, or late enough to still be worth ringing.
    case due
    /// Too late. Santa waited and nobody came.
    case missed
}

/// Decides whether a scheduled call can still happen.
///
/// This is the whole answer to "the notification fired at 6:30 and the parent
/// tapped it at 7:15": inside the grace window Santa still rings, outside it the
/// call is missed and the app says so rather than ringing at a sleeping child.
public enum ScheduleWindow {

    public static func standing(
        fireAt: Date,
        now: Date,
        grace: TimeInterval = ScheduleRules.graceWindow
    ) -> ScheduleStanding {
        if now < fireAt { return .waiting }
        return now.timeIntervalSince(fireAt) <= grace ? .due : .missed
    }

    /// When the reminder for this call should land, or nil if that moment has
    /// already gone — booking a call four minutes out must not schedule a
    /// reminder into the past.
    public static func reminderDate(
        forCallAt fireAt: Date,
        now: Date,
        lead: TimeInterval = ScheduleRules.reminderLead
    ) -> Date? {
        let reminder = fireAt.addingTimeInterval(-lead)
        return reminder > now ? reminder : nil
    }

    /// Whether a chosen instant is far enough out to be booked rather than
    /// counted down on screen.
    public static func isSchedulable(
        fireAt: Date,
        now: Date,
        threshold: TimeInterval = ScheduleRules.schedulingThreshold
    ) -> Bool {
        fireAt.timeIntervalSince(now) >= threshold
    }
}
