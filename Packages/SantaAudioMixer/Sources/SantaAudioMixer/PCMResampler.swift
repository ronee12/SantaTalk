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

    private var converter: AVAudioConverter?
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

        guard let converter = converter(for: format) else { return [] }

        let ratio = Self.sampleRate / format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
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
            return buffer
        }

        guard status != .error, let channel = output.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }

    private func converter(for format: AVAudioFormat) -> AVAudioConverter? {
        if let converter, converterInputFormat == format { return converter }
        let made = AVAudioConverter(from: format, to: Self.canonicalFormat)
        converter = made
        converterInputFormat = format
        return made
    }
}
