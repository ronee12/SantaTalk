import Foundation
import SwiftData
import SwiftUI

/// One child Santa knows, as answered during onboarding or typed into the vault.
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
///
/// There is a row per child. Onboarding writes the first one; the vault adds the
/// rest. Every new property carries a default so an install made before children
/// were separate rows migrates without a schema version.
@Model
final class ChildProfile {
    var id: UUID = UUID()
    var name: String
    var age: Int
    var interests: [String]
    /// Was the per-child language before Santa spoke one language for the whole
    /// app. Read once at launch to seed `AppSettings.languageID`, never written
    /// again — see `AppState.hydrate()`.
    var languageID: String
    /// True only once the parent has reached the hand-over screen.
    ///
    /// Answers are written as they are given, so a force-quit at step three keeps
    /// what was typed — but a half-finished profile must not convince the next
    /// launch that setup is done and drop the parent on the dashboard with a
    /// child Santa knows nothing about.
    var isSetupComplete: Bool
    /// Picks the avatar colour out of `Palette.childTints`, so the tint survives
    /// a relaunch instead of being reassigned by list position.
    var tintIndex: Int = 0
    /// Orders the list. Names change and ids sort arbitrarily, so neither can.
    var createdAt: Date = Date.now
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        interests: [String],
        languageID: String,
        isSetupComplete: Bool = false,
        tintIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.interests = interests
        self.languageID = languageID
        self.isSetupComplete = isSetupComplete
        self.tintIndex = tintIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - How a child reads in the vault

extension ChildProfile {

    /// The row's second line. Gender was never asked for, so age is all there is
    /// to say that the name does not already.
    var detail: String { "\(age) years old" }

    var tint: Color { Palette.childTint(at: tintIndex) }

    /// Name 20, age 15, up to three interests at 10 each — out of 65.
    ///
    /// The same weighting the onboarding meter uses, so a child set up in the
    /// vault and a child set up through onboarding score identically.
    var knowledgeScore: Int {
        (name.trimmed.isEmpty ? 0 : 20)
            + 15
            + min(3, interests.count) * 10
    }

    var knowledgePercent: Int {
        Int((Double(knowledgeScore) / 65 * 100).rounded())
    }
}
