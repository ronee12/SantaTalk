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

    /// A buffer of `frames` frames in `format`, with each channel filled with its
    /// own constant from `values` (indexed by channel), so downmixing can be
    /// distinguished from picking a single channel.
    private func makeBuffer(format: AVAudioFormat, frames: AVAudioFrameCount, channelValues values: [Float]) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        if let float = buffer.floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                let value = values[channel]
                for frame in 0 ..< Int(frames) { float[channel][frame] = value }
            }
        }
        return buffer
    }

    /// An interleaved buffer of `frames` frames in `format`, with per-frame,
    /// per-channel values from `frameValues` (indexed `[frame][channel]`), laid
    /// out in true interleaved order — `[f0c0, f0c1, f1c0, f1c1, …]` — via the
    /// single channel pointer `AVAudioPCMBuffer` exposes for interleaved data.
    /// Values vary frame-to-frame so a sliding-window misread (which would land
    /// on a neighbouring frame's sample) produces a visibly different sequence
    /// than the true per-frame average, unlike a constant-valued buffer would.
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

    @Test("interleaved stereo Float32 downmixes to the true per-frame average")
    func interleavedStereoFloatDownmixesCorrectly() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                   channels: 2, interleaved: true)!
        // channel 0 (left) and channel 1 (right) diverge every frame, so a
        // sliding-window read (which would pick up a neighbouring frame's
        // sample instead of this frame's other channel) yields a clearly
        // different sequence than the true per-frame average.
        let frameValues: [[Float]] = [
            [0.1, 0.9],
            [0.3, 0.7],
            [0.5, 0.5],
            [0.7, 0.3],
        ]
        let buffer = makeInterleavedBuffer(format: format, frames: frameValues.count, frameValues: frameValues)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == frameValues.count)
        for (frame, expected) in frameValues.enumerated() {
            let average = (expected[0] + expected[1]) / 2
            #expect(abs(samples[frame] - average) < 0.0001)
        }
    }

    @Test("interleaved stereo Int16 downmixes to the true per-frame average")
    func interleavedStereoInt16DownmixesCorrectly() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                   channels: 2, interleaved: true)!
        let frameValues: [[Float]] = [
            [0.2, 0.8],
            [0.4, 0.6],
            [0.6, 0.4],
            [0.8, 0.2],
        ]
        let buffer = makeInterleavedBuffer(format: format, frames: frameValues.count, frameValues: frameValues)

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == frameValues.count)
        for (frame, expected) in frameValues.enumerated() {
            let average = (expected[0] + expected[1]) / 2
            #expect(abs(samples[frame] - average) < 0.01)
        }
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
        let buffer = makeBuffer(format: format, frames: 480, channelValues: [1.0, 0.0])

        let samples = resampler.monoFloats(from: buffer)
        #expect(samples.count == 480)
        let mixed = samples.first ?? -1
        // A genuine downmix of left=1.0 and right=0.0 lands strictly between the
        // two channel values. An implementation that dropped the right channel
        // (or the left) would instead equal 1.0 or 0.0 exactly.
        #expect(mixed > 0.0 && mixed < 1.0)
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

    @Test("the converter for a source is reused across buffers, and swapped when the format changes")
    func converterIsReusedPerSource() {
        let resampler = PCMResampler()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                   channels: 1, interleaved: false)!

        _ = resampler.monoFloats(from: makeBuffer(format: format, frames: 160, value: 0.3))
        let firstConverter = resampler.converter
        #expect(firstConverter != nil)

        _ = resampler.monoFloats(from: makeBuffer(format: format, frames: 160, value: 0.3))
        let secondConverter = resampler.converter
        #expect(secondConverter != nil)

        // Same source format: the converter instance must be reused, not rebuilt,
        // or resampling state (and click-free seams) would be lost every call.
        #expect(firstConverter === secondConverter)

        let otherFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000,
                                        channels: 1, interleaved: false)!
        _ = resampler.monoFloats(from: makeBuffer(format: otherFormat, frames: 240, value: 0.3))
        let thirdConverter = resampler.converter
        #expect(thirdConverter != nil)

        // A different source format must get its own converter.
        #expect(ObjectIdentifier(secondConverter!) != ObjectIdentifier(thirdConverter!))
    }
}
