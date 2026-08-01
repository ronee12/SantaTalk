import Foundation

/// Everything needed to start a scheduled call, as it travels in a link.
///
/// The id alone would be enough while the row exists. Carrying the rest makes
/// the link self-describing, and lets a tap still ring the right call for the
/// right child if the row has since been swept — a notification can outlive the
/// thing that scheduled it.
public struct CallLinkPayload: Sendable, Hashable {
    public let scheduleID: UUID
    public let childName: String
    public let topic: String
    public let wantsVideo: Bool
    public let languageID: String
    public let fireAt: Date

    public init(
        scheduleID: UUID,
        childName: String,
        topic: String,
        wantsVideo: Bool,
        languageID: String,
        fireAt: Date
    ) {
        self.scheduleID = scheduleID
        self.childName = childName
        self.topic = topic
        self.wantsVideo = wantsVideo
        self.languageID = languageID
        self.fireAt = fireAt
    }
}

/// `santatalk://call?schedule=…&child=…&topic=…&video=1&lang=English&at=…`
///
/// One representation for both ways in: a notification tap builds this URL from
/// its `userInfo` and hands it to the same parser an external link goes through,
/// so there is a single path from "something wants a call" to "the call starts".
public enum CallLink {

    public static let scheme = "santatalk"
    public static let host = "call"

    private enum Key {
        static let schedule = "schedule"
        static let child = "child"
        static let topic = "topic"
        static let video = "video"
        static let language = "lang"
        static let firesAt = "at"
    }

    /// Built per call rather than cached. `ISO8601DateFormatter` is not
    /// `Sendable`, so a shared instance would be a data race waiting to happen —
    /// and links are parsed once when one arrives, never in a loop.
    private static func timestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    public static func url(for payload: CallLinkPayload) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: Key.schedule, value: payload.scheduleID.uuidString),
            URLQueryItem(name: Key.child, value: payload.childName),
            URLQueryItem(name: Key.topic, value: payload.topic),
            URLQueryItem(name: Key.video, value: payload.wantsVideo ? "1" : "0"),
            URLQueryItem(name: Key.language, value: payload.languageID),
            URLQueryItem(name: Key.firesAt, value: timestampFormatter().string(from: payload.fireAt))
        ]
        return components.url
    }

    /// Nil for anything that is not one of our call links, or that is missing the
    /// two fields a call cannot be started without.
    public static func payload(from url: URL) -> CallLinkPayload? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard let rawID = value(Key.schedule), let scheduleID = UUID(uuidString: rawID),
              let rawDate = value(Key.firesAt), let fireAt = timestampFormatter().date(from: rawDate)
        else { return nil }

        return CallLinkPayload(
            scheduleID: scheduleID,
            childName: value(Key.child) ?? "",
            topic: value(Key.topic) ?? "",
            wantsVideo: value(Key.video) == "1",
            languageID: value(Key.language) ?? "",
            fireAt: fireAt
        )
    }

    // MARK: Notification payloads

    /// The `userInfo` a local notification carries. A single string, so there is
    /// nothing to keep in step between the request and the parser.
    public static func userInfo(for payload: CallLinkPayload) -> [String: String] {
        guard let url = url(for: payload) else { return [:] }
        return ["url": url.absoluteString]
    }

    public static func payload(fromUserInfo userInfo: [AnyHashable: Any]) -> CallLinkPayload? {
        guard let raw = userInfo["url"] as? String, let url = URL(string: raw) else { return nil }
        return payload(from: url)
    }
}
