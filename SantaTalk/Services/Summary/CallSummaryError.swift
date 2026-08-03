import Foundation
import SantaCallSummary

/// Every way a summary can fail to arrive, reduced to what a parent can act on.
///
/// A parent-facing screen, so unlike `SantaCallError` this may be a touch more
/// specific — a parent who is told the recording has no sound knows not to keep
/// tapping. It still never surfaces a status code or a model name.
enum CallSummaryError: Error, Equatable {
    /// The file the row points at is gone.
    case recordingMissing
    /// There is a file, but there is nothing to listen to in it.
    case noSound
    /// Longer than one request can carry.
    case tooLong
    case offline
    /// The model answered with something that was not a summary.
    case unreadableAnswer
    /// Anything else — App Check refused, quota, a bad key, a dropped request.
    case failed

    var message: String {
        switch self {
        case .recordingMissing:
            "This recording's file is missing, so there is nothing to summarise."
        case .noSound:
            "There is no sound in this recording to summarise."
        case .tooLong:
            "This call is too long to summarise in one go."
        case .offline:
            "No connection. Try again once you're back online."
        case .unreadableAnswer, .failed:
            "Santa's helpers couldn't listen just now. Try again in a moment."
        }
    }

    /// Everything upstream of the model — the file, the audio track, the export.
    static func from(_ failure: CallAudioExtractor.Failure) -> CallSummaryError {
        switch failure {
        case .noAudioTrack: .noSound
        case .tooLong: .tooLong
        case .cannotStart: .failed
        }
    }

    /// `URLError` is the only underlying error worth reading: it is the
    /// difference between "you are on a train" and "something is wrong", and a
    /// parent can do something about the first.
    static func from(_ error: any Error) -> CallSummaryError {
        if let known = error as? CallSummaryError { return known }
        if let failure = error as? CallAudioExtractor.Failure { return from(failure) }
        if error is CallSummaryDecoder.Failure { return .unreadableAnswer }

        guard let urlError = error as? URLError else { return .failed }

        return switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .cannotFindHost, .cannotConnectToHost, .timedOut,
             .dataNotAllowed, .internationalRoamingOff:
            .offline
        default:
            .failed
        }
    }
}
