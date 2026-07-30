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
    var ringtoneID: String
    var isRecordingEnabled: Bool
    var keepsReactionVideo: Bool
    var remindsBeforeCall: Bool

    init(
        isPro: Bool = false,
        ringtoneID: String = "sleigh",
        isRecordingEnabled: Bool = true,
        keepsReactionVideo: Bool = true,
        remindsBeforeCall: Bool = true
    ) {
        self.isPro = isPro
        self.ringtoneID = ringtoneID
        self.isRecordingEnabled = isRecordingEnabled
        self.keepsReactionVideo = keepsReactionVideo
        self.remindsBeforeCall = remindsBeforeCall
    }
}
