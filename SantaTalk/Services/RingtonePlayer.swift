import AVFoundation
import Foundation

/// The sound the phone makes while Santa is calling.
///
/// One tone, looped until the call is answered rather than played once — a
/// thirteen-second file that stops on its own reads as the caller giving up,
/// which is the opposite of what the ringing screen is for.
///
/// The session category is `.playback` so the ring is heard with the silent
/// switch on, the way a real incoming call is. That is also why `stop()` has to
/// be called before the call connects: LiveKit reconfigures the session to
/// `.playAndRecord` on its way up, and a ringtone still holding `.playback` is a
/// ringtone playing over Santa's first words.
@MainActor
final class RingtonePlayer {

    private var player: AVAudioPlayer?

    var isPlaying: Bool { player?.isPlaying ?? false }

    /// Starts the loop, or does nothing if it is already running — the ringing
    /// screen can appear more than once without restarting the tone from zero.
    func start() {
        guard player == nil else { return }

        guard let url = Bundle.main.url(forResource: "ringtone", withExtension: "mp3") else {
            // A missing asset must not take the call with it. The screen still
            // rings, silently, and Accept still works.
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            self.player = nil
        }
    }

    /// Stops and releases the tone, and hands the audio session back.
    ///
    /// Deactivating with `.notifyOthersOnDeactivation` is what lets the call's
    /// own session take over cleanly instead of inheriting a `.playback`
    /// category that cannot record.
    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
