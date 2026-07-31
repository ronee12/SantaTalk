import AVFoundation
import LiveKit
import Observation
import SantaAudioMixer

/// Turns a live call into a file. The only recording type `AppState` talks to.
///
/// Every entry point is failure-tolerant on purpose. The child is talking to
/// Santa; the recording is a souvenir, and a souvenir must never be the reason a
/// call goes wrong.
@Observable
@MainActor
final class CallRecorder {

    struct RecordedFile {
        let url: URL
        let durationSeconds: Int
        let hasVideo: Bool
    }

    /// A call shorter than this is a connection that failed, not a memory.
    private static let minimumSeconds = 2

    private(set) var isRecording = false

    @ObservationIgnored private let camera: CameraCapture
    @ObservationIgnored private let mixer = AudioTimelineMixer()
    @ObservationIgnored private var writer: RecordingWriter?
    @ObservationIgnored private var childTrack: (track: LocalAudioTrack, tap: ConversationAudioTap)?
    @ObservationIgnored private var santaTrack: (track: RemoteAudioTrack, tap: ConversationAudioTap)?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var startTime: TimeInterval = 0

    /// The camera is shared with the preview, which runs whether or not this
    /// recorder does.
    init(camera: CameraCapture) {
        self.camera = camera
    }

    /// Begins writing. A failure here leaves `isRecording` false and is silent —
    /// there is nothing a parent could do about it mid-call.
    func start(keepVideo: Bool) {
        guard !isRecording else { return }

        startTime = CACurrentMediaTime()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("call-\(UUID().uuidString).mov")

        // A video track is only created if the camera is genuinely running. An
        // input that never receives a sample can fail the whole write.
        let videoEnabled = keepVideo && camera.isRunning

        guard let writer = try? RecordingWriter(
            url: url, startTime: startTime, videoEnabled: videoEnabled
        ) else { return }
        self.writer = writer

        mixer.start(at: startTime) { [weak writer] chunk in
            writer?.append(chunk)
        }

        if writer.hasVideoTrack {
            camera.onFrame = { [weak writer] sampleBuffer in
                writer?.appendVideo(sampleBuffer)
            }
        }

        flushTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                self?.mixer.flush(now: CACurrentMediaTime())
            }
        }

        isRecording = true
    }

    func attach(child track: LocalAudioTrack) {
        guard isRecording, childTrack == nil else { return }
        let tap = makeTap(for: .child)
        childTrack = (track, tap)
        track.add(audioRenderer: tap)
    }

    func attach(santa track: RemoteAudioTrack) {
        guard isRecording, santaTrack == nil else { return }
        let tap = makeTap(for: .santa)
        santaTrack = (track, tap)
        track.add(audioRenderer: tap)
    }

    /// Closes the file. Returns nil when there is nothing worth keeping.
    func finish() async -> RecordedFile? {
        guard isRecording, let writer else { return nil }
        isRecording = false

        flushTask?.cancel()
        flushTask = nil
        detachTaps()
        camera.onFrame = nil

        mixer.flush(now: CACurrentMediaTime())
        mixer.finish()

        let duration = Int((CACurrentMediaTime() - startTime).rounded())
        // Read after `finish()` completes, not before: a zero-frame video
        // track only reveals itself as such inside `finish()`, and this must
        // reflect what the file actually contains — that value is stored in
        // the database and decides whether the player shows a video tile or
        // an "audio only" placeholder.
        let finished = await writer.finish()
        let hasVideo = writer.hasVideoTrack
        self.writer = nil

        guard let finished else { return nil }
        guard duration >= Self.minimumSeconds else {
            try? FileManager.default.removeItem(at: finished)
            return nil
        }
        return RecordedFile(url: finished, durationSeconds: duration, hasVideo: hasVideo)
    }

    /// Abandons the recording and removes the partial file.
    func cancel() {
        Task { @MainActor in
            if let file = await finish() {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
    }

    private func makeTap(for source: MixSource) -> ConversationAudioTap {
        ConversationAudioTap(source: source) { [mixer] buffer, source, time in
            mixer.accept(buffer, from: source, arrivedAt: time)
        }
    }

    private func detachTaps() {
        if let childTrack { childTrack.track.remove(audioRenderer: childTrack.tap) }
        if let santaTrack { santaTrack.track.remove(audioRenderer: santaTrack.tap) }
        childTrack = nil
        santaTrack = nil
    }
}
