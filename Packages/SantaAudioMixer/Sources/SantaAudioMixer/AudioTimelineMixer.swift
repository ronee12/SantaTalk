import AVFoundation
import Foundation

/// Which side of the call a buffer came from.
public enum MixSource: Sendable, Hashable {
    case child
    case santa
}

/// Turns two independent audio streams into one contiguous recording track.
///
/// The two LiveKit renderers fire on their own audio threads with no clock
/// between them, so every buffer is positioned by the wall-clock instant it
/// arrived. Flushing lags that by `settleWindow`, which gives a buffer that took
/// the slower path time to land before its stretch of timeline is written.
///
/// Flushing is driven from outside rather than by an internal timer, so the type
/// is deterministic under test and the cadence stays the caller's decision.
///
/// `accept` and `flush` hop onto a serial queue *asynchronously* and return
/// immediately: `accept` runs on a real-time LiveKit audio thread and `flush`
/// runs on a main-actor timer, and neither may block on the recording path —
/// a disk hiccup in the sink (which eventually reaches `AVAssetWriterInput`)
/// must never stall the call. `start` and `finish` are not called from
/// real-time contexts, so they hop onto the same queue synchronously: their
/// state has been applied and any resulting chunk handed to the sink by the
/// time those calls return. Tests that need `accept`/`flush` to have drained
/// before asserting use `waitForPendingWork()`.
public final class AudioTimelineMixer: @unchecked Sendable {

    public typealias Sink = @Sendable (MixedAudioChunk) -> Void

    /// How far behind the present the flush point sits.
    public static let settleWindow: TimeInterval = 0.4

    private let queue = DispatchQueue(label: "com.santatalk.audio-mixer")

    private var accumulator = TimelineAccumulator()
    private var resamplers: [MixSource: PCMResampler] = [:]
    private var startTime: TimeInterval?
    private var sink: Sink?
    private var hasFinished = false

    public init() {}

    /// Begins a recording timeline anchored at `time`, which must come from the
    /// same clock the `arrivedAt` stamps use.
    public func start(at time: TimeInterval, sink: @escaping Sink) {
        queue.sync {
            accumulator = TimelineAccumulator()
            resamplers = [:]
            startTime = time
            self.sink = sink
            hasFinished = false
        }
    }

    /// Called from a LiveKit audio thread, twice over for a two-way call.
    ///
    /// Non-blocking by design: this runs on a real-time audio-rendering thread,
    /// and must never wait on whatever else is ahead of it on the queue (a
    /// flush whose sink is doing disk I/O, for instance).
    public func accept(_ buffer: AVAudioPCMBuffer, from source: MixSource, arrivedAt time: TimeInterval) {
        queue.async { [self] in
            guard let startTime, !hasFinished else { return }

            let resampler = resamplers[source] ?? {
                let made = PCMResampler()
                resamplers[source] = made
                return made
            }()

            let samples = resampler.monoFloats(from: buffer)
            guard !samples.isEmpty else { return }

            // The buffer *ends* at its arrival instant, so its first frame sits
            // a buffer-length earlier on the timeline. Rounded rather than
            // truncated — floating-point subtraction above can land a hair under
            // the true value (e.g. 1.1 as 1.0999999999999943), and truncating
            // that would clip a frame that should have been included.
            let endFrame = Int(((time - startTime) * PCMResampler.sampleRate).rounded())
            accumulator.add(samples, at: max(0, endFrame - samples.count))
        }
    }

    /// Emits everything that has settled. Call on a repeating cadence.
    ///
    /// Non-blocking by design: this is called from the main actor on a timer,
    /// and must not block the UI thread on the sink's work (writer appends,
    /// disk I/O).
    public func flush(now: TimeInterval) {
        queue.async { [self] in
            guard let startTime, !hasFinished else { return }
            let frame = Int(((now - Self.settleWindow - startTime) * PCMResampler.sampleRate).rounded())
            emit(accumulator.drain(upTo: frame))
        }
    }

    /// Emits the remainder and closes the timeline.
    public func finish() {
        queue.sync { [self] in
            guard startTime != nil, !hasFinished else { return }
            hasFinished = true
            emit(accumulator.drainAll())
        }
    }

    /// Returns once every previously enqueued operation has run. The queue is
    /// serial and FIFO, so an empty synchronous block is a sufficient barrier.
    /// Exists for tests: production code never needs to wait for the mixer.
    internal func waitForPendingWork() {
        queue.sync {}
    }

    private func emit(_ drained: (startFrame: Int, samples: [Float])?) {
        guard let drained, !drained.samples.isEmpty else { return }
        sink?(MixedAudioChunk(startFrame: drained.startFrame, samples: drained.samples))
    }
}
