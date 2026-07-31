import Foundation
import SwiftData
import SwiftUI

/// One recorded call. The media itself is a file in Application Support; this
/// row holds only what the list needs to draw and what the player needs to find
/// it.
///
/// `filename` is a basename, never a path. The app's container directory moves
/// between installs and OS upgrades, so an absolute path written today can point
/// nowhere tomorrow.
@Model
final class CallRecording {
    var id: UUID
    var childName: String
    var title: String
    var startedAt: Date
    var durationSeconds: Int
    var hasVideo: Bool
    var filename: String
    /// Empty until call summaries ship.
    var summary: String

    init(
        id: UUID,
        childName: String,
        title: String,
        startedAt: Date,
        durationSeconds: Int,
        hasVideo: Bool,
        filename: String,
        summary: String = ""
    ) {
        self.id = id
        self.childName = childName
        self.title = title
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.hasVideo = hasVideo
        self.filename = filename
        self.summary = summary
    }
}

// MARK: - How a recording reads in the list

extension CallRecording {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var dateLabel: String { Self.dateFormatter.string(from: startedAt) }
    var timeLabel: String { Self.timeFormatter.string(from: startedAt) }

    var meta: String { "\(dateLabel)  ·  \(timeLabel)  ·  \(Format.duration(durationSeconds))" }

    /// State is never colour-only — the badge carries a word too.
    var badge: String { hasVideo ? "Reactions recorded" : "Audio only" }
    var badgeColor: Color { hasVideo ? Palette.pine : Palette.dim }
    var badgeBackground: Color {
        hasVideo ? Color(hex: 0x4FD3A0, opacity: 0.12) : Color(hex: 0xEDF2FF, opacity: 0.07)
    }

    /// Shown where a summary would be, until summaries ship.
    var summaryText: String {
        summary.isEmpty ? "Summaries are coming soon." : summary
    }
}
