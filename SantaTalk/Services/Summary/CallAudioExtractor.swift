import AVFoundation

/// Pulls the audio out of a recorded call, leaving the video behind.
///
/// Calls are written as `.mov` with an H.264 camera track alongside the voices
/// (`RecordingWriter`). A summary needs none of the picture, and sending it
/// would cost a great deal for nothing — so the child's face never leaves the
/// phone on this path.
///
/// The export is `AVAssetExportPresetPassthrough`: the AAC that is already on
/// disk is re-muxed into an `.m4a` container rather than re-encoded. That makes
/// it near-instant and lossless, and it means the size is predictable — the
/// writer records at 64 kbps, so a five-minute call is about 2.4 MB.
///
/// `@MainActor` for the same reason as `RecordingExporter`: `AVAssetExportSession`
/// is not `Sendable`, so it stays in one isolation domain. The encoding runs on
/// AVFoundation's own threads and the `await` does not block anything.
@MainActor
enum CallAudioExtractor {

    enum Failure: Error {
        /// The file exists but has no audio — a recording that captured only
        /// picture, or one truncated mid-write.
        case noAudioTrack
        case cannotStart
        /// Longer than the model will accept in one request.
        case tooLong
    }

    /// Firebase caps inline data at 20 MB for the whole request, and the SDK
    /// base64-encodes the bytes on the way out — which costs a third on top. This
    /// is the largest payload that still fits under the cap once encoded, and at
    /// 64 kbps it is close to half an hour of call.
    static let maximumBytes = 14_000_000

    static func audio(from url: URL) async throws -> Data {
        let asset = AVURLAsset(url: url)

        guard let source = try await asset.loadTracks(withMediaType: .audio).first else {
            throw Failure.noAudioTrack
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw Failure.cannotStart }

        // The source track's own range, not the asset's: on a recording whose
        // writer was cut short the two disagree, and the asset's duration would
        // ask for time the track cannot supply.
        let range = try await source.load(.timeRange)
        try track.insertTimeRange(range, of: source, at: .zero)

        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetPassthrough
        ) else { throw Failure.cannotStart }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("summary-\(UUID().uuidString).m4a")

        // The extracted audio is a means, not a keepsake. It goes as soon as it
        // has been read, whether or not the read worked.
        defer { try? FileManager.default.removeItem(at: output) }

        try await session.export(to: output, as: .m4a)

        let data = try Data(contentsOf: output, options: .mappedIfSafe)
        guard data.count <= maximumBytes else { throw Failure.tooLong }

        // `mappedIfSafe` hands back a window onto a file this method is about to
        // delete. Copying is what makes the returned bytes outlive the `defer`.
        return Data(data)
    }
}
