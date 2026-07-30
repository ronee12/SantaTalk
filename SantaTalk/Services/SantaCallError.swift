import Foundation

/// Every failure a child could witness, reduced to the three story beats the
/// design system allows. Never surfaces a status code, an error string, or a price.
enum SantaCallError: Error, Equatable {
    /// Out of credits, or asking too often.
    case busy
    /// No network, or the North Pole is unreachable.
    case offline
    /// Anything else — an auth failure, a bad response, a dropped session.
    case dropped

    var childFacingMessage: String {
        switch self {
        case .busy: "Santa's busy right now — ask a grown-up."
        case .offline: "The North Pole line is down. Try again soon."
        case .dropped: "Santa got cut off — the elves are fixing it."
        }
    }

    /// Maps a backend response to a story beat. The reason codes are the ones
    /// `santa_backend/src/lib/errors.ts` can emit.
    static func from(statusCode: Int, reason: String?) -> SantaCallError {
        switch reason {
        case "no_credits", "rate_limited": .busy
        case "upstream_unavailable": .offline
        default: statusCode == 503 ? .offline : .dropped
        }
    }
}
