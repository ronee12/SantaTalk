import Foundation
import SwiftData

/// The parent's choices from the vault, and whether they have bought Pro.
///
/// Exactly one row exists; `ProfileStore.settings()` creates it on first launch.
/// A single row rather than loose keys keeps every preference in one place and
/// makes "delete the app, delete the data" a single truth rather than a sweep.
///
/// `isPro` here is a local mirror for what the UI shows. The claim that actually
/// unlocks calls lives on the Worker against the device id, so editing this
/// store buys nothing.
@Model
final class AppSettings {
    var isPro: Bool
    /// Unused. Santa has one ringtone now, so there is nothing to choose — the
    /// column stays only so an existing store needs no schema version.
    var ringtoneID: String
    var isRecordingEnabled: Bool
    var keepsReactionVideo: Bool
    /// Unused. The five-minute reminder is no longer optional. Kept for the same
    /// reason as `ringtoneID`.
    var remindsBeforeCall: Bool
    /// A `Language.id`, which is the English name. Santa speaks one language for
    /// the whole app rather than one per child. Empty until seeded — see
    /// `AppState.hydrate()`.
    var languageID: String = ""
    /// Which child the dashboard is set up to call. Nil until the first child
    /// exists, and re-pointed when the one it names is deleted.
    var activeChildID: UUID?
    /// How long the vault stays unlocked after the parent leaves it, in seconds.
    /// Zero re-asks every time.
    var lockGraceSeconds: Int = 120

    init(
        isPro: Bool = false,
        ringtoneID: String = "sleigh",
        isRecordingEnabled: Bool = true,
        keepsReactionVideo: Bool = true,
        remindsBeforeCall: Bool = true,
        languageID: String = "",
        activeChildID: UUID? = nil,
        lockGraceSeconds: Int = 120
    ) {
        self.isPro = isPro
        self.ringtoneID = ringtoneID
        self.isRecordingEnabled = isRecordingEnabled
        self.keepsReactionVideo = keepsReactionVideo
        self.remindsBeforeCall = remindsBeforeCall
        self.languageID = languageID
        self.activeChildID = activeChildID
        self.lockGraceSeconds = lockGraceSeconds
    }
}

/// The options behind "Ask again after" in the vault's Lock section.
///
/// There is deliberately no "Never": the gate is the only thing keeping a child
/// out of the recordings, the wish list and the paywall.
struct LockGrace: Identifiable, Hashable {
    let seconds: Int
    let label: String

    var id: Int { seconds }

    static let options: [LockGrace] = [
        .init(seconds: 0, label: "Immediately"),
        .init(seconds: 60, label: "1 minute"),
        .init(seconds: 120, label: "2 minutes"),
        .init(seconds: 300, label: "5 minutes"),
        .init(seconds: 900, label: "15 minutes")
    ]

    static func label(forSeconds seconds: Int) -> String {
        options.first { $0.seconds == seconds }?.label ?? "2 minutes"
    }
}
