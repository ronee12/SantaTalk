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
    let hasVideoTrack: Bool

    private let writer: AVAssetWriter
    private let audioInput: AVAssetWriterInput
    private let videoInput: AVAssetWriterInput?
    private let startTime: CMTime

    /// Appends arrive from the camera queue and from the mixer queue. Funnelling
    /// them through one serial queue is cheaper than reasoning about which
    /// `AVAssetWriter` calls are safe to interleave.
    private let queue = DispatchQueue(label: "com.santatalk.recording-writer")
    private var isFinished = false

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
            guard !isFinished, audioInput.isReadyForMoreMediaData,
                  let buffer = chunk.makeSampleBuffer() else { return }
            audioInput.append(buffer)
        }
    }

    /// Frames arriving while the encoder is behind are dropped rather than
    /// queued. A stalled writer must not grow memory during a live call.
    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [self] in
            guard !isFinished, let videoInput, videoInput.isReadyForMoreMediaData else { return }

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

            videoInput.append(retimed)
        }
    }

    /// Returns the finished file, or nil if the writer failed. The `sync` closes
    /// the queue behind every append already dispatched, so nothing is lost.
    func finish() async -> URL? {
        let alreadyFinished = queue.sync { () -> Bool in
            guard !isFinished else { return true }
            isFinished = true
            audioInput.markAsFinished()
            videoInput?.markAsFinished()
            return false
        }
        guard !alreadyFinished else { return nil }

        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }
}
