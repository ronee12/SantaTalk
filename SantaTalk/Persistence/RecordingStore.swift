import Foundation
import SwiftData

/// Recordings, both halves of them: the row in SwiftData and the file on disk.
///
/// Keeping both behind one type is what makes deletion honest — a row removed
/// without its file leaves megabytes the parent thinks they deleted.
@MainActor
struct RecordingStore {
    let context: ModelContext

    /// `Application Support/Recordings/`, created on demand and kept out of
    /// backups. Recordings are large, local, and re-creatable only by living the
    /// moment again — but the promise made to the parent is that they stay on
    /// this phone, and a backup is another copy somewhere else.
    static var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var url = base
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return base
    }

    func all() -> [CallRecording] {
        let descriptor = FetchDescriptor<CallRecording>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func url(for recording: CallRecording) -> URL {
        Self.directory.appendingPathComponent(recording.filename)
    }

    /// Moves a finished recording out of the temporary directory and records it.
    /// Returns nil if the move fails — better no row than a row pointing at
    /// nothing.
    func save(
        movingFrom source: URL,
        childName: String,
        title: String,
        startedAt: Date,
        durationSeconds: Int,
        hasVideo: Bool
    ) -> CallRecording? {
        let id = UUID()
        let filename = "\(id.uuidString).\(source.pathExtension)"
        let destination = Self.directory.appendingPathComponent(filename)

        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: source)
            return nil
        }

        let recording = CallRecording(
            id: id,
            childName: childName,
            title: title,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            hasVideo: hasVideo,
            filename: filename
        )
        context.insert(recording)
        try? context.save()
        return recording
    }

    /// Deletes a recording's file and its row together, or deletes neither.
    ///
    /// The file is removed first. A file that is already gone
    /// (`CocoaError.fileNoSuchFile`) counts as success — there is nothing left
    /// to orphan, so the row is deleted too. Any other removal failure
    /// (permissions, disk error, ...) is thrown, and the row is left in place:
    /// a row that survives a failed delete can be retried or surfaced to the
    /// parent, but a row that vanishes while its file survives on disk is
    /// exactly the "megabytes the parent thinks they deleted" outcome this
    /// type exists to prevent.
    func delete(_ recording: CallRecording) throws {
        do {
            try FileManager.default.removeItem(at: url(for: recording))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // Already gone — nothing to orphan.
        }
        context.delete(recording)
        try context.save()
    }

    /// Empties the library, for "Delete all recordings" in the vault.
    ///
    /// Deliberately not all-or-nothing: a single file that will not delete must
    /// not strand the other forty. Each recording is removed on the same terms
    /// `delete` uses, the failures are counted, and their rows are left behind so
    /// the parent can see what survived and try again. Returns how many refused
    /// to go.
    @discardableResult
    func deleteAll() -> Int {
        var failed = 0
        for recording in all() {
            do {
                try delete(recording)
            } catch {
                failed += 1
            }
        }
        return failed
    }
}
