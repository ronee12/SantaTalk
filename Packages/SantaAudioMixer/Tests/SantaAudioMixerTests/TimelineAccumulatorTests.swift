import Testing
@testable import SantaAudioMixer

@Suite("TimelineAccumulator")
struct TimelineAccumulatorTests {

    @Test("an empty timeline drains to nothing")
    func emptyDrainsToNil() {
        var timeline = TimelineAccumulator()
        #expect(timeline.drain(upTo: 0) == nil)
        #expect(timeline.drainAll() == nil)
    }

    @Test("samples written at zero come back unchanged")
    func writeThenDrain() {
        var timeline = TimelineAccumulator()
        timeline.add([0.1, 0.2, 0.3], at: 0)

        let drained = timeline.drain(upTo: 3)
        #expect(drained?.startFrame == 0)
        #expect(drained?.samples.count == 3)
        #expect(drained?.samples[1] == 0.2)
    }

    @Test("overlapping writes sum — both parties talking at once")
    func overlapsSum() {
        var timeline = TimelineAccumulator()
        timeline.add([0.2, 0.2, 0.2, 0.2], at: 0)
        timeline.add([0.1, 0.1], at: 2)

        let samples = timeline.drain(upTo: 4)?.samples ?? []
        #expect(samples.count == 4)
        #expect(abs(samples[1] - 0.2) < 0.0001)
        #expect(abs(samples[2] - 0.3) < 0.0001)
        #expect(abs(samples[3] - 0.3) < 0.0001)
    }

    @Test("a write landing past the end grows the timeline with silence")
    func gapsBecomeSilence() {
        var timeline = TimelineAccumulator()
        timeline.add([0.5], at: 0)
        timeline.add([0.5], at: 4)

        let drained = timeline.drain(upTo: 5)
        #expect(drained?.samples.count == 5)
        #expect(drained?.samples[1] == 0)
        #expect(drained?.samples[3] == 0)
        #expect(drained?.samples[4] == 0.5)
    }

    @Test("draining advances the base frame")
    func baseFrameAdvances() {
        var timeline = TimelineAccumulator()
        timeline.add([0.1, 0.2, 0.3, 0.4], at: 0)
        _ = timeline.drain(upTo: 2)

        #expect(timeline.baseFrame == 2)
        let drained = timeline.drain(upTo: 4)
        #expect(drained?.startFrame == 2)
        #expect(drained?.samples.count == 2)
    }

    @Test("a late buffer overlapping flushed audio drops only the flushed prefix")
    func lateBufferKeepsItsTail() {
        var timeline = TimelineAccumulator()
        timeline.add([0.1, 0.1, 0.1, 0.1], at: 0)
        _ = timeline.drain(upTo: 2)

        timeline.add([0.5, 0.5, 0.5, 0.5], at: 0)

        let drained = timeline.drain(upTo: 4)
        #expect(drained?.startFrame == 2)
        #expect(drained?.samples == [0.6, 0.6])
    }

    @Test("a buffer entirely before the base frame is dropped")
    func fullyLateBufferIsDropped() {
        var timeline = TimelineAccumulator()
        timeline.add([0.1, 0.1, 0.1, 0.1], at: 0)
        _ = timeline.drain(upTo: 4)

        timeline.add([0.9, 0.9], at: 0)
        #expect(timeline.drainAll() == nil)
    }

    @Test("summed samples are clipped to the representable range")
    func summedSamplesClip() {
        var timeline = TimelineAccumulator()
        timeline.add([0.9, -0.9], at: 0)
        timeline.add([0.9, -0.9], at: 0)

        let drained = timeline.drain(upTo: 2)
        #expect(drained?.samples == [1.0, -1.0])
    }

    @Test("padding to a frame past the end emits trailing silence")
    func drainPadsToRequestedFrame() {
        var timeline = TimelineAccumulator()
        timeline.add([0.5, 0.5], at: 0)

        let drained = timeline.drain(upTo: 6)
        #expect(drained?.samples.count == 6)
        #expect(timeline.baseFrame == 6)
    }

    @Test("drainAll takes exactly what is left")
    func drainAllTakesRemainder() {
        var timeline = TimelineAccumulator()
        timeline.add([0.1, 0.2, 0.3], at: 0)

        let drained = timeline.drainAll()
        #expect(drained?.samples.count == 3)
        #expect(timeline.drainAll() == nil)
    }
}
