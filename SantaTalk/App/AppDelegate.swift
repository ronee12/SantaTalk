import FirebaseAppCheck
import FirebaseCore
import SantaScheduling
import SwiftUI
import UserNotifications

/// Exists for two reasons, both of them about being early enough.
///
/// `UNUserNotificationCenter.delegate` has to be set before iOS delivers a tap,
/// and the only moment guaranteed to be early enough is `didFinishLaunching`. A
/// tap that launches the app cold arrives immediately afterwards, so a delegate
/// assigned later in a view's `task` would miss it.
///
/// Firebase has the same shape of problem one level down — see `configureFirebase()`.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureFirebase()
        // Same reasoning as Firebase: `Purchases.shared` traps if it is read
        // before this call, and the paywall's `.task` can run before any other
        // setup point would have been reached.
        SubscriptionRepository.configure()
        UNUserNotificationCenter.current().delegate = NotificationResponder.shared
        return true
    }

    /// Firebase is here for one job: call summaries go to Gemini through
    /// Firebase AI Logic. Nothing else in the app reads or writes Firebase, and
    /// no child data is stored there.
    ///
    /// Order is the whole point of this method. The App Check provider factory
    /// must be installed *before* `configure()`, because the first token request
    /// happens during configuration — set it afterwards and that request has
    /// already gone out under the default provider.
    ///
    /// The debug provider prints a token to the Xcode console on first run. It
    /// has to be pasted into Firebase Console → App Check → Manage debug tokens
    /// once per machine, or every simulator run is rejected. That is a person's
    /// job, not this method's.
    private func configureFirebase() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif

        // `GoogleService-Info.plist` lives in `Support/` and is bundled by the
        // project's synchronized file group, so there is no plist path to pass.
        FirebaseApp.configure()
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
