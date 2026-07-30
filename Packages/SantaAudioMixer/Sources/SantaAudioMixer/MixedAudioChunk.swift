import AVFoundation
import CoreMedia

/// A contiguous run of mixed audio, positioned on the recording's timeline.
///
/// Frames rather than seconds are the unit here: the writer needs sample-exact
/// placement, and seconds would accumulate rounding across a three-minute call.
public struct MixedAudioChunk: Sendable {

    public let startFrame: Int
    public let samples: [Float]

    public init(startFrame: Int, samples: [Float]) {
        self.startFrame = startFrame
        self.samples = samples
    }

    public var startTime: CMTime {
        CMTime(value: CMTimeValue(startFrame), timescale: CMTimeScale(PCMResampler.sampleRate))
    }

    /// Signed 16-bit is what the AAC encoder in `AVAssetWriter` accepts without
    /// argument. 32767 rather than 32768 so full-scale positive cannot overflow.
    public var int16Samples: [Int16] {
        samples.map { Int16(min(1, max(-1, $0)) * 32767) }
    }

    /// A mono 48 kHz signed-16-bit sample buffer ready for `AVAssetWriterInput`.
    /// Returns nil rather than throwing — a dropped chunk is a gap, not a failure.
    public func makeSampleBuffer() -> CMSampleBuffer? {
        guard !samples.isEmpty else { return nil }

        var asbd = AudioStreamBasicDescription(
            mSampleRate: PCMResampler.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        ) == noErr, let format else { return nil }

        let payload = int16Samples
        let byteCount = payload.count * MemoryLayout<Int16>.size

        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: byteCount,
            flags: 0,
            blockBufferOut: &blockBuffer
        ) == noErr, let blockBuffer else { return nil }

        let copied = payload.withUnsafeBytes { bytes -> OSStatus in
            guard let base = bytes.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(
                with: base, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount
            )
        }
        guard copied == noErr else { return nil }

        var sampleBuffer: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: format,
            sampleCount: CMItemCount(payload.count),
            presentationTimeStamp: startTime,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }

        return sampleBuffer
    }
}
