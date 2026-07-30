import CoreMedia
import Testing
@testable import SantaAudioMixer

@Suite("MixedAudioChunk")
struct MixedAudioChunkTests {

    @Test("the start frame becomes a timestamp on the 48 kHz timeline")
    func startTimeUsesSampleRateTimescale() {
        let chunk = MixedAudioChunk(startFrame: 48_000, samples: [0])
        #expect(chunk.startTime.seconds == 1.0)
        #expect(chunk.startTime.timescale == 48_000)
    }

    @Test("a chunk at the very start begins at zero")
    func firstChunkStartsAtZero() {
        let chunk = MixedAudioChunk(startFrame: 0, samples: [0, 0])
        #expect(chunk.startTime == .zero)
    }

    @Test("floats scale into the full Int16 range")
    func floatsScaleToInt16() {
        let chunk = MixedAudioChunk(startFrame: 0, samples: [0, 1, -1, 0.5])
        #expect(chunk.int16Samples == [0, 32767, -32767, 16383])
    }

    @Test("out-of-range floats clamp instead of wrapping")
    func outOfRangeFloatsClamp() {
        let chunk = MixedAudioChunk(startFrame: 0, samples: [2.5, -2.5])
        #expect(chunk.int16Samples == [32767, -32767])
    }

    @Test("a sample buffer carries every frame at the right time")
    func sampleBufferIsWellFormed() throws {
        let chunk = MixedAudioChunk(startFrame: 96_000, samples: Array(repeating: 0.25, count: 480))

        let buffer = try #require(chunk.makeSampleBuffer())
        #expect(CMSampleBufferGetNumSamples(buffer) == 480)
        #expect(CMSampleBufferGetPresentationTimeStamp(buffer).seconds == 2.0)
        #expect(CMSampleBufferIsValid(buffer))
        #expect(CMSampleBufferGetTotalSampleSize(buffer) == 960)
    }

    @Test("a sample buffer declares mono 48 kHz signed 16-bit")
    func sampleBufferFormatIsCanonical() throws {
        let chunk = MixedAudioChunk(startFrame: 0, samples: Array(repeating: 0.1, count: 128))

        let buffer = try #require(chunk.makeSampleBuffer())
        let description = try #require(CMSampleBufferGetFormatDescription(buffer))
        let asbd = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee)

        #expect(asbd.mSampleRate == 48_000)
        #expect(asbd.mChannelsPerFrame == 1)
        #expect(asbd.mBitsPerChannel == 16)
        #expect(asbd.mBytesPerFrame == 2)
    }

    @Test("an empty chunk makes no buffer")
    func emptyChunkMakesNoBuffer() {
        let chunk = MixedAudioChunk(startFrame: 0, samples: [])
        #expect(chunk.makeSampleBuffer() == nil)
    }
}
