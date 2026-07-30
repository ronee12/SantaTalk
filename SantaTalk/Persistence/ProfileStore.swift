import Foundation
import SwiftData

/// The app's whole local store, behind three calls.
///
/// Everything it touches stays on the device and goes when the app goes. Nothing
/// here is ever uploaded — `BackendClient` sends a device id and a language code
/// and knows about none of these types.
@MainActor
struct ProfileStore {
    let context: ModelContext

    /// The saved child, or nil if onboarding has never been completed. Its
    /// presence is what tells the app setup is done.
    func profile() -> ChildProfile? {
        try? context.fetch(FetchDescriptor<ChildProfile>()).first
    }

    /// The settings row, created on first launch so callers never deal with nil.
    func settings() -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }

    /// The profile, creating an empty one to fill in if this is the first save.
    func profileForWriting() -> ChildProfile {
        if let existing = profile() { return existing }
        let created = ChildProfile(name: "", age: 0, interests: [], secret: "", languageID: "")
        context.insert(created)
        return created
    }

    /// SwiftData autosaves, but onboarding answers and a bought subscription are
    /// both things a force-quit must not lose, so writes are flushed explicitly.
    func commit() {
        try? context.save()
    }
}
