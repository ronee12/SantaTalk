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
/// `accept`, `flush`, and `finish` all hop onto the same serial queue
/// synchronously: state has been applied and any resulting chunk handed to the
/// sink by the time the call returns. That is what lets tests call `accept`
/// then `flush` then assert with no synchronization of their own.
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
    public func accept(_ buffer: AVAudioPCMBuffer, from source: MixSource, arrivedAt time: TimeInterval) {
        queue.sync { [self] in
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
    public func flush(now: TimeInterval) {
        queue.sync { [self] in
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

    private func emit(_ drained: (startFrame: Int, samples: [Float])?) {
        guard let drained, !drained.samples.isEmpty else { return }
        sink?(MixedAudioChunk(startFrame: drained.startFrame, samples: drained.samples))
    }
}
