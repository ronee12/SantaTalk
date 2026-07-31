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

/// Something a child asked Santa for, in their own words.
struct Wish: Identifiable, Hashable {
    let id = UUID()
    let item: String
    let quote: String
    let heard: String
}

/// A child profile. Santa keeps a separate memory for each and never mixes them up.
struct Child: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var gender: String
    var age: Int
    var tint: Color
    var badge: String
    var knowledge: Int
    var saysAs: String
    var wishes: [Wish]

    var detail: String { "\(gender) · \(age) years old" }
}

/// A call the parent has booked for later.
struct ScheduledCall: Identifiable, Hashable {
    let id: String
    let childName: String
    let when: String
    let topic: String

    var detail: String { "\(childName) · \(topic)" }
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

/// The tone the phone plays before Santa picks up.
struct Ringtone: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
}

/// Which permission state the microphone request is in.
enum PermissionState {
    case idle, asking, granted, denied
}
