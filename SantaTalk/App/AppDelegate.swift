import SantaScheduling
import SwiftUI
import UserNotifications

/// Exists for one reason: `UNUserNotificationCenter.delegate` has to be set
/// before iOS delivers a tap, and the only moment guaranteed to be early enough
/// is `didFinishLaunching`. A tap that launches the app cold arrives immediately
/// afterwards, so a delegate assigned later in a view's `task` would miss it.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationResponder.shared
        return true
    }
}

/// Turns a notification into a call, and decides what a notification is allowed
/// to look like while the app is open.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationResponder()

    /// The parent tapped it. Same path as an external `santatalk://` link — the
    /// `userInfo` carries the very URL that link would have been.
    /// `nonisolated` because the project builds with `MainActor` default
    /// isolation, and these arrive off it — the hop is made explicitly inside.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let payload = CallLink.payload(
            fromUserInfo: response.notification.request.content.userInfo
        ) else { return }

        await MainActor.run {
            CallLaunchInbox.shared.deliver(payload)
        }
    }

    /// Fired while the app is in front.
    ///
    /// The reminder still shows — it is for the parent, and it is the whole
    /// point. The call notification does not: the app is already about to ring
    /// on its own, and a banner sliding over the ringing screen would be the
    /// same call announced twice. During a live call nothing shows at all;
    /// interrupting a child mid-conversation with Santa is not something a
    /// second child's booking gets to do.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        let isReminder = identifier.hasPrefix("reminder-")

        let isBusy = await MainActor.run { CallLaunchInbox.shared.isCallInProgress }
        guard !isBusy else { return [] }

        return isReminder ? [.banner, .sound] : []
    }
}
