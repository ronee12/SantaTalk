import AVFoundation

/// Normalises whatever a LiveKit track hands over into 48 kHz mono floats.
///
/// One instance per source. `AVAudioConverter` carries resampling state across
/// calls, so reusing a converter for a single source is what keeps consecutive
/// buffers from clicking at their seams — a converter per call would not.
public final class PCMResampler {

    public static let sampleRate: Double = 48_000

    public static let canonicalFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: PCMResampler.sampleRate,
        channels: 1,
        interleaved: false
    )!

    // Exposed at `internal` (rather than `private`) so the test target can assert
    // the same converter instance is reused across calls — reuse is what keeps
    // resampling state, and therefore buffer seams, click-free.
    internal private(set) var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?

    public init() {}

    /// The buffer's audio as canonical mono floats. Returns an empty array if the
    /// buffer is empty or cannot be converted — a dropped buffer is a click, a
    /// crash is a ruined call.
    public func monoFloats(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard buffer.frameLength > 0 else { return [] }

        let format = buffer.format
        if format.commonFormat == .pcmFormatFloat32,
           format.sampleRate == Self.sampleRate,
           format.channelCount == 1,
           !format.isInterleaved,
           let channel = buffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
        }

        // AVAudioConverter's default channel reduction does not blend channels —
        // its channelMap simply selects one source channel per output channel, so
        // a naive stereo-to-mono conversion silently discards every channel but
        // the first. Downmix ourselves first so all channels are actually heard.
        guard let source = format.channelCount > 1 ? downmixToMono(buffer) : buffer else { return [] }

        guard let converter = converter(for: source.format) else { return [] }

        let ratio = Self.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: Self.canonicalFormat, frameCapacity: capacity) else {
            return []
        }

        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }

        guard status != .error, let channel = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }

    /// Averages every channel of `buffer` down to a single mono channel at the
    /// same sample rate and bit depth family, so multi-channel sources get a
    /// genuine downmix rather than a single channel picked at random.
    private func downmixToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let format = buffer.format
        let channelCount = Int(format.channelCount)
        let frames = Int(buffer.frameLength)

        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: 1,
            interleaved: false
        ), let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameLength),
        let monoChannel = mono.floatChannelData else { return nil }

        mono.frameLength = buffer.frameLength

        if let float = buffer.floatChannelData {
            for frame in 0 ..< frames {
                var sum: Float = 0
                for channel in 0 ..< channelCount { sum += float[channel][frame] }
                monoChannel[0][frame] = sum / Float(channelCount)
            }
        } else if let int16 = buffer.int16ChannelData {
            for frame in 0 ..< frames {
                var sum: Float = 0
                for channel in 0 ..< channelCount { sum += Float(int16[channel][frame]) / 32768.0 }
                monoChannel[0][frame] = sum / Float(channelCount)
            }
        } else {
            return nil
        }

        return mono
    }

    private func converter(for format: AVAudioFormat) -> AVAudioConverter? {
        if let converter, converterInputFormat == format { return converter }
        let made = AVAudioConverter(from: format, to: Self.canonicalFormat)
        converter = made
        converterInputFormat = format
        return made
    }
}
