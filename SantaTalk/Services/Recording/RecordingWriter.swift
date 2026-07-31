import AVFoundation
import CoreMedia
import SantaAudioMixer

/// One file, two tracks, one timeline.
///
/// Both tracks are rebased against a single recording start, which is what keeps
/// the child's face and the conversation in step. Video timestamps arrive on the
/// host clock — the same clock `CACurrentMediaTime()` reads — so the two can be
/// subtracted directly.
///
/// Explicitly `nonisolated` because `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// would otherwise pull this unannotated class onto the main actor — defeating
/// the entire point of a writer that must be callable from the camera's
/// background queue and the mixer's queue without a main-actor hop.
nonisolated final class RecordingWriter: @unchecked Sendable {

    enum Failure: Error {
        case cannotStart
    }

    let url: URL

    /// Whether the finished file actually contains a usable video track.
    ///
    /// True from init if a video input was successfully added — that's all
    /// `start()` needs to know when deciding whether to wire up camera frames.
    /// But if the camera never delivered a single frame (session failed to
    /// start, access revoked mid-call, every frame dropped), `finish()` flips
    /// this to `false` before anyone reads it again: a video input that never
    /// received a sample must not be staked against, since this value is
    /// stored in the database and decides whether the player shows a video
    /// tile or an "audio only" placeholder. The mutation happens inside
    /// `finish()`'s `queue.sync`, and every external read of this property
    /// happens strictly after that call returns, so no additional locking is
    /// needed for the handoff.
    private(set) var hasVideoTrack: Bool

    private let writer: AVAssetWriter
    private let audioInput: AVAssetWriterInput
    private let videoInput: AVAssetWriterInput?
    private let startTime: CMTime

    /// Appends arrive from the camera queue and from the mixer queue. Funnelling
    /// them through one serial queue is cheaper than reasoning about which
    /// `AVAssetWriter` calls are safe to interleave.
    private let queue = DispatchQueue(label: "com.santatalk.recording-writer")
    private var isFinished = false

    /// Set on the queue the first time `appendVideo` actually hands a sample
    /// to the video input. A video track with no samples is what Defect 1
    /// guards against.
    private var hasAppendedVideoSample = false

    init(url: URL, startTime: TimeInterval, videoEnabled: Bool) throws {
        self.url = url
        self.startTime = CMTime(seconds: startTime, preferredTimescale: 1_000_000_000)

        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000
        ])
        audioInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(audioInput) else { throw Failure.cannotStart }
        writer.add(audioInput)

        if videoEnabled {
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_500_000]
            ])
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                videoInput = input
            } else {
                videoInput = nil
            }
        } else {
            videoInput = nil
        }

        hasVideoTrack = videoInput != nil

        guard writer.startWriting() else { throw Failure.cannotStart }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ chunk: MixedAudioChunk) {
        queue.async { [self] in
            // `AVAssetWriterInput.append(_:)` is documented as unsafe to call
            // once the writer has left `.writing` — a failed writer must stop
            // being fed, not silently no-op call after call.
            guard !isFinished, writer.status == .writing,
                  audioInput.isReadyForMoreMediaData,
                  let buffer = chunk.makeSampleBuffer() else { return }
            audioInput.append(buffer)
        }
    }

    /// Frames arriving while the encoder is behind are dropped rather than
    /// queued. A stalled writer must not grow memory during a live call.
    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [self] in
            guard !isFinished, writer.status == .writing,
                  let videoInput, videoInput.isReadyForMoreMediaData else { return }

            let presentation = CMTimeSubtract(sampleBuffer.presentationTimeStamp, startTime)
            guard presentation >= .zero else { return }

            var timing = CMSampleTimingInfo(
                duration: sampleBuffer.duration,
                presentationTimeStamp: presentation,
                decodeTimeStamp: .invalid
            )
            var retimed: CMSampleBuffer?
            guard CMSampleBufferCreateCopyWithNewTiming(
                allocator: kCFAllocatorDefault,
                sampleBuffer: sampleBuffer,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleBufferOut: &retimed
            ) == noErr, let retimed else { return }

            if videoInput.append(retimed) {
                hasAppendedVideoSample = true
            }
        }
    }

    /// Returns the finished file, or nil if the writer failed. The `sync` closes
    /// the queue behind every append already dispatched, so nothing is lost.
    func finish() async -> URL? {
        let alreadyFinished = queue.sync { () -> Bool in
            guard !isFinished else { return true }
            isFinished = true
            audioInput.markAsFinished()
            if videoInput != nil {
                // A video track that never received a sample must not be
                // trusted downstream, even though it may still exist as an
                // empty descriptor in the container — staking a good audio
                // recording on it is exactly the bug this guards against.
                if !hasAppendedVideoSample {
                    hasVideoTrack = false
                }
                videoInput?.markAsFinished()
            }
            return false
        }
        guard !alreadyFinished else { return nil }

        await writer.finishWriting()

        guard writer.status == .completed else {
            // A partial `.mov` from a writer that didn't complete is worse
            // than no file: nobody else knows to clean it up.
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }
}
