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
    /// Declaration order is tile order, cheapest commitment first.
    case week, month, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Weekly"
        case .month: "Monthly"
        case .year: "Yearly"
        }
    }

    var ribbon: String {
        switch self {
        case .week: "Cancel Anytime"
        case .month: "Flexible"
        case .year: "Most Popular"
        }
    }

    /// How many weeks the plan bills for, used to state every tile's cost in the
    /// same unit. A month is the average — 52 weeks over 12 — rather than four,
    /// which would overstate the weekly rate by about eight percent.
    var weeksPerPeriod: Decimal {
        switch self {
        case .week: 1
        case .month: Decimal(52) / 12
        case .year: 52
        }
    }

    /// The RevenueCat package this tile buys.
    ///
    /// These are RevenueCat's own standard identifiers, which its dashboard
    /// assigns automatically when a package is created from a template. If the
    /// offering was built with custom identifiers instead, these three strings
    /// are the only thing that has to change — nothing else in the app names a
    /// package.
    var packageID: String {
        switch self {
        case .week: "$rc_weekly"
        case .month: "$rc_monthly"
        case .year: "$rc_annual"
        }
    }
}

/// Which permission state the microphone request is in.
enum PermissionState {
    case idle, asking, granted, denied
}
