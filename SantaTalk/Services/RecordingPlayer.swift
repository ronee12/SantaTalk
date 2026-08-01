import AVFoundation
import Observation

/// One `AVPlayer` behind the player screen.
///
/// The recording is a single file, so the same player drives both the
/// conversation and the child's face. Two players would need keeping in step;
/// one cannot fall out of it.
@Observable
@MainActor
final class RecordingPlayer {

    private(set) var isPlaying = false
    private(set) var position: Double = 0
    private(set) var duration: Double = 0

    @ObservationIgnored let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    /// `duration` comes from the stored row rather than the asset: the row is
    /// already loaded, and reading an asset's duration is asynchronous.
    func load(url: URL, duration: Int) {
        stop()

        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        self.duration = Double(duration)
        position = 0
        isPlaying = false

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.position = max(0, time.seconds) }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.position = 0
                await self.player.seek(to: .zero)
            }
        }
    }

    func togglePlayback() {
        guard player.currentItem != nil else { return }
        isPlaying.toggle()
        if isPlaying { player.play() } else { player.pause() }
    }

    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        let seconds = min(1, max(0, fraction)) * duration
        position = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func skipBackFifteen() {
        seek(toFraction: duration > 0 ? max(0, position - 15) / duration : 0)
    }

    func stop() {
        player.pause()
        isPlaying = false
        position = 0

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player.replaceCurrentItem(with: nil)
    }
}
