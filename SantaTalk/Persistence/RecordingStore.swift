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

    func delete(_ recording: CallRecording) {
        try? FileManager.default.removeItem(at: url(for: recording))
        context.delete(recording)
        try? context.save()
    }
}
