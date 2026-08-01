import Foundation
import SantaScheduling
import SwiftData

/// Booked calls, on disk.
///
/// Same shape as `ProfileStore` and `RecordingStore`: the only thing that knows
/// how these rows are fetched and written, so nothing above it holds a
/// `ModelContext`.
@MainActor
struct ScheduleStore {
    let context: ModelContext

    /// Soonest first, which is the order both the vault list and the "what fires
    /// next" question want.
    func all() -> [ScheduledCall] {
        let descriptor = FetchDescriptor<ScheduledCall>(
            sortBy: [SortDescriptor(\.fireAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func call(id: UUID) -> ScheduledCall? {
        all().first { $0.id == id }
    }

    @discardableResult
    func add(
        childID: UUID,
        childName: String,
        fireAt: Date,
        topic: String,
        wantsVideo: Bool,
        languageID: String
    ) -> ScheduledCall {
        let created = ScheduledCall(
            childID: childID,
            childName: childName,
            fireAt: fireAt,
            topic: topic,
            wantsVideo: wantsVideo,
            languageID: languageID
        )
        context.insert(created)
        commit()
        return created
    }

    func delete(_ call: ScheduledCall) {
        context.delete(call)
        commit()
    }

    func delete(ids: [UUID]) {
        let doomed = all().filter { ids.contains($0.id) }
        for call in doomed { context.delete(call) }
        commit()
    }

    func markMissed(_ call: ScheduledCall) {
        call.state = .missed
        commit()
    }

    /// Catches up the rows whose moment passed while the app was closed.
    ///
    /// A local notification fires whether or not anyone is looking, so the app
    /// can come back to calls that are hours stale. Returns the ones it just
    /// marked, so the dashboard can mention them.
    @discardableResult
    func sweepExpired(now: Date = .now) -> [ScheduledCall] {
        let expired = all().filter {
            $0.isPending && ScheduleWindow.standing(fireAt: $0.fireAt, now: now) == .missed
        }
        for call in expired { call.state = .missed }
        if !expired.isEmpty { commit() }
        return expired
    }

    /// Drops missed calls nobody acted on. They exist to be mentioned once, not
    /// to accumulate into a list of every evening that got away.
    func purgeStaleMissed(now: Date = .now, olderThan age: TimeInterval = 7 * 24 * 60 * 60) {
        let stale = all().filter { $0.state == .missed && now.timeIntervalSince($0.fireAt) > age }
        for call in stale { context.delete(call) }
        if !stale.isEmpty { commit() }
    }

    func commit() {
        try? context.save()
    }
}
