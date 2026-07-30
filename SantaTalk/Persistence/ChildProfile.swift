import Foundation
import SwiftData

/// The child this phone belongs to, as answered during onboarding.
///
/// This is the only place any of it is written down. None of it reaches
/// santa_backend — the Worker stores a device id, a timestamp and a language
/// code, and a test fails the build if a column that could hold child data is
/// ever added. It reaches ElevenLabs only as dynamic variables, at the moment of
/// a call, straight from the device.
///
/// Living in SwiftData rather than the Keychain is deliberate: deleting the app
/// must take every detail about the child with it. The one exception is the
/// device id — see `DeviceIdentity` for why that outlives an uninstall.
@Model
final class ChildProfile {
    var name: String
    var age: Int
    var interests: [String]
    /// The "one thing only you would know" detail. The most sensitive field the
    /// app holds, and the one the whole product hangs on.
    var secret: String
    /// A `Language.id`, which is the English name. Resolved back through `Catalog`.
    var languageID: String
    /// True only once the parent has reached the hand-over screen.
    ///
    /// Answers are written as they are given, so a force-quit at step three keeps
    /// what was typed — but a half-finished profile must not convince the next
    /// launch that setup is done and drop the parent on the dashboard with a
    /// child Santa knows nothing about.
    var isSetupComplete: Bool
    var updatedAt: Date

    init(
        name: String,
        age: Int,
        interests: [String],
        secret: String,
        languageID: String,
        isSetupComplete: Bool = false,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.age = age
        self.interests = interests
        self.secret = secret
        self.languageID = languageID
        self.isSetupComplete = isSetupComplete
        self.updatedAt = updatedAt
    }
}
