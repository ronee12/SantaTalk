import Foundation

/// Small formatting helpers shared across screens.
enum Format {

    /// `134` → `"2:14"`.
    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// `39.99` → `"$39.99"`.
    static func money(_ amount: Double) -> String {
        String(format: "$%.2f", (amount * 100).rounded() / 100)
    }

    /// Today, Tomorrow, then twelve days of `Sat 8 Aug`.
    static func dayLabels(from reference: Date = .now, calendar: Calendar = .current) -> [String] {
        var labels = ["Today", "Tomorrow"]
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        for offset in 2..<14 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: reference) else { continue }
            let parts = calendar.dateComponents([.weekday, .day, .month], from: date)
            guard let weekday = parts.weekday, let day = parts.day, let month = parts.month else { continue }
            labels.append("\(weekdays[weekday - 1]) \(day) \(months[month - 1])")
        }
        return labels
    }

    /// `"1 August"` — the renewal date under the paywall button.
    static func renewalDate(inDays days: Int, from reference: Date = .now) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: reference) ?? reference
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

/// One plan's price as the App Store actually states it, in the parent's own
/// currency and format.
///
/// Deliberately free of any RevenueCat type: `SubscriptionRepository` builds
/// these, and everything downstream — `Pricing`, the paywall, the receipt — can
/// then be reasoned about, previewed and read without the store in the picture.
struct StorePrice: Equatable {
    /// Already localized: `"$39.99"`, `"£34.99"`, `"3 900 ¥"`.
    let display: String
    /// The yearly plan divided across 52 weeks, formatted in the same currency.
    /// Nil for plans where a weekly rate would be meaningless.
    let perWeek: String?
    /// Length of the introductory offer attached to this product, in days. Nil
    /// when the product carries no trial — which is different from a trial this
    /// particular parent has already used up.
    let trialDays: Int?
}

/// The prices shown on the paywall.
///
/// The hardcoded values match the comp and are what the paywall renders until
/// RevenueCat answers — a first launch on a slow connection shows plausible
/// prices rather than three empty tiles. Once `store` is filled the real,
/// localized prices win everywhere, because those are the only ones the parent
/// will actually be charged.
struct Pricing {
    var week: Double = 6.99
    var month: Double = 12.99
    var year: Double = 39.99
    /// The fallback trial length, used only while the store is silent. The real
    /// number comes from the product's introductory offer.
    var defaultTrialDays: Int = 3

    /// Filled by `AppState` once the offering loads. Empty means "not yet", not
    /// "free".
    var store: [SubscriptionPlan: StorePrice] = [:]

    /// Whether this parent can still take an introductory offer. False suppresses
    /// every mention of a free trial: promising one to somebody Apple will charge
    /// immediately is how refund requests start.
    var isEligibleForIntroOffer: Bool = true

    func price(for plan: SubscriptionPlan) -> Double {
        switch plan {
        case .week: week
        case .month: month
        case .year: year
        }
    }

    /// What the tile shows. The store's own string when there is one, so the
    /// currency and its formatting are Apple's rather than ours.
    func display(for plan: SubscriptionPlan) -> String {
        store[plan]?.display ?? Format.money(price(for: plan))
    }

    /// The unit line under each price.
    ///
    /// Monthly and yearly both restate themselves per week so the three tiles can
    /// be compared in one glance — $6.99, $3.00 and $0.77 a week is a ladder a
    /// parent reads instantly, where $6.99, $12.99 and $39.99 is not.
    func perLabel(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .week:
            return "per week"
        case .month, .year:
            return "\(store[plan]?.perWeek ?? Format.money(fallbackPerWeek(for: plan))) / wk"
        }
    }

    /// Used only before the store answers, so it divides the hardcoded price by
    /// the same period length `StorePrice` would have used.
    private func fallbackPerWeek(for plan: SubscriptionPlan) -> Double {
        let weeks = NSDecimalNumber(decimal: plan.weeksPerPeriod).doubleValue
        return weeks > 0 ? price(for: plan) / weeks : price(for: plan)
    }

    /// How many free days this plan actually offers this parent. Zero once they
    /// have used their introductory offer, whatever the product still advertises.
    func trialDays(for plan: SubscriptionPlan) -> Int {
        guard isEligibleForIntroOffer else { return 0 }
        return store[plan]?.trialDays ?? (plan == .year ? defaultTrialDays : 0)
    }

    func renewalDate(for plan: SubscriptionPlan) -> String {
        Format.renewalDate(inDays: trialDays(for: plan))
    }

    /// "week", "month", "year" — the noun the fineprint and the receipt bill in.
    private func period(_ plan: SubscriptionPlan) -> String {
        switch plan {
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
    }

    /// One line under the button: the exact renewal date and price, never behind a link.
    func fineprint(for plan: SubscriptionPlan) -> String {
        let price = display(for: plan)
        let unit = period(plan)
        let days = trialDays(for: plan)
        return days > 0
            ? "\(days) days free, then \(price) a \(unit) on \(renewalDate(for: plan)). Cancel any time."
            : "\(price) a \(unit). Cancel any time."
    }

    /// The receipt line on the confirmation screen, repeating what was bought.
    func receipt(for plan: SubscriptionPlan) -> String {
        let price = display(for: plan)
        let unit = period(plan)
        let days = trialDays(for: plan)
        return days > 0
            ? "Free until \(renewalDate(for: plan)). After that \(price) a \(unit)."
            : "\(price) a \(unit). Cancel any time in Settings."
    }
}
