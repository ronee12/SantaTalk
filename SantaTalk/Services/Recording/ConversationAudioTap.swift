import AVFoundation
import LiveKit
import SantaAudioMixer

/// Listens to one side of the call without altering it.
///
/// LiveKit calls `render(pcmBuffer:)` from an audio thread, so this does the
/// least possible work: stamp the buffer with the instant it arrived and hand it
/// on. `AudioRenderer` is an `@objc` protocol, hence `NSObject`.
///
/// Explicitly `nonisolated` because `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// would otherwise pull this unannotated class onto the main actor — defeating
/// the entire point of a tap that must be callable from LiveKit's real-time
/// audio thread without a main-actor hop. `@unchecked Sendable` because
/// `AudioRenderer: Sendable` requires conformance and `NSObject` itself isn't
/// `Sendable`; both stored properties here are immutable and themselves
/// `Sendable` (`MixSource`, and `Sink` is `@Sendable`), so there is nothing
/// actually unsafe being silenced.
nonisolated final class ConversationAudioTap: NSObject, AudioRenderer, @unchecked Sendable {

    typealias Sink = @Sendable (AVAudioPCMBuffer, MixSource, TimeInterval) -> Void

    private let source: MixSource
    private let sink: Sink

    init(source: MixSource, sink: @escaping Sink) {
        self.source = source
        self.sink = sink
        super.init()
    }

    func render(pcmBuffer: AVAudioPCMBuffer) {
        // The same clock the recording start is taken from.
        sink(pcmBuffer, source, CACurrentMediaTime())
    }
}
