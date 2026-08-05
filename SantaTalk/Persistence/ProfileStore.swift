import Foundation
import SwiftData

/// The app's whole local store, behind a handful of calls.
///
/// Everything it touches stays on the device and goes when the app goes. Nothing
/// here is ever uploaded — `BackendClient` sends a device id and a language code
/// and knows about none of these types.
@MainActor
struct ProfileStore {
    let context: ModelContext

    /// Every child Santa knows, oldest first, so the list does not reorder itself
    /// when a name is edited.
    func children() -> [ChildProfile] {
        let descriptor = FetchDescriptor<ChildProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The first child, or nil if onboarding has never been completed. Its
    /// presence is what tells the app setup is done.
    func profile() -> ChildProfile? {
        children().first
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

    /// The first child, creating an empty one to fill in if this is the first
    /// save. This is onboarding's row — the vault adds the rest through `add`.
    func profileForWriting() -> ChildProfile {
        if let existing = profile() { return existing }
        let created = ChildProfile(name: "", age: 0, interests: [], languageID: "")
        context.insert(created)
        return created
    }

    /// Adds a child from the vault. The tint cycles through the palette by
    /// position so two children rarely land on the same colour.
    @discardableResult
    func add(name: String, age: Int, interests: [String]) -> ChildProfile {
        let created = ChildProfile(
            name: name,
            age: age,
            interests: interests,
            languageID: "",
            isSetupComplete: true,
            tintIndex: children().count
        )
        context.insert(created)
        commit()
        return created
    }

    func delete(_ child: ChildProfile) {
        context.delete(child)
        commit()
    }

    /// SwiftData autosaves, but onboarding answers and a bought subscription are
    /// both things a force-quit must not lose, so writes are flushed explicitly.
    func commit() {
        try? context.save()
    }
}
