import Foundation
import SantaScheduling
import SwiftData

/// A call the parent has booked for later.
///
/// `fireAt` is the record. Everything the screens show is derived from it, which
/// is what stops the vault and the confirmation screen from disagreeing — the
/// old version stored a display string like "Tonight, 6:30 PM" and nothing knew
/// what instant that meant.
///
/// The child is held by id *and* by name. The id is the link, so renaming a
/// child does not orphan their call; the name is a copy, so a notification that
/// outlives the child row can still say who it was for.
@Model
final class ScheduledCall {
    var id: UUID = UUID()
    var childID: UUID = UUID()
    var childName: String = ""
    var fireAt: Date = Date.now
    var topic: String = ""
    /// Captured at booking, not read live. With several children booked, Ben's
    /// audio call must not inherit whatever the global toggle happens to say at
    /// half past six.
    var wantsVideo: Bool = false
    var languageID: String = ""
    /// `ScheduleState.rawValue`. Stored as a string so a value added later does
    /// not renumber the ones already on disk.
    var stateRaw: String = ScheduleState.pending.rawValue
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        childID: UUID,
        childName: String,
        fireAt: Date,
        topic: String,
        wantsVideo: Bool,
        languageID: String,
        state: ScheduleState = .pending,
        createdAt: Date = .now
    ) {
        self.id = id
        self.childID = childID
        self.childName = childName
        self.fireAt = fireAt
        self.topic = topic
        self.wantsVideo = wantsVideo
        self.languageID = languageID
        self.stateRaw = state.rawValue
        self.createdAt = createdAt
    }
}

/// Where a booked call has got to.
///
/// A call that actually happened has no state here — its row is deleted, because
/// the recording is the record of it. Only the ones still owed, and the ones
/// nobody answered, survive.
enum ScheduleState: String, Sendable {
    case pending
    case missed
}

extension ScheduledCall {

    var state: ScheduleState {
        get { ScheduleState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var isPending: Bool { state == .pending }

    /// `Tonight · 6:30 PM`
    var whenLabel: String { ScheduleFormat.label(for: fireAt) }

    var detail: String {
        topic.isEmpty ? childName : "\(childName) · \(topic)"
    }

    /// What the notification and the deeplink carry.
    var linkPayload: CallLinkPayload {
        CallLinkPayload(
            scheduleID: id,
            childName: childName,
            topic: topic,
            wantsVideo: wantsVideo,
            languageID: languageID,
            fireAt: fireAt
        )
    }

    var slot: ScheduleSlot {
        ScheduleSlot(id: id, childName: childName, fireAt: fireAt)
    }
}
