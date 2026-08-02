import AVFoundation
import CoreImage

/// A recorded call, rebuilt as the video it looked like.
///
/// The saved `.mov` is the child's face and both voices — it has never contained
/// Santa's half of the *picture*, because there is no Santa video, only a
/// portrait and a layout. Sharing the file directly therefore sends a bare
/// close-up of a child, which is not what the call looked like to anyone.
///
/// This assembles the missing half: one composition holding the conversation and
/// whatever camera there was, and one `AVVideoComposition` that draws the stage
/// around it. The same pair drives both the preview on the trim screen and the
/// export, so what a parent watches before sharing is made by the code that
/// makes what they share.
nonisolated struct ShareComposition: @unchecked Sendable {

    enum Failure: Error {
        case noAudio
        case cannotBuildArtwork
        case cannotAssemble
    }

    let composition: AVComposition
    let videoComposition: AVVideoComposition
    /// The full length of the call, which is the length of its audio.
    let duration: CMTime
    /// Nil when the call was audio-only — the trim strip uses this for thumbnails.
    let cameraTrack: AVAssetTrack?

    static func build(url: URL, childName: String, showsWordmark: Bool) async throws -> ShareComposition {
        let artwork = await StageArtwork.render(childName: childName, showsWordmark: showsWordmark)
        guard let artwork else { throw Failure.cannotBuildArtwork }

        let asset = AVURLAsset(url: url)
        let assetDuration = try await asset.load(.duration)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw Failure.noAudio
        }

        // The audio is the call. Video is decoration that starts late, stops
        // when the child hides, and may not exist at all.
        let audioRange = CMTimeRangeGetIntersection(
            try await audioTrack.load(.timeRange),
            otherRange: CMTimeRange(start: .zero, duration: assetDuration)
        )
        guard audioRange.duration > .zero else { throw Failure.noAudio }
        let duration = audioRange.end

        let composition = AVMutableComposition()
        guard
            let compositionAudio = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compositionVideo = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.cannotAssemble }

        try compositionAudio.insertTimeRange(audioRange, of: audioTrack, at: audioRange.start)

        let cameraTrack = try await asset.loadTracks(withMediaType: .video).first
        let coverage: CameraCoverage
        if let cameraTrack {
            coverage = await CameraCoverage.scan(track: cameraTrack, asset: asset, limit: duration)
        } else {
            coverage = .none
        }

        try await fill(
            compositionVideo,
            to: duration,
            with: cameraTrack,
            covering: coverage
        )

        let tileRect = ExportGeometry.tileRectInPixels
        let frameRect = ExportGeometry.frameRect

        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            with: composition
        ) { request in
            let frame = coverage.contains(request.compositionTime)
                ? compose(camera: request.sourceImage, artwork: artwork, tileRect: tileRect)
                : artwork.placeholderFrame

            request.finish(with: frame.cropped(to: frameRect), context: nil)
        }
        videoComposition.renderSize = ExportGeometry.pixelSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        return ShareComposition(
            composition: composition,
            videoComposition: videoComposition,
            duration: duration,
            cameraTrack: cameraTrack
        )
    }

    // MARK: Building the timeline

    /// Lays the camera down where it was running and black filler everywhere
    /// else, so the video track covers the call end to end with no gaps for a
    /// player to freeze across.
    private static func fill(
        _ track: AVMutableCompositionTrack,
        to duration: CMTime,
        with camera: AVAssetTrack?,
        covering coverage: CameraCoverage
    ) async throws {
        let filler = try await FillerClip.track()

        func insertFiller(from start: CMTime, to end: CMTime) throws {
            var cursor = start
            while cursor < end {
                let chunk = CMTimeMinimum(FillerClip.duration, end - cursor)
                try track.insertTimeRange(
                    CMTimeRange(start: .zero, duration: chunk), of: filler, at: cursor
                )
                cursor = cursor + chunk
            }
        }

        var cursor = CMTime.zero
        if let camera {
            for range in coverage.ranges where range.end > cursor {
                let start = CMTimeMaximum(range.start, cursor)
                if start > cursor { try insertFiller(from: cursor, to: start) }

                let segment = CMTimeRange(start: start, end: CMTimeMinimum(range.end, duration))
                if segment.duration > .zero {
                    try track.insertTimeRange(segment, of: camera, at: start)
                    cursor = segment.end
                }
            }
        }
        if cursor < duration { try insertFiller(from: cursor, to: duration) }
    }

    // MARK: Drawing one frame

    /// Camera frames are 720×1280 and the tile is not that shape, so the frame
    /// is scaled to *fill* — matching the player's `resizeAspectFill` — centred,
    /// and then cut to the tile's rounded corners by the alpha mask.
    private static func compose(
        camera: CIImage, artwork: StageArtwork, tileRect: CGRect
    ) -> CIImage {
        let source = camera.extent
        guard source.width > 0, source.height > 0 else { return artwork.placeholderFrame }

        let scale = max(tileRect.width / source.width, tileRect.height / source.height)
        let scaled = camera.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centred = scaled.transformed(by: CGAffineTransform(
            translationX: tileRect.midX - scaled.extent.midX,
            y: tileRect.midY - scaled.extent.midY
        ))

        let inTile = centred.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: artwork.backdrop,
            kCIInputMaskImageKey: artwork.tileMask
        ])

        return artwork.chrome.composited(over: inTile)
    }
}
