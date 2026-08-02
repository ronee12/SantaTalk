import AVFoundation
import Observation
import SwiftUI

/// Everything the Trim & Share screen knows.
///
/// Kept out of `AppState` on purpose: this is the only screen that cares about
/// any of it, all of it dies when the screen closes, and `AppState` is already
/// long enough that adding a video editor to it would make both harder to read.
@Observable
@MainActor
final class TrimShareModel {

    enum Phase: Equatable {
        case preparing
        case ready
        case exporting(Double)
        case failed(String)
    }

    struct Thumbnail: Identifiable {
        let id: Int
        let image: CGImage
    }

    /// Identifiable so the system share sheet can be presented from it.
    struct Exported: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    /// Shorter than this is a stutter, not a clip.
    static let minimumClip: Double = 1

    private(set) var phase: Phase = .preparing
    private(set) var duration: Double = 0
    private(set) var position: Double = 0
    private(set) var isPlaying = false
    private(set) var thumbnails: [Thumbnail] = []
    private(set) var waveform: [Float] = []
    private(set) var hasCamera = false

    var exported: Exported?

    private(set) var start: Double = 0
    private(set) var end: Double = 0

    var selectedLength: Double { max(0, end - start) }
    var isWholeCall: Bool { start <= 0.01 && end >= duration - 0.01 }

    @ObservationIgnored let player = AVPlayer()

    @ObservationIgnored private let exporter = RecordingExporter()
    @ObservationIgnored private var share: ShareComposition?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var stripTask: Task<Void, Never>?
    @ObservationIgnored private var waveformTask: Task<[Float], Never>?
    @ObservationIgnored private var didCancelExport = false

    // MARK: Opening

    func prepare(url: URL, childName: String, showsWordmark: Bool) async {
        guard share == nil else { return }
        do {
            // Detached deliberately. `SWIFT_APPROACHABLE_CONCURRENCY` makes a
            // nonisolated async function run on its caller's executor, so
            // awaiting the build directly would scan every sample in the file on
            // the main actor and freeze the screen that is waiting for it.
            let share = try await Task.detached {
                try await ShareComposition.build(
                    url: url, childName: childName, showsWordmark: showsWordmark
                )
            }.value
            self.share = share

            duration = max(0, share.duration.seconds)
            start = 0
            end = duration
            hasCamera = share.cameraTrack != nil

            let item = AVPlayerItem(asset: share.composition)
            item.videoComposition = share.videoComposition
            player.replaceCurrentItem(with: item)
            watchPlayhead()

            phase = .ready
            loadStrip(url: url, share: share)
        } catch {
            phase = .failed("This recording could not be opened.")
        }
    }

    /// Thumbnails come from the *composed* video rather than the raw camera, so
    /// the strip shows what will actually be shared — including the placeholder
    /// across any stretch the camera was off.
    private func loadStrip(url: URL, share: ShareComposition) {
        stripTask = Task { [weak self] in
            guard let self else { return }

            // Detached for the same reason the composition build is — this one
            // walks well over a million samples. Held so closing the screen can
            // cancel it; a detached task does not inherit cancellation.
            let peaks = Task.detached { await WaveformSampler.envelope(url: url, buckets: 480) }
            self.waveformTask = peaks

            let count = 18
            let times = (0..<count).map { step in
                CMTime(seconds: self.duration * Double(step) / Double(count),
                       preferredTimescale: 600)
            }

            let generator = AVAssetImageGenerator(asset: share.composition)
            generator.videoComposition = share.videoComposition
            generator.maximumSize = CGSize(width: 132, height: 234)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.6, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.6, preferredTimescale: 600)

            var index = 0
            for await result in generator.images(for: times) {
                if Task.isCancelled { return }
                if let image = try? result.image {
                    self.thumbnails.append(Thumbnail(id: index, image: image))
                }
                index += 1
            }

            let envelope = await peaks.value
            if Task.isCancelled { return }
            self.waveform = envelope
        }
    }

    // MARK: The selection

    /// Both clamps stay inside `0...duration` even when the call is barely
    /// longer than the minimum clip, so a short recording cannot produce a
    /// negative handle.
    func setStart(_ seconds: Double) {
        start = min(max(0, seconds), max(0, end - Self.minimumClip))
        if position < start { seek(to: start) }
    }

    func setEnd(_ seconds: Double) {
        end = max(min(duration, seconds), min(duration, start + Self.minimumClip))
        if position > end { seek(to: start) }
    }

    func resetSelection() {
        start = 0
        end = duration
    }

    // MARK: Playback

    /// The preview loops the selection rather than the call. A parent choosing a
    /// clip wants to hear that clip repeatedly, not wait out the rest.
    private func watchPlayhead() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.03, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.position = max(0, time.seconds)
                guard self.isPlaying else { return }
                if self.position >= self.end - 0.02 || self.position < self.start - 0.5 {
                    self.seek(to: self.start)
                }
            }
        }
    }

    func togglePlayback() {
        guard phase == .ready else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if position < start || position >= end - 0.02 { seek(to: start) }
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let clamped = min(max(start, seconds), end)
        position = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero
        )
    }

    /// Scrubbing the strip is allowed anywhere in the call, not only inside the
    /// selection — that is how a parent finds the bit they want to keep.
    func scrub(to seconds: Double) {
        let clamped = min(max(0, seconds), duration)
        position = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero
        )
    }

    // MARK: Export

    func export(title: String, dateLabel: String) async {
        guard let share, !exporter.isExporting else { return }
        pause()
        didCancelExport = false
        phase = .exporting(0)

        let url = ExportDirectory.file(title: title, dateLabel: dateLabel)
        let range = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        do {
            try await exporter.export(share, timeRange: range, to: url) { [weak self] fraction in
                self?.phase = .exporting(fraction)
            }
            phase = .ready
            exported = Exported(url: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            phase = didCancelExport ? .ready : .failed("The video could not be prepared.")
            didCancelExport = false
        }
    }

    func cancelExport() {
        guard case .exporting = phase else { return }
        didCancelExport = true
        exporter.cancel()
    }

    func dismissFailure() {
        phase = .ready
    }

    // MARK: Closing

    func teardown() {
        stripTask?.cancel()
        waveformTask?.cancel()
        exporter.cancel()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
