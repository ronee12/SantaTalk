import AVFoundation

/// The child's camera. Video only — never an audio input, because LiveKit owns
/// `AVAudioSession` for the duration of the call and a second claim on the
/// microphone would put the live call at risk for the sake of a souvenir.
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
}
