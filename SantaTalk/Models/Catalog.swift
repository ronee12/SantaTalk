import SantaScheduling
import SwiftUI

/// Every fixed list the UI offers. Content only — no behaviour.
enum Catalog {

    /// The thirty-two languages Santa speaks, in the comp's order.
    static let languages: [Language] = [
        .init(flag: "🇬🇧", native: "English", english: "English"),
        .init(flag: "🇪🇸", native: "Español", english: "Spanish"),
        .init(flag: "🇫🇷", native: "Français", english: "French"),
        .init(flag: "🇵🇹", native: "Português", english: "Portuguese"),
        .init(flag: "🇸🇦", native: "العربية", english: "Arabic"),
        .init(flag: "🇩🇪", native: "Deutsch", english: "German"),
        .init(flag: "🇮🇹", native: "Italiano", english: "Italian"),
        .init(flag: "🇳🇱", native: "Nederlands", english: "Dutch"),
        .init(flag: "🇵🇱", native: "Polski", english: "Polish"),
        .init(flag: "🇸🇪", native: "Svenska", english: "Swedish"),
        .init(flag: "🇩🇰", native: "Dansk", english: "Danish"),
        .init(flag: "🇳🇴", native: "Norsk", english: "Norwegian"),
        .init(flag: "🇫🇮", native: "Suomi", english: "Finnish"),
        .init(flag: "🇨🇿", native: "Čeština", english: "Czech"),
        .init(flag: "🇸🇰", native: "Slovenčina", english: "Slovak"),
        .init(flag: "🇭🇷", native: "Hrvatski", english: "Croatian"),
        .init(flag: "🇷🇴", native: "Română", english: "Romanian"),
        .init(flag: "🇧🇬", native: "Български", english: "Bulgarian"),
        .init(flag: "🇬🇷", native: "Ελληνικά", english: "Greek"),
        .init(flag: "🇭🇺", native: "Magyar", english: "Hungarian"),
        .init(flag: "🇺🇦", native: "Українська", english: "Ukrainian"),
        .init(flag: "🇷🇺", native: "Русский", english: "Russian"),
        .init(flag: "🇹🇷", native: "Türkçe", english: "Turkish"),
        .init(flag: "🇯🇵", native: "日本語", english: "Japanese"),
        .init(flag: "🇰🇷", native: "한국어", english: "Korean"),
        .init(flag: "🇨🇳", native: "中文", english: "Mandarin"),
        .init(flag: "🇮🇳", native: "हिन्दी", english: "Hindi"),
        .init(flag: "🇮🇳", native: "தமிழ்", english: "Tamil"),
        .init(flag: "🇮🇩", native: "Bahasa Indonesia", english: "Indonesian"),
        .init(flag: "🇲🇾", native: "Bahasa Melayu", english: "Malay"),
        .init(flag: "🇵🇭", native: "Filipino", english: "Filipino"),
        .init(flag: "🇻🇳", native: "Tiếng Việt", english: "Vietnamese")
    ]

    /// Maps the phone's locale onto a language so most parents just tap Continue.
    static func language(forLocaleIdentifier identifier: String) -> Language? {
        let map: [String: String] = [
            "en": "English", "es": "Spanish", "fr": "French", "pt": "Portuguese", "ar": "Arabic",
            "de": "German", "it": "Italian", "nl": "Dutch", "pl": "Polish", "sv": "Swedish",
            "da": "Danish", "nb": "Norwegian", "no": "Norwegian", "fi": "Finnish", "cs": "Czech",
            "sk": "Slovak", "hr": "Croatian", "ro": "Romanian", "bg": "Bulgarian", "el": "Greek",
            "hu": "Hungarian", "uk": "Ukrainian", "ru": "Russian", "tr": "Turkish", "ja": "Japanese",
            "ko": "Korean", "zh": "Mandarin", "hi": "Hindi", "ta": "Tamil", "id": "Indonesian",
            "ms": "Malay", "fil": "Filipino", "vi": "Vietnamese"
        ]
        let base = identifier.split(separator: "-").first.map(String.init) ?? identifier
        guard let english = map[identifier] ?? map[base] else { return nil }
        return languages.first { $0.english == english }
    }

    static let timings: [CallTiming] = [
        .init(seconds: 3, label: "In 3 seconds"),
        .init(seconds: 10, label: "In 10 seconds"),
        .init(seconds: 30, label: "In 30 seconds"),
        .init(seconds: 60, label: "In 1 minute"),
        .init(seconds: 300, label: "In 5 minutes")
    ]

    /// Parts rather than dates, so "Tonight, 6:30 PM" still means half past six
    /// this evening however long the app has been open. Ones whose moment has
    /// already gone are filtered off the sheet — see `AppState.availablePresets`.
    static let presetSchedules: [PresetSchedule] = [
        .init(label: "Tonight, 6:30 PM", dayOffset: 0, hour: 18, minute: 30),
        .init(label: "Tonight, 7:00 PM", dayOffset: 0, hour: 19, minute: 0),
        .init(label: "Tonight, 7:30 PM", dayOffset: 0, hour: 19, minute: 30),
        .init(label: "Tomorrow, 6:30 PM", dayOffset: 1, hour: 18, minute: 30)
    ]

    /// A predefined list, because free text is where a parent stalls.
    static let topics = [
        "The Christmas wish list",
        "Being kind to a brother or sister",
        "Bedtime without a fuss",
        "Trying new foods",
        "Tidying up toys",
        "Well done on swimming",
        "Just a hello from the North Pole"
    ]

    /// Twelve options, deliberately gender-neutral in order.
    static let interests = [
        "Dinosaurs", "Space", "Drawing", "Dogs", "Football", "LEGO",
        "Dancing", "Trains", "Baking", "Mermaids", "Cars", "Dressing up"
    ]

    static let secretExamples = [
        "Lost her first tooth", "Her brother is Theo", "Learning to swim", "Her cat is Biscuit"
    ]

    static let ages = [3, 4, 5, 6, 7, 8, 9, 10]

    /// The four premium lines on the paywall.
    static let premiumFeatures = [
        "Unlimited Santa Calls",
        "Unlimited Chat with Santa",
        "Recordings & wish list",
        "Up to 4 children"
    ]
}

/// The sample content the prototype ships with.
///
/// Children are no longer here — they are rows in SwiftData, written by
/// onboarding and the vault. What remains is content with no capture path yet.
enum SampleData {

    static let chat: [ChatMessage] = [
        ChatMessage(isFromSanta: true,
                    text: "Ho ho ho! The elves told me someone here has been very helpful this week."),
        ChatMessage(isFromSanta: false, text: "She has! She tidied her whole room."),
        ChatMessage(isFromSanta: true,
                    text: "Then I shall mention it when I call. Shall I bring up her wish list too?")
    ]
}
