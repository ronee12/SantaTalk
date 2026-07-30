import AVFoundation
import Testing
@testable import SantaAudioMixer

@Suite("PCMResampler")
struct PCMResamplerTests {

    /// A buffer of `frames` frames in `format`, filled with a constant so the
    /// content is trivially checkable after conversion.
    private func makeBuffer(format: AVAudioFormat, frames: AVAudioFrameCount, value: Float) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        if let float = buffer.floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                for frame in 0 ..< Int(frames) { float[channel][frame] = value }
            }
        } else if let int16 = buffer.int16ChannelData {
            let scaled = Int16(value * 32767)
            for channel in 0 ..< Int(format.channelCount) {
                for frame in 0 ..< Int(frames) { int16[channel][frame] = scaled }
            }
        }
        return buffer
    }

    @Test("canonical buffers pass straight through")
    func canonicalPassesThrough() {
        let resampler = PCMResampler()
        let buffer = makeBuffer(format: PCMResampler.canonicalFormat, frames: 480, value: 0.25)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == 480)
        #expect(samples.first == 0.25)
    }

    @Test("24 kHz mono roughly doubles in frame count at 48 kHz")
    func upsamplesFromHalfRate() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000,
                                   channels: 1, interleaved: false)!
        let buffer = makeBuffer(format: format, frames: 480, value: 0.5)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count > 800)
        #expect(samples.count < 1100)
    }

    @Test("stereo folds down to mono without changing duration")
    func stereoFoldsToMono() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                   channels: 2, interleaved: false)!
        let buffer = makeBuffer(format: format, frames: 480, value: 0.4)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == 480)
        #expect(samples.first != 0)
    }

    @Test("Int16 input converts to float")
    func int16Converts() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                   channels: 1, interleaved: false)!
        let buffer = makeBuffer(format: format, frames: 480, value: 0.5)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == 480)
        #expect(abs((samples.first ?? 0) - 0.5) < 0.01)
    }

    @Test("an empty buffer yields no samples")
    func emptyBufferYieldsNothing() {
        let resampler = PCMResampler()
        let buffer = AVAudioPCMBuffer(pcmFormat: PCMResampler.canonicalFormat, frameCapacity: 480)!
        buffer.frameLength = 0

        #expect(resampler.monoFloats(from: buffer).isEmpty)
    }

    @Test("the same resampler handles repeated buffers from one source")
    func repeatedBuffersKeepConverging() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                   channels: 1, interleaved: false)!

        var total = 0
        for _ in 0 ..< 5 {
            total += resampler.monoFloats(from: makeBuffer(format: format, frames: 160, value: 0.3)).count
        }
        // 5 × 10 ms at 16 kHz is 50 ms, which is 2400 frames at 48 kHz.
        #expect(total > 2000)
        #expect(total < 2800)
    }
}
