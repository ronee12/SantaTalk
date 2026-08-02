import AVFoundation

/// A second of black, generated once and reused forever.
///
/// `AVVideoComposition` only calls its frame handler where a video track exists,
/// so the moments a shared video has to draw for itself — an audio-only call, a
/// hidden stretch, the beat before the camera woke up — still need *something*
/// occupying the timeline. This is that something. It is never seen: the
/// backdrop is painted over every pixel of it.
///
/// One second rather than one frame because a track has to be long enough to
/// survive the composition's frame rounding, and short enough that looping it
/// across a three-minute call stays cheap.
nonisolated enum FillerClip {

    enum Failure: Error {
        case cannotWrite
    }

    static let duration = CMTime(value: 1, timescale: 1)

    private static let frameRate: Int32 = 30

    private static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("share-filler.mov")
    }

    /// The cached clip's video track, generating the clip first if this is the
    /// first share on this install.
    static func track() async throws -> AVAssetTrack {
        let location = url
        if !FileManager.default.fileExists(atPath: location.path) {
            try await generate(at: location)
        }

        let asset = AVURLAsset(url: location)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            // A cached file that will not load is a cached file worth losing.
            try? FileManager.default.removeItem(at: location)
            throw Failure.cannotWrite
        }
        return track
    }

    private static func generate(at location: URL) async throws {
        try? FileManager.default.removeItem(at: location)

        let writer = try AVAssetWriter(outputURL: location, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(ExportGeometry.pixelSize.width),
            AVVideoHeightKey: Int(ExportGeometry.pixelSize.height)
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(ExportGeometry.pixelSize.width),
                kCVPixelBufferHeightKey as String: Int(ExportGeometry.pixelSize.height)
            ]
        )

        guard writer.canAdd(input) else { throw Failure.cannotWrite }
        writer.add(input)
        guard writer.startWriting() else { throw Failure.cannotWrite }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool, let buffer = blackBuffer(from: pool) else {
            writer.cancelWriting()
            throw Failure.cannotWrite
        }

        // The same buffer every frame. Nothing mutates it after this point, so
        // handing the encoder one picture thirty times is safe and the encoder
        // reduces the repeats to almost nothing.
        for frame in 0..<Int64(frameRate) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: frame, timescale: frameRate))
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: location)
            throw Failure.cannotWrite
        }
    }

    private static func blackBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        // Zeroing BGRA gives black. The alpha goes with it, which the H.264
        // encoder discards anyway.
        memset(base, 0, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        return buffer
    }
}
