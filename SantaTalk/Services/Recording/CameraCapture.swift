import AVFoundation
import CoreMedia
import Foundation
import Observation

/// The child's camera. Video only — never an audio input, because LiveKit owns
/// `AVAudioSession` for the duration of the call and a second claim on the
/// microphone would put the live call at risk for the sake of a souvenir.
///
/// Observable because `isRunning` decides whether the call screen draws a
/// preview or a placeholder, and the session starts on a background queue a
/// beat after the view has already been laid out.
@Observable
@MainActor
final class CameraCapture {

    /// Triggers the real system camera prompt, after our own explainer screen
    /// has stated the reason.
    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// What iOS currently thinks. Asked rather than stored, for the same reason
    /// the microphone state is: the system's answer outlives our copy of it.
    static var permissionState: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        default: .idle
        }
    }

    let session = AVCaptureSession()

    /// Called on a background queue for every frame.
    var onFrame: (@Sendable (CMSampleBuffer) -> Void)? {
        get { forwarder.onFrame }
        set { forwarder.onFrame = newValue }
    }

    private(set) var isRunning = false

    private let output = AVCaptureVideoDataOutput()
    private let forwarder = FrameForwarder()
    private let queue = DispatchQueue(label: "com.santatalk.camera")
    @ObservationIgnored private var isConfigured = false
    /// Intent, not observation: `isRunning` only flips after the `await` inside
    /// `startRunning()` completes, so a `stopRunning()` that lands during that
    /// window needs somewhere else to record "actually, no" — this is it.
    @ObservationIgnored private var wantsRunning = false

    /// Configures on first call, then starts. Returns false if the camera is
    /// denied, missing, or already claimed by something else — all of which the
    /// caller treats the same way: carry on without video.
    func startRunning() async -> Bool {
        guard Self.permissionState == .granted else { return false }
        guard !isRunning else { return true }

        wantsRunning = true

        if !isConfigured {
            guard configure() else {
                wantsRunning = false
                return false
            }
            isConfigured = true
        }

        // `startRunning()` blocks, sometimes for hundreds of milliseconds. It
        // must never run on the thread drawing the call.
        let session = session
        await withCheckedContinuation { continuation in
            queue.async {
                session.startRunning()
                continuation.resume()
            }
        }

        // `stopRunning()` may have arrived while the await above was in
        // flight, when `isRunning` was still false and so had nothing to act
        // on. Honor that now rather than leaving the session running.
        guard wantsRunning else {
            queue.async { session.stopRunning() }
            isRunning = false
            return false
        }

        isRunning = session.isRunning
        return isRunning
    }

    func stopRunning() {
        wantsRunning = false
        guard isRunning else { return }
        isRunning = false
        let session = session
        queue.async { session.stopRunning() }
    }

    private func configure() -> Bool {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ), let input = try? AVCaptureDeviceInput(device: device) else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        // This session is video-only. LiveKit owns `AVAudioSession` in
        // `playAndRecord` for the whole call, and the default `true` here
        // would let AVFoundation reconfigure the shared audio session out
        // from under the live call — so opt out explicitly rather than rely
        // on "we never add an audio input" alone.
        session.automaticallyConfiguresApplicationAudioSession = false

        guard session.canAddInput(input) else { return false }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(forwarder, queue: queue)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            return false
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            // Portrait, and mirrored on the recording as well as the preview, so
            // replay shows the child the way round they saw themselves.
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        return true
    }
}

/// `AVCaptureVideoDataOutput` wants an `NSObject` delegate called off the main
/// actor, which `CameraCapture` cannot be. Explicitly `nonisolated` because
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` would otherwise pull an
/// unannotated class onto the main actor — defeating the entire point of a
/// forwarder that exists to receive capture callbacks off it.
private nonisolated final class FrameForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Written on the main actor, read on the capture queue — `@unchecked
    /// Sendable` only silences the compiler, so the access itself is guarded
    /// by a lock.
    private let lock = NSLock()
    private var _onFrame: (@Sendable (CMSampleBuffer) -> Void)?

    var onFrame: (@Sendable (CMSampleBuffer) -> Void)? {
        get { lock.withLock { _onFrame } }
        set { lock.withLock { _onFrame = newValue } }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
