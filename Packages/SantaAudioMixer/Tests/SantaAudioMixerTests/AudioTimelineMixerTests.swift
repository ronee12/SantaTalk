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
