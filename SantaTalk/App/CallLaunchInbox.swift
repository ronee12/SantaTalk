import Foundation
import SantaScheduling

/// Holds a tapped call until something is ready to act on it.
///
/// A notification tapped from a cold start arrives before `AppState` exists, let
/// alone before the store has been read. Without somewhere to park it the tap is
/// simply lost and the app opens on the dashboard as if nothing happened. The
/// delegate drops the payload here; `AppState` drains it once it has hydrated.
@MainActor
final class CallLaunchInbox {

    static let shared = CallLaunchInbox()

    private var pending: CallLinkPayload?
    /// Set once `AppState` is listening, so a tap while the app is already
    /// running goes straight through instead of waiting for a drain that has
    /// already happened.
    var onArrival: ((CallLinkPayload) -> Void)?
    /// Mirrors whether a call is live, so the notification delegate can suppress
    /// banners without reaching into `AppState` — the delegate is created by
    /// `UIApplicationDelegate` and has no route to the environment.
    var isCallInProgress: Bool = false

    private init() {}

    func deliver(_ payload: CallLinkPayload) {
        if let onArrival {
            onArrival(payload)
        } else {
            pending = payload
        }
    }

    func deliver(url: URL) {
        guard let payload = CallLink.payload(from: url) else { return }
        deliver(payload)
    }

    /// Takes whatever arrived before anyone was listening. Returns it once and
    /// then forgets it — a tap must not start the same call twice.
    func drain() -> CallLinkPayload? {
        defer { pending = nil }
        return pending
    }
}
