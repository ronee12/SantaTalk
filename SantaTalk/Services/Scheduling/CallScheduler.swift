import Foundation
import SantaScheduling
import UserNotifications

/// Owns everything between "the parent booked a call" and "the phone rings".
///
/// Two independent paths lead to the same place, because neither alone is
/// enough. Notifications cover the app being closed; a foreground timer covers
/// the app being open, where iOS would otherwise show a banner over a screen
/// that should simply start ringing. Both call `onDue`, which is idempotent —
/// whichever arrives first wins and the other is a no-op.
@MainActor
final class CallScheduler {

    /// Called with the id of a call that should ring now.
    var onDue: ((UUID) -> Void)?

    private let authority: NotificationAuthority
    private var timerTask: Task<Void, Never>?
    /// Cleared when the app comes back, so a call handled while backgrounded is
    /// not re-fired by the timer on the way in.
    private var firedIDs: Set<UUID> = []

    /// The default is built here rather than in the parameter list: a default
    /// argument is evaluated in a nonisolated context, and
    /// `SystemNotificationAuthority` is `MainActor`-bound. Nil means "the real
    /// one"; tests pass their own.
    init(authority: NotificationAuthority? = nil) {
        self.authority = authority ?? SystemNotificationAuthority()
    }

    // MARK: Permission

    func authorizationState() async -> PermissionState {
        await authority.authorizationState()
    }

    func requestAuthorization() async -> Bool {
        await authority.requestAuthorization()
    }

    // MARK: Notifications

    /// Books the reminder and the call itself.
    ///
    /// The reminder is skipped when the call is sooner than the lead time —
    /// iOS would silently drop a request dated in the past, and the parent would
    /// have been promised a reminder that never comes.
    func arm(_ call: ScheduledCall, now: Date = .now) async {
        disarm(callID: call.id)

        let payload = call.linkPayload
        let userInfo = CallLink.userInfo(for: payload)

        if let reminderAt = ScheduleWindow.reminderDate(forCallAt: call.fireAt, now: now) {
            await add(
                identifier: Self.reminderIdentifier(call.id),
                title: "Santa calls \(call.childName) in five minutes",
                body: "Time to get the phone into the right hands.",
                fireAt: reminderAt,
                userInfo: userInfo
            )
        }

        await add(
            identifier: Self.callIdentifier(call.id),
            title: "Santa is calling \(call.childName)!",
            body: call.topic.isEmpty ? "Tap to answer." : "He wants to talk about \(call.topic.lowercasedFirst).",
            fireAt: call.fireAt,
            userInfo: userInfo
        )
    }

    func disarm(callID: UUID) {
        authority.removeRequests(withIdentifiers: [
            Self.reminderIdentifier(callID),
            Self.callIdentifier(callID)
        ])
    }

    /// Re-books every pending call from scratch.
    ///
    /// Cheaper to reason about than patching: the store is the truth, and after
    /// this the notification centre says exactly what the store says. Called at
    /// launch and whenever the list changes.
    func rearmAll(_ calls: [ScheduledCall], now: Date = .now) async {
        authority.removeAllRequests()
        for call in calls where call.isPending && call.fireAt > now {
            await arm(call, now: now)
        }
    }

    private func add(
        identifier: String,
        title: String,
        body: String,
        fireAt: Date,
        userInfo: [String: String]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        // Calendar rather than an interval, so a call booked for 6:30 stays at
        // 6:30 across a clock change rather than sliding by an hour.
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        await authority.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    static func reminderIdentifier(_ id: UUID) -> String { "reminder-\(id.uuidString)" }
    static func callIdentifier(_ id: UUID) -> String { "call-\(id.uuidString)" }

    // MARK: The foreground timer

    /// Sleeps until the next call is due, then reports it.
    ///
    /// Only the earliest is waited on; the run re-arms itself afterwards, so a
    /// list of five calls needs one sleeping task rather than five.
    func restartTimer(for calls: [ScheduledCall], now: Date = .now) {
        timerTask?.cancel()

        let pending = calls
            .filter { $0.isPending }
            .filter { ScheduleWindow.standing(fireAt: $0.fireAt, now: now) != .missed }
            .filter { !firedIDs.contains($0.id) }
            .sorted { $0.fireAt < $1.fireAt }

        guard let next = pending.first else { return }

        let delay = max(0, next.fireAt.timeIntervalSince(now))
        let id = next.id

        timerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.firedIDs.insert(id)
            self.onDue?(id)
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Forgets what has already fired, so returning to the foreground can arm
    /// the timer again without a stale id suppressing a call that is still due.
    func clearFiredMarks() {
        firedIDs.removeAll()
    }
}

private extension String {
    /// "The Christmas wish list" → "the Christmas wish list", for the middle of
    /// a sentence.
    var lowercasedFirst: String {
        isEmpty ? self : prefix(1).lowercased() + dropFirst()
    }
}
