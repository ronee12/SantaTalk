import AVFoundation

/// The shape of a conversation, for the trim strip to draw.
///
/// A wall of thumbnails is the wrong timeline for a recorded call: the picture
/// barely changes for three minutes, so it tells a parent nothing about where
/// the good bit is. The audio does. This reduces the whole track to a few
/// hundred peaks, which is enough to see the laugh.
nonisolated enum WaveformSampler {

    /// Deliberately far below the 48 kHz the call was recorded at. Only the
    /// envelope is wanted, and decoding a three-minute call at full rate to
    /// throw away 99% of it is a second of the parent's time for no pixels.
    private static let sampleRate: Double = 8_000

    static func envelope(url: URL, buckets: Int) async -> [Float] {
        guard buckets > 0 else { return [] }

        let asset = AVURLAsset(url: url)
        guard
            let track = try? await asset.loadTracks(withMediaType: .audio).first,
            let duration = try? await asset.load(.duration),
            duration.seconds > 0,
            let reader = try? AVAssetReader(asset: asset)
        else { return [] }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: sampleRate
        ])
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }

        let total = max(1, Int(duration.seconds * sampleRate))
        var peaks = [Float](repeating: 0, count: buckets)
        var index = 0

        while let sample = output.copyNextSampleBuffer() {
            if Task.isCancelled { reader.cancelReading(); return [] }

            if let block = CMSampleBufferGetDataBuffer(sample) {
                let length = CMBlockBufferGetDataLength(block)
                let count = length / MemoryLayout<Float>.size
                if count > 0 {
                    var frames = [Float](repeating: 0, count: count)
                    frames.withUnsafeMutableBytes { raw in
                        _ = CMBlockBufferCopyDataBytes(
                            block, atOffset: 0, dataLength: length,
                            destination: raw.baseAddress!
                        )
                    }
                    for frame in frames {
                        let bucket = min(buckets - 1, index * buckets / total)
                        peaks[bucket] = max(peaks[bucket], abs(frame))
                        index += 1
                    }
                }
            }
            CMSampleBufferInvalidate(sample)
        }
        reader.cancelReading()

        // Normalised, because a quiet call deserves the same strip as a loud one.
        let loudest = peaks.max() ?? 0
        guard loudest > 0 else { return peaks }
        return peaks.map { $0 / loudest }
    }
}
