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

    static let presetSchedules = [
        "Tonight, 6:30 PM", "Tonight, 7:00 PM", "Tonight, 7:30 PM", "Tomorrow, 6:30 PM"
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

    static let ringtones: [Ringtone] = [
        .init(id: "sleigh", name: "Sleigh Bells", detail: "Bells getting closer"),
        .init(id: "chimes", name: "Jingle Chimes", detail: "Soft, good for bedtime"),
        .init(id: "classic", name: "Classic Ring", detail: "Sounds like the house phone"),
        .init(id: "music", name: "Music Box", detail: "Slow and quiet")
    ]

    /// The four premium lines on the paywall.
    static let premiumFeatures = [
        "Unlimited Santa Calls",
        "Unlimited Chat with Santa",
        "Recordings & wish list",
        "Up to 4 children"
    ]
}

/// The sample content the prototype ships with.
enum SampleData {

    static let children: [Child] = [
        Child(
            name: "Maya", gender: "Girl", age: 6, tint: Palette.tintGirl,
            badge: "Calling tonight", knowledge: 72, saysAs: "“MY-uh”, not “MAY-uh”",
            wishes: [
                Wish(item: "A purple bike",
                     quote: "the one with a bell on it, like Ava’s but purple",
                     heard: "Heard in the first call"),
                Wish(item: "Roller skates",
                     quote: "the kind that light up when you go fast",
                     heard: "Heard yesterday")
            ]
        ),
        Child(
            name: "Ben", gender: "Boy", age: 4, tint: Palette.tintBoy,
            badge: "", knowledge: 38, saysAs: "“Ben”, never “Benjamin”",
            wishes: [
                Wish(item: "A shark book",
                     quote: "a big one with the teeth pictures",
                     heard: "Typed in chat")
            ]
        )
    ]

    static let recordings: [Recording] = [
        Recording(
            id: "r1", childName: "Maya", title: "The school play",
            date: "2026-07-29", time: "7:14 PM", seconds: 134, hasReaction: true,
            summary: "Santa asked about the school play and she told him she is a snowflake in it. She promised to be kinder to her little brother, then asked twice whether reindeer sleep standing up."
        ),
        Recording(
            id: "r2", childName: "Maya", title: "Being brave",
            date: "2026-07-28", time: "6:40 PM", seconds: 130, hasReaction: false,
            summary: "Shy for the first minute, then she asked whether the elves get holidays. Santa mentioned the purple bike without promising it."
        ),
        Recording(
            id: "r3", childName: "Ben", title: "First hello",
            date: "2026-07-26", time: "7:02 PM", seconds: 98, hasReaction: true,
            summary: "His first call. Mostly laughing. He told Santa his name three times to make sure he had it right, and asked if Santa could see his room."
        )
    ]

    static let schedules: [ScheduledCall] = [
        ScheduledCall(id: "s0", childName: "Ben", when: "Tomorrow · 6:30 PM",
                      topic: "Being brave at the dentist")
    ]

    static let chat: [ChatMessage] = [
        ChatMessage(isFromSanta: true,
                    text: "Ho ho ho! The elves told me someone here has been very helpful this week."),
        ChatMessage(isFromSanta: false, text: "She has! She tidied her whole room."),
        ChatMessage(isFromSanta: true,
                    text: "Then I shall mention it when I call. Shall I bring up her wish list too?")
    ]
}
