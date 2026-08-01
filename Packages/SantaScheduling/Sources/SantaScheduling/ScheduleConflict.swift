import Foundation

/// Enough of a booked call for the conflict check to reason about, without the
/// package needing to know SwiftData exists.
public struct ScheduleSlot: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let childName: String
    public let fireAt: Date

    public init(id: UUID, childName: String, fireAt: Date) {
        self.id = id
        self.childName = childName
        self.fireAt = fireAt
    }
}

/// Santa can only be on one call at a time, so two bookings close together are a
/// mistake worth catching at the moment they are made rather than at the moment
/// they collide.
public enum ScheduleConflict {

    /// The already-booked call that stands in the way of `fireAt`, if any.
    ///
    /// `excluding` is the call being edited — rebooking Ben's 6:30 for 6:35 must
    /// not report Ben's own 6:30 as the thing blocking it.
    public static func first(
        against fireAt: Date,
        among slots: [ScheduleSlot],
        excluding excludedID: UUID? = nil,
        window: TimeInterval = ScheduleRules.conflictWindow
    ) -> ScheduleSlot? {
        slots
            .filter { $0.id != excludedID }
            .filter { abs($0.fireAt.timeIntervalSince(fireAt)) < window }
            // The nearest one is the one to name — it is the call the parent is
            // most likely thinking of.
            .min { abs($0.fireAt.timeIntervalSince(fireAt)) < abs($1.fireAt.timeIntervalSince(fireAt)) }
    }
}
