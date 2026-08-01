import AVFoundation
import Foundation
import Synchronization

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

    /// Where the next buffer from each source will be written.
    ///
    /// A stream's own samples are the clock, not the instant they happened to
    /// reach us. Arrival times jitter and buffers come in bursts, so positioning
    /// each one by wall-clock would overlap consecutive buffers (summing a voice
    /// on top of itself) and punch gaps between others — which is heard as
    /// tearing and distortion rather than as a timing error. Only the *first*
    /// buffer of a source is placed by arrival time; every one after it is laid
    /// end to end.
    private var nextFrame: [MixSource: Int] = [:]

    /// How far a source may drift from wall-clock before its cursor is reset.
    ///
    /// A source that genuinely stopped — the child muted, the agent finished
    /// talking and the track went idle — would otherwise resume writing where it
    /// left off, dragging the rest of its audio earlier and earlier. A gap this
    /// large is a real silence, not jitter, so the cursor re-anchors.
    private static let resyncThreshold: TimeInterval = 0.5

    /// A cheap, lock-free hint that lets `accept` skip the snapshot copy while
    /// the mixer is inert (before `start`, or after `finish`) without having to
    /// hop onto `queue` first. It is an optimisation only — `startTime` and
    /// `hasFinished`, read inside the queue block, remain the actual
    /// correctness boundary. A stale "true" read here (a race between this and
    /// `finish`) just means one extra snapshot gets thrown away by the
    /// `hasFinished` check below; that's already handled and fine.
    private let isActive = Atomic<Bool>(false)

    public init() {}

    /// Begins a recording timeline anchored at `time`, which must come from the
    /// same clock the `arrivedAt` stamps use.
    public func start(at time: TimeInterval, sink: @escaping Sink) {
        queue.sync {
            accumulator = TimelineAccumulator()
            resamplers = [:]
            nextFrame = [:]
            startTime = time
            self.sink = sink
            hasFinished = false
        }
        isActive.store(true, ordering: .relaxed)
    }

    /// Called from a LiveKit audio thread, twice over for a two-way call.
    ///
    /// Non-blocking by design: this runs on a real-time audio-rendering thread,
    /// and must never wait on whatever else is ahead of it on the queue (a
    /// flush whose sink is doing disk I/O, for instance).
    ///
    /// `buffer` comes from WebRTC's native audio device layer via
    /// `RTCAudioRenderer.renderPCMBuffer:`, whose header declares no ownership
    /// or lifetime contract — buffers are commonly served from a reuse pool and
    /// may be overwritten the instant this call returns. The sample data and
    /// format are therefore copied out synchronously, right here, before
    /// anything is handed to the queue; only the copy — memory this mixer
    /// owns — is ever touched from the async block below.
    public func accept(_ buffer: AVAudioPCMBuffer, from source: MixSource, arrivedAt time: TimeInterval) {
        guard isActive.load(ordering: .relaxed) else { return }
        guard let snapshot = Self.snapshot(of: buffer) else { return }

        // The snapshot buffer is uniquely owned by this call the instant
        // `snapshot(of:)` returns it — nothing else holds a reference — so
        // handing it to the queue is safe even though `AVAudioPCMBuffer` isn't
        // `Sendable`. `nonisolated(unsafe)` silences the resulting capture
        // warning deliberately, rather than leaving it as ambient noise that
        // could mask a real aliasing bug later.
        nonisolated(unsafe) let snapshotToStore = snapshot

        queue.async { [self] in
            guard let startTime, !hasFinished else { return }

            let resampler = resamplers[source] ?? {
                let made = PCMResampler()
                resamplers[source] = made
                return made
            }()

            let samples = resampler.monoFloats(from: snapshotToStore)
            guard !samples.isEmpty else { return }

            // Where wall-clock says this buffer ends. Rounded rather than
            // truncated — floating-point subtraction can land a hair under the
            // true value (e.g. 1.1 as 1.0999999999999943), and truncating that
            // would clip a frame that should have been included.
            let arrivalEnd = Int(((time - startTime) * PCMResampler.sampleRate).rounded())
            let arrivalStart = max(0, arrivalEnd - samples.count)

            // Lay the buffer immediately after this source's previous one. Only
            // when there is no cursor yet, or the stream has been silent long
            // enough that the gap is real rather than jitter, does wall-clock
            // get a say.
            let drift = Self.resyncThreshold * PCMResampler.sampleRate
            let start: Int
            if let cursor = nextFrame[source], Double(abs(arrivalStart - cursor)) < drift {
                start = cursor
            } else {
                start = arrivalStart
            }

            accumulator.add(samples, at: start)
            nextFrame[source] = start + samples.count
        }
    }

    /// A byte-for-byte copy of `buffer`'s sample data in a freshly allocated
    /// buffer of the same format, so downstream code (`PCMResampler`, in
    /// particular the per-source converter/downmix caches it touches only from
    /// the mixer's queue) can keep treating the result exactly like the
    /// original without knowing it no longer aliases caller-owned memory.
    ///
    /// Cheap and allocation-light by design — this runs synchronously on the
    /// caller's real-time audio thread. It copies bytes only; format
    /// conversion (`PCMResampler.monoFloats`) stays off this path and runs
    /// later on the mixer's queue.
    ///
    /// Handles both Float32 and Int16 samples, interleaved or not — the same
    /// four layouts `PCMResampler` already accepts. Returns `nil` if the
    /// buffer is empty, its format doesn't yield a fresh buffer, or its
    /// storage isn't one of those recognised layouts; the caller drops the
    /// buffer in that case rather than risk a crash or a race.
    private static func snapshot(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let frames = buffer.frameLength
        guard frames > 0 else { return nil }
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frames) else { return nil }
        copy.frameLength = frames

        let channelCount = Int(buffer.format.channelCount)
        let sampleCount = buffer.format.isInterleaved ? Int(frames) * channelCount : Int(frames)

        if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
            if buffer.format.isInterleaved {
                destination[0].update(from: source[0], count: sampleCount)
            } else {
                for channel in 0 ..< channelCount {
                    destination[channel].update(from: source[channel], count: sampleCount)
                }
            }
            return copy
        }

        if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
            if buffer.format.isInterleaved {
                destination[0].update(from: source[0], count: sampleCount)
            } else {
                for channel in 0 ..< channelCount {
                    destination[channel].update(from: source[channel], count: sampleCount)
                }
            }
            return copy
        }

        return nil
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
        isActive.store(false, ordering: .relaxed)
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
