import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` the scheduler uses.
///
/// A protocol rather than the singleton directly, so `CallScheduler` can be
/// exercised without the system asking a real person for permission.
@MainActor
protocol NotificationAuthority: AnyObject {
    func authorizationState() async -> PermissionState
    func requestAuthorization() async -> Bool
    func add(_ request: UNNotificationRequest) async
    func removeRequests(withIdentifiers identifiers: [String])
    func removeAllRequests()
}

/// The real one.
@MainActor
final class SystemNotificationAuthority: NotificationAuthority {

    private let center = UNUserNotificationCenter.current()

    /// Asked rather than remembered. iOS keeps the answer across launches and
    /// reinstalls, and a stored copy is the thing that tells a parent
    /// notifications are off when they have been on for a week — the same reason
    /// the microphone and camera are re-read at launch.
    func authorizationState() async -> PermissionState {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .idle
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .idle
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func add(_ request: UNNotificationRequest) async {
        try? await center.add(request)
    }

    func removeRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllRequests() {
        center.removeAllPendingNotificationRequests()
    }
}
