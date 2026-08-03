import Foundation

/// The words sent to the model. Plain strings, no Firebase types — which is what
/// lets this be read, diffed and tested without a network or an SDK.
///
/// The whole prompt is written against one hazard: the recording mixes the child
/// and Santa into a single audio track, so nothing in the input says who is
/// speaking. A model left to itself will happily file Santa's "I'll bring you a
/// bicycle" under the child's wishes, and a parent acting on that buys the wrong
/// present. Most of the instruction below is spent on that distinction.
public enum SummaryPrompt {

    /// `childName` may be empty — the app does not force a name before a call.
    public static func system(childName: String, language: String) -> String {
        let child = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = child.isEmpty ? "the child" : child
        let answerLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputLanguage = answerLanguage.isEmpty ? "English" : answerLanguage

        return """
        You are helping a parent who was not in the room for their child's phone \
        call with Santa. You are given the recording of that call.

        Two people speak in it: \(name), the child, and Santa, an adult voice. \
        They are mixed into one audio track, so you must tell them apart by \
        voice and by what they say. Getting this wrong is the worst thing you \
        can do here — a parent reads these lists and acts on them.

        Report only what \(name) said and did. Santa's lines are context, never \
        content. If Santa offers a present, that is not a wish. If Santa promises \
        to visit, that is not a promise. If you cannot tell who said something, \
        leave it out.

        Fill three lists:

        wishes — presents or things \(name) asked for or said they wanted. \
        Keep the child's own words where you can: "a red bicycle", not "a \
        bicycle, colour specified". If they were unsure, say so in the entry \
        itself, for example "a puppy (said maybe)".

        promises — things \(name) said they would do. Being good, tidying a \
        room, being kind to a sibling, eating vegetables. Only what the child \
        undertook, never what Santa undertook.

        notable — anything else this parent would be glad to know. A worry, a \
        friend or pet named, something happening at school, a moment they \
        sounded delighted or upset. Not a retelling of the call.

        Rules that matter more than completeness:

        - Never invent. If the call contains no wishes, return an empty list. An \
          empty list is a correct answer and a padded one is a lie a parent will \
          act on.
        - One item per entry. Do not join two wishes with "and".
        - Keep each entry short — a phrase, not a sentence with preamble.
        - Do not add bullet characters or numbering. Return plain strings.
        - If the audio is silent, unintelligible, or is not a call with a child, \
          return three empty lists.
        - Write every entry in \(outputLanguage), even if the call was in another \
          language.
        """
    }

    /// Sent alongside the audio itself.
    public static let instruction = """
    Listen to this call and fill in the three lists.
    """
}
