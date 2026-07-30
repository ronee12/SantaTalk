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
    private final class Collector: @unchecked Sendable {
        var chunks: [MixedAudioChunk] = []
        var sink: @Sendable (MixedAudioChunk) -> Void {
            { [self] chunk in chunks.append(chunk) }
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

        #expect(collector.chunks.isEmpty)
    }

    @Test("both sides talking at once sum into one track")
    func bothSidesSum() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 48_000, value: 0.3), from: .child, arrivedAt: 1)
        mixer.accept(buffer(frames: 48_000, value: 0.4), from: .santa, arrivedAt: 1)
        mixer.flush(now: 1.5)

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

        #expect(collector.chunks.count == 2)
        let first = collector.chunks[0]
        let second = collector.chunks[1]
        #expect(second.startFrame == first.startFrame + first.samples.count)
    }

    @Test("finish emits the tail that the settle window was holding")
    func finishEmitsTheTail() {
        let mixer = AudioTimelineMixer()
        let collector = Collector()
        mixer.start(at: 0, sink: collector.sink)

        mixer.accept(buffer(frames: 48_000, value: 0.5), from: .child, arrivedAt: 1)
        mixer.flush(now: 1.1)
        let flushed = collector.frameCount

        mixer.finish()
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
        let after = collector.frameCount
        mixer.finish()

        #expect(collector.frameCount == after)
    }
}
