import AVFoundation
import SwiftUI
import UIKit

/// A silent video that fills its container, edge to edge, and either loops or plays
/// through once and holds on its last frame.
///
/// `AVPlayerLayer` rather than SwiftUI's `VideoPlayer`, which brings transport
/// controls, a background colour and a tap-to-pause gesture — none of which
/// belong on a screen whose whole job is to be a moving photograph.
///
/// The bundled clip carries no audio track at all, so playback never activates
/// an audio session and never interrupts whatever the parent is listening to.
struct LoopingVideoView: UIViewRepresentable {
    let resource: String
    var fileExtension: String = "mp4"
    /// Off on the welcome screen: it plays once and settles, so the scene stops
    /// moving while the parent reads the one line under it.
    var loops: Bool = true

    func makeUIView(context: Context) -> LoopingVideoContainer {
        LoopingVideoContainer(
            url: Bundle.main.url(forResource: resource, withExtension: fileExtension),
            loops: loops
        )
    }

    func updateUIView(_ view: LoopingVideoContainer, context: Context) {}

    static func dismantleUIView(_ view: LoopingVideoContainer, coordinator: ()) {
        view.stop()
    }
}

/// Owns the queue player and the looper, both of which have to outlive the call
/// that made them or playback stops after one pass.
final class LoopingVideoContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var observers: [any NSObjectProtocol] = []
    /// A single-pass clip that has reached its end must not be restarted when the
    /// app comes back to the front — the still last frame is the intended state.
    private var hasPlayedThrough = false

    init(url: URL?, loops: Bool) {
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        backgroundColor = UIColor(Palette.nightDeep)

        guard let playerLayer = layer as? AVPlayerLayer else { return }
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.player = player

        guard let url else { return }
        let item = AVPlayerItem(url: url)

        if loops {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            // Without this the queue player clears the layer on the last frame and
            // the screen drops to flat night behind the copy.
            player.actionAtItemEnd = .pause
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: AVPlayerItem.didPlayToEndTimeNotification,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    self?.hasPlayedThrough = true
                }
            )
        }

        player.isMuted = true
        player.play()

        // iOS pauses the player when the app leaves the foreground and does not
        // resume it on the way back, which would leave a still frame behind.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, !self.hasPlayedThrough else { return }
                self.player.play()
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func stop() {
        player.pause()
        removeObservers()
    }

    private func removeObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    deinit { removeObservers() }
}
