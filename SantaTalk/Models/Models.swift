import SwiftUI

/// One of the languages Santa can call in. Native name leads — a Greek parent scans
/// Ελληνικά, not "Greek".
struct Language: Identifiable, Hashable {
    let flag: String
    let native: String
    let english: String

    var id: String { english }
    /// The English name is hidden when it is the same word as the native one.
    var subtitle: String { native == english ? "" : english }
}

/// One line in the chat thread.
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let isFromSanta: Bool
    let text: String
}

/// How soon Santa should ring.
struct CallTiming: Identifiable, Hashable {
    let seconds: Int
    let label: String

    var id: Int { seconds }
    /// A minute or more is a schedule, not a countdown.
    var isLater: Bool { seconds >= 60 }
}

/// The three subscription options on the paywall.
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case week, year, life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Weekly"
        case .year: "Yearly"
        case .life: "Lifetime"
        }
    }

    var ribbon: String {
        switch self {
        case .week: "Cancel Anytime"
        case .year: "Most Popular"
        case .life: "Limited Offer"
        }
    }
}

/// Which permission state the microphone request is in.
enum PermissionState {
    case idle, asking, granted, denied
}
