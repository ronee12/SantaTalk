import AVFoundation

/// Where finished share files live.
///
/// Caches, not Application Support: an export is a copy of something already
/// kept safely, so it is exactly the kind of file iOS should be free to reclaim.
/// Nothing here survives a launch — the directory is emptied on the way in, so a
/// share abandoned at the system sheet does not sit on disk forever.
nonisolated enum ExportDirectory {

    static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShareExports", isDirectory: true)
    }

    static func prepare() -> URL {
        let directory = url
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func clean() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        ) else { return }
        for file in files { try? manager.removeItem(at: file) }
    }

    /// The name the parent sees in the share sheet, and in whatever they send it
    /// to. Worth getting right: "Santa call — 12 Dec 2025" reads as a keepsake,
    /// a UUID reads as a bug.
    static func file(title: String, dateLabel: String) -> URL {
        let name = "\(title) — \(dateLabel)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return prepare().appendingPathComponent("\(name).mp4")
    }
}

/// Runs one export and reports how far along it is.
///
/// `.mp4` rather than the `.mov` the call was recorded as: every app that
/// accepts a video accepts an mp4, and a fair number quietly refuse a mov.
@MainActor
final class RecordingExporter {

    enum Failure: Error {
        case cannotStart
    }

    private var session: AVAssetExportSession?

    var isExporting: Bool { session != nil }

    func export(
        _ share: ShareComposition,
        timeRange: CMTimeRange,
        to url: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(
            asset: share.composition, presetName: AVAssetExportPresetHighestQuality
        ) else { throw Failure.cannotStart }

        session.videoComposition = share.videoComposition
        session.timeRange = timeRange
        self.session = session
        defer { self.session = nil }

        try? FileManager.default.removeItem(at: url)

        // Progress is watched from its own task rather than `async let`, so the
        // session — which is not `Sendable` — is only ever touched from the main
        // actor. The encoding itself happens on AVFoundation's own threads.
        let watcher = Task { @MainActor in
            for await state in session.states(updateInterval: 0.2) {
                if case .exporting(let fraction) = state {
                    progress(fraction.fractionCompleted)
                }
            }
        }
        defer { watcher.cancel() }

        try await session.export(to: url, as: .mp4)
    }

    /// Leaves the partial file behind for the caller to remove — the exporter
    /// does not own the URL it was handed.
    func cancel() {
        session?.cancelExport()
        session = nil
    }
}
