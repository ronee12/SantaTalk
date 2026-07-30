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

/// The prices shown on the paywall. Values match the comp's defaults.
struct Pricing {
    var year: Double = 39.99
    var week: Double = 6.99
    var lifetime: Double = 79.99
    var trialDays: Int = 3

    var perWeek: Double { year / 52 }
    var renewalDate: String { Format.renewalDate(inDays: trialDays) }

    func price(for plan: SubscriptionPlan) -> Double {
        switch plan {
        case .week: week
        case .year: year
        case .life: lifetime
        }
    }

    func perLabel(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .week: "per week"
        case .year: "\(Format.money(perWeek)) / wk"
        case .life: "one payment"
        }
    }

    /// One line under the button: the exact renewal date and price, never behind a link.
    func fineprint(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .life:
            "One payment of \(Format.money(lifetime)). No renewal, ever."
        case .week:
            "\(Format.money(week)) a week. Cancel any time."
        case .year:
            trialDays > 0
                ? "\(trialDays) days free, then \(Format.money(year)) a year on \(renewalDate). Cancel any time."
                : "\(Format.money(year)) a year. Cancel any time."
        }
    }

    /// The receipt line on the confirmation screen, repeating what was bought.
    func receipt(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .life:
            "Paid once, \(Format.money(lifetime)). Nothing will renew."
        case .week:
            "\(Format.money(week)) a week. Cancel any week in Settings."
        case .year:
            trialDays > 0
                ? "Free until \(renewalDate). After that \(Format.money(year)) a year."
                : "\(Format.money(year)) a year. Cancel any time in Settings."
        }
    }
}
