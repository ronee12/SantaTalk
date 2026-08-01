import Foundation

/// The numbers the whole feature agrees on, in one place.
///
/// They are here rather than scattered across the scheduler and the views
/// because every one of them appears in copy the parent reads — "fifteen minutes
/// either side", "five minutes before" — and a constant that drifts from its
/// sentence is a promise the app stops keeping.
public enum ScheduleRules {

    /// A new call clashes with an existing one booked within this much of it,
    /// either side. A Santa call plus its ringing runs several minutes, so
    /// same-minute-only would let two calls collide in practice.
    public static let conflictWindow: TimeInterval = 15 * 60

    /// How long after its moment a call can still be answered. Phones get picked
    /// up late; past this the call is missed rather than ringing out of nowhere.
    public static let graceWindow: TimeInterval = 30 * 60

    /// How far ahead of the call the reminder lands.
    public static let reminderLead: TimeInterval = 5 * 60

    /// Anything at least this far out is booked rather than dialled.
    public static let schedulingThreshold: TimeInterval = 60
}
