import AVFoundation

/// When the camera was actually running, expressed as ranges on the call's
/// timeline.
///
/// A recorded call is not necessarily a continuous video. The camera starts a
/// couple of hundred milliseconds after the audio, "Hide me" stops it mid-call,
/// and a call ended while hidden leaves a tail with no frames at all. Left
/// alone, a player holds the last decoded frame across every one of those gaps —
/// so a child who hid for forty seconds is exported as a forty-second freeze,
/// which reads as a broken video rather than a deliberate one.
///
/// Knowing where the holes are lets the share draw its placeholder in them
/// instead.
/// `nonisolated` so the scan, which walks every sample in the file, runs off the
/// main actor rather than janking the screen that asked for it.
nonisolated struct CameraCoverage: Sendable {

    /// Sorted, non-overlapping, and clamped to the call.
    let ranges: [CMTimeRange]

    static let none = CameraCoverage(ranges: [])

    /// Frames this far apart are two separate stretches of camera, not one
    /// stretch with a hiccup in it. Comfortably longer than any dropped frame,
    /// comfortably shorter than any deliberate hide.
    private static let maximumGap = CMTime(value: 3, timescale: 2)

    func contains(_ time: CMTime) -> Bool {
        ranges.contains { $0.containsTime(time) }
    }

    /// Reads the video track's sample *references* — timing only, no decoding —
    /// so a three-minute call is scanned in a few milliseconds rather than
    /// decoded twice.
    ///
    /// If the scan cannot be run at all, the honest fallback is to claim the
    /// track's whole time range: that restores today's freeze-frame behaviour
    /// rather than covering a call in placeholders.
    static func scan(track: AVAssetTrack, asset: AVAsset, limit: CMTime) async -> CameraCoverage {
        let trackRange: CMTimeRange
        let frameDuration: CMTime
        do {
            trackRange = try await track.load(.timeRange)
            let rate = try await track.load(.nominalFrameRate)
            frameDuration = rate > 0
                ? CMTime(seconds: 1 / Double(rate), preferredTimescale: 600)
                : CMTime(value: 1, timescale: 30)
        } catch {
            return CameraCoverage(ranges: [])
        }

        let fallback = CameraCoverage(ranges: clamp([trackRange], to: limit))

        guard let reader = try? AVAssetReader(asset: asset) else { return fallback }
        let output = AVAssetReaderSampleReferenceOutput(track: track)
        guard reader.canAdd(output) else { return fallback }
        reader.add(output)
        guard reader.startReading() else { return fallback }

        var ranges: [CMTimeRange] = []
        var start: CMTime?
        var end: CMTime?

        while let sample = output.copyNextSampleBuffer() {
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            guard time.isValid else { continue }

            let sampleDuration = CMSampleBufferGetDuration(sample)
            let step = sampleDuration.isValid && sampleDuration > .zero ? sampleDuration : frameDuration

            if let previousEnd = end, time - previousEnd <= maximumGap {
                end = time + step
            } else {
                if let start, let end { ranges.append(CMTimeRange(start: start, end: end)) }
                start = time
                end = time + step
            }
        }
        reader.cancelReading()

        if let start, let end { ranges.append(CMTimeRange(start: start, end: end)) }
        guard !ranges.isEmpty else { return CameraCoverage(ranges: []) }

        return CameraCoverage(ranges: clamp(ranges, to: limit))
    }

    /// The video track can outlast the audio by a frame or two. Anything past
    /// the end of the call is not part of it.
    private static func clamp(_ ranges: [CMTimeRange], to limit: CMTime) -> [CMTimeRange] {
        ranges.compactMap { range in
            let start = CMTimeMaximum(range.start, .zero)
            let end = CMTimeMinimum(range.end, limit)
            guard end > start else { return nil }
            return CMTimeRange(start: start, end: end)
        }
    }
}
