import Foundation

/// Turns whatever the model actually sent into a `CallSummary`.
///
/// The request pins `responseMIMEType` to JSON and hands over a schema, so in
/// the good case this is `JSONSerialization` and nothing more. The leniency
/// below is for the other case: a model that wraps its JSON in a code fence,
/// omits a key it had nothing to put in, or slips a bullet character into a
/// list it was told to return as plain strings. None of those are worth showing
/// a parent an error over when the useful part of the answer arrived intact.
///
/// What it will *not* do is invent structure. A response that is not a JSON
/// object throws, because at that point we no longer know what we are reading.
public enum CallSummaryDecoder {

    public enum Failure: Error, Equatable {
        /// The text could not be parsed as JSON at all.
        case notJSON
        /// It parsed, but the top level was an array, a number, a string —
        /// anything but the object the schema asked for.
        case notAnObject
    }

    public static func decode(_ text: String, generatedAt: Date) throws -> CallSummary {
        let cleaned = stripCodeFence(from: text)

        guard let data = cleaned.data(using: .utf8), !cleaned.isEmpty else {
            throw Failure.notJSON
        }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw Failure.notJSON
        }

        guard let object = parsed as? [String: Any] else {
            throw Failure.notAnObject
        }

        return CallSummary(
            wishes: list(object["wishes"]),
            promises: list(object["promises"]),
            notable: list(object["notable"]),
            generatedAt: generatedAt
        )
    }

    // MARK: - Reading one list

    /// A missing key and a key holding the wrong type mean the same thing here:
    /// nothing to show under that heading. Throwing instead would discard the
    /// two lists that did arrive.
    private static func list(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }

        var seen = Set<String>()
        var result: [String] = []

        for element in array {
            // Non-strings are dropped rather than described. `String(describing:)`
            // on a dictionary would put `["item": "bike"]` in front of a parent.
            guard let raw = element as? String else { continue }

            let entry = tidy(raw)
            guard !entry.isEmpty else { continue }

            // Models repeat themselves, and the same wish twice reads like the
            // child asked twice.
            let key = entry.lowercased()
            guard seen.insert(key).inserted else { continue }

            result.append(entry)
        }

        return result
    }

    /// Trims, and takes off any list marker the model added despite being asked
    /// for plain strings — the view draws its own bullets.
    private static func tidy(_ raw: String) -> String {
        var entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        for marker in ["- ", "* ", "• ", "– ", "— "] where entry.hasPrefix(marker) {
            entry.removeFirst(marker.count)
            entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return entry
    }

    // MARK: - Code fences

    /// ```json ... ``` around an otherwise fine object. Structured output makes
    /// this unlikely rather than impossible.
    private static func stripCodeFence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: .newlines)
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
