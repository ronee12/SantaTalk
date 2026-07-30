import AVFoundation
import Testing
@testable import SantaAudioMixer

@Suite("AudioTimelineMixer")
struct AudioTimelineMixerTests {

    private func buffer(frames: AVAudioFrameCount, value: Float) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: PCMResampler.canonicalFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        for frame in 0 ..< Int(frames) { buffer.floatChannelData![0][frame] = value }
        return buffer
    }

    /// A non-interleaved buffer of `frames` frames in `format`, with each
    /// channel filled from its own array in `channelValues` (indexed
    /// `[channel][frame]`) — distinct per-channel, per-frame values so a wrong
    /// per-channel offset lands on a visibly wrong value rather than a
    /// coincidentally correct one.
    private func makeNonInterleavedBuffer(format: AVAudioFormat, frames: Int, channelValues: [[Float]]) -> AVAudioPCMBuffer {
        precondition(!format.isInterleaved)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)

        if let float = buffer.floatChannelData {
            for channel in 0 ..< channelValues.count {
                for frame in 0 ..< frames { float[channel][frame] = channelValues[channel][frame] }
            }
        } else if let int16 = buffer.int16ChannelData {
            for channel in 0 ..< channelValues.count {
                for frame in 0 ..< frames { int16[channel][frame] = Int16(channelValues[channel][frame] * 32767) }
            }
        }
        return buffer
    }

    /// An interleaved buffer of `frames` frames in `format`, with per-frame,
    /// per-channel values from `frameValues` (indexed `[frame][channel]`),
    /// laid out in true interleaved order — `[f0c0, f0c1, f1c0, f1c1, …]` —
    /// via the single channel pointer `AVAudioPCMBuffer` exposes for
    /// interleaved data. Values vary frame-to-frame so a wrong interleaved
    /// stride (e.g. mistaking this for non-interleaved, or under/over-counting
    /// samples) lands on visibly wrong values instead of a coincidentally
    /// correct average.
    private func makeInterleavedBuffer(format: AVAudioFormat, frames: Int, frameValues: [[Float]]) -> AVAudioPCMBuffer {
        precondition(format.isInterleaved)
        let channelCount = Int(format.channelCount)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)

        if let float = buffer.floatChannelData {
            for frame in 0 ..< frames {
                for channel in 0 ..< channelCount {
                    float[0][frame * channelCount + channel] = frameValues[frame][channel]
                }
            }
        } else if let int16 = buffer.int16ChannelData {
            for frame in 0 ..< frames {
                for channel in 0 ..< channelCount {
                    int16[0][frame * channelCount + channel] = Int16(frameValues[frame][channel] * 32767)
                }
            }
        }
        return buffer
    }

    /// Collects everything the mixer emits, in order.
    ///
    /// The sink now runs on the mixer's own serial queue rather than on the
    /// caller's thread (see `accept`/`flush` using `queue.async`), so appends
    /// from the mixer's queue can race reads from the test's thread. The lock
    /// makes both sides of that race safe.
    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [MixedAudioChunk] = []

        var chunks: [MixedAudioChunk] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        var sink: @Sendable (MixedAudioChunk) -> Void {
            { [self] chunk in
                lock.lock()
                storage.append(chunk)
                lock.unlock()
            }
        }

        var frameCount: Int { chunks.reduce(0) { $0 + $1.samples.count } }
    }

    @Test("a buffer is placed by when it arrived, not when it was flushed")
    func placesBufferByArrivalTime() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 100, sink: collector.sink)

        // One second of audio that finished arriving one second in.
        mixer.accept(buffer(frames: 48_000, value: 0.5), from: .child, arrivedAt: 101)
        mixer.flush(now: 101.5)
        mixer.waitForPendingWork()

        #expect(collector.chunks.first?.startFrame == 0)
        // Flushes up to 101.5 − 0.4 settle = 1.1 s of timeline.
        #expect(collector.frameCount == 52_800)
        #expect(collector.chunks.first?.samples[0] == 0.5)
    }

    @Test("nothing older than the settle window is emitted")
    func honoursTheSettleWindow() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 100, sink: collector.sink)

        mixer.accept(buffer(frames: 4_800, value: 0.5), from: .child, arrivedAt: 100.1)
        mixer.flush(now: 100.2)
        mixer.waitForPendingWork()

        #expect(collector.chunks.isEmpty)
    }

    @Test("the settle window releases only the settled prefix while holding the rest back")
    func partialFlushHoldsBackUnsettledAudio() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 100, sink: collector.sink)

        // A 0.1 s buffer that finishes arriving at 100.5, so it occupies
        // timeline frames 19_200..<24_000 (no clamping: it lands well after 0).
        mixer.accept(buffer(frames: 4_800, value: 0.5), from: .child, arrivedAt: 100.5)
        // Settle boundary is 100.6 − 0.4 = 0.2 s of timeline = 9_600 frames.
        // That boundary sits before the buffer (19_200), so only the leading
        // silence up to it is released; the buffer itself stays held.
        mixer.flush(now: 100.6)
        mixer.waitForPendingWork()

        #expect(collector.frameCount == 9_600)
        #expect(collector.chunks.first?.startFrame == 0)

        // The remainder — 9_600 frames of silence plus the 4_800-frame buffer,
        // 14_400 frames total — is still held and comes out on finish.
        mixer.finish()
        mixer.waitForPendingWork()
        #expect(collector.frameCount == 24_000)
    }

    @Test("both sides talking at once sum into one track")
    func bothSidesSum() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 48_000, value: 0.3), from: .child, arrivedAt: 1)
        mixer.accept(buffer(frames: 48_000, value: 0.4), from: .santa, arrivedAt: 1)
        mixer.flush(now: 1.5)
        mixer.waitForPendingWork()

        let first = collector.chunks.first?.samples[0] ?? 0
        #expect(abs(first - 0.7) < 0.0001)
    }

    @Test("successive flushes emit contiguous frames with no gap or overlap")
    func flushesAreContiguous() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 48_000, value: 0.2), from: .child, arrivedAt: 1)
        mixer.flush(now: 1.5)
        mixer.accept(buffer(frames: 48_000, value: 0.2), from: .child, arrivedAt: 2)
        mixer.flush(now: 2.5)
        mixer.waitForPendingWork()

        #expect(collector.chunks.count == 2)
        let first = collector.chunks[0]
        let second = collector.chunks[1]
        #expect(second.startFrame == first.startFrame + first.samples.count)
        // Pins down the actual settle-window arithmetic, not just the
        // accumulator's own bookkeeping: 1.5 − 0.4 settle = 1.1 s of timeline
        // for the first flush (52_800 frames), then 2.5 − 0.4 = 2.1 s total,
        // so the second flush covers the remaining 1.0 s (48_000 frames).
        #expect(first.samples.count == 52_800)
        #expect(second.samples.count == 48_000)
    }

    @Test("finish emits the tail that the settle window was holding")
    func finishEmitsTheTail() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 48_000, value: 0.5), from: .child, arrivedAt: 1)
        mixer.flush(now: 1.1)
        mixer.waitForPendingWork()
        let flushed = collector.frameCount

        mixer.finish()
        mixer.waitForPendingWork()
        #expect(collector.frameCount > flushed)
    }

    @Test("audio arriving before the mixer started is clamped, not dropped")
    func earlyAudioIsClamped() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 100, sink: collector.sink)

        // Arrived at 100.1 but covers 0.5 s, so it begins 0.4 s before the start.
        mixer.accept(buffer(frames: 24_000, value: 0.5), from: .child, arrivedAt: 100.1)
        mixer.flush(now: 100.6)
        mixer.waitForPendingWork()

        #expect(collector.chunks.first?.startFrame == 0)
        #expect(collector.frameCount > 0)
    }

    @Test("accept copies the buffer synchronously so mutating the caller's buffer afterward cannot corrupt the recording")
    func acceptCopiesBufferBeforeReturning() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        let original = buffer(frames: 48_000, value: 0.5)
        mixer.accept(original, from: .child, arrivedAt: 1)

        // Mutate the caller's buffer immediately after accept() returns, exactly
        // as WebRTC's audio device layer would if it recycled the buffer from a
        // reuse pool for the next frame. accept() must have copied the samples
        // out synchronously before this point for the assertion below to hold.
        for frame in 0 ..< Int(original.frameLength) {
            original.floatChannelData![0][frame] = 0.9
        }

        mixer.flush(now: 1.5)
        mixer.waitForPendingWork()

        // Checking only frame 0 would pass even if the snapshot had copied
        // just the first frame, so pin down the last frame of the buffer too.
        let lastFrameIndex = Int(original.frameLength) - 1
        #expect(collector.chunks.first?.samples.first == 0.5)
        #expect(collector.chunks.first?.samples[lastFrameIndex] == 0.5)
    }

    @Test("accept is a no-op before start and after finish, so no snapshot ever reaches the timeline")
    func acceptWhenInertProducesNoOutput() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()

        // Before start: the mixer is inert, so this buffer must never reach
        // the timeline. A flush this far past a fresh start always emits a
        // padded-silence chunk regardless (silence is real audio too), so the
        // meaningful check is that every sample comes back exactly zero
        // rather than carrying this buffer's 0.9 value.
        mixer.accept(buffer(frames: 48_000, value: 0.9), from: .child, arrivedAt: 0)

        mixer.start(at: 0, sink: collector.sink)
        mixer.flush(now: 1.0)
        mixer.waitForPendingWork()
        #expect(collector.chunks.allSatisfy { chunk in chunk.samples.allSatisfy { $0 == 0 } })

        // Accept something real so finish has data to emit, proving the sink
        // is wired up correctly before exercising the post-finish case.
        mixer.accept(buffer(frames: 4_800, value: 0.5), from: .child, arrivedAt: 1.1)
        mixer.finish()
        mixer.waitForPendingWork()
        let afterFinish = collector.frameCount
        #expect(afterFinish > 0)

        // After finish: the mixer is inert again, so this buffer must not be
        // reflected anywhere.
        mixer.accept(buffer(frames: 48_000, value: 0.9), from: .child, arrivedAt: 1)
        mixer.waitForPendingWork()
        #expect(collector.frameCount == afterFinish)
    }

    @Test("accept copies an interleaved Float32 buffer with the correct stride")
    func acceptCopiesInterleavedFloat32Correctly() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                   channels: 2, interleaved: true)!
        let frameValues: [[Float]] = [
            [0.0, 0.2],
            [0.2, 0.4],
            [0.4, 0.6],
            [0.6, 0.8],
        ]
        let buffer = makeInterleavedBuffer(format: format, frames: frameValues.count, frameValues: frameValues)

        mixer.accept(buffer, from: .child, arrivedAt: Double(frameValues.count) / PCMResampler.sampleRate)
        mixer.flush(now: 1.0)
        mixer.waitForPendingWork()

        let samples = collector.chunks.first?.samples ?? []
        #expect(samples.count >= frameValues.count)
        for (frame, expected) in frameValues.enumerated() {
            let average = (expected[0] + expected[1]) / 2
            #expect(abs(samples[frame] - average) < 0.0001)
        }
    }

    @Test("accept copies an interleaved Int16 buffer with the correct stride")
    func acceptCopiesInterleavedInt16Correctly() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                   channels: 2, interleaved: true)!
        let frameValues: [[Float]] = [
            [0.0, 0.2],
            [0.2, 0.4],
            [0.4, 0.6],
            [0.6, 0.8],
        ]
        let buffer = makeInterleavedBuffer(format: format, frames: frameValues.count, frameValues: frameValues)

        mixer.accept(buffer, from: .child, arrivedAt: Double(frameValues.count) / PCMResampler.sampleRate)
        mixer.flush(now: 1.0)
        mixer.waitForPendingWork()

        let samples = collector.chunks.first?.samples ?? []
        #expect(samples.count >= frameValues.count)
        for (frame, expected) in frameValues.enumerated() {
            let average = (expected[0] + expected[1]) / 2
            #expect(abs(samples[frame] - average) < 0.01)
        }
    }

    @Test("accept copies a non-interleaved Float32 buffer with the correct per-channel layout")
    func acceptCopiesNonInterleavedFloat32Correctly() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                   channels: 2, interleaved: false)!
        let channel0: [Float] = [0.0, 0.2, 0.4, 0.6]
        let channel1: [Float] = [0.1, 0.3, 0.5, 0.7]
        let buffer = makeNonInterleavedBuffer(format: format, frames: channel0.count, channelValues: [channel0, channel1])

        mixer.accept(buffer, from: .child, arrivedAt: Double(channel0.count) / PCMResampler.sampleRate)
        mixer.flush(now: 1.0)
        mixer.waitForPendingWork()

        let samples = collector.chunks.first?.samples ?? []
        #expect(samples.count >= channel0.count)
        for frame in 0 ..< channel0.count {
            let average = (channel0[frame] + channel1[frame]) / 2
            #expect(abs(samples[frame] - average) < 0.0001)
        }
    }

    @Test("accept copies a non-interleaved Int16 buffer with the correct per-channel layout")
    func acceptCopiesNonInterleavedInt16Correctly() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                   channels: 2, interleaved: false)!
        let channel0: [Float] = [0.0, 0.2, 0.4, 0.6]
        let channel1: [Float] = [0.1, 0.3, 0.5, 0.7]
        let buffer = makeNonInterleavedBuffer(format: format, frames: channel0.count, channelValues: [channel0, channel1])

        mixer.accept(buffer, from: .child, arrivedAt: Double(channel0.count) / PCMResampler.sampleRate)
        mixer.flush(now: 1.0)
        mixer.waitForPendingWork()

        let samples = collector.chunks.first?.samples ?? []
        #expect(samples.count >= channel0.count)
        for frame in 0 ..< channel0.count {
            let average = (channel0[frame] + channel1[frame]) / 2
            #expect(abs(samples[frame] - average) < 0.01)
        }
    }

    @Test("finishing twice does not emit twice")
    func finishIsIdempotent() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 4_800, value: 0.5), from: .child, arrivedAt: 0.1)
        mixer.finish()
        mixer.waitForPendingWork()
        let after = collector.frameCount
        mixer.finish()
        mixer.waitForPendingWork()

        #expect(collector.frameCount == after)
    }
}
