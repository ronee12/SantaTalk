import FirebaseAI
import Foundation
import SantaCallSummary

/// Asks Gemini what happened in a call.
///
/// The audio goes straight from the device to Google through Firebase AI Logic —
/// santa_backend is not on this path and never sees a recording. App Check is
/// what stands in front of the endpoint; see `AppDelegate.configureFirebase()`.
///
/// `nonisolated`: an upload has no business on the main actor. The project
/// builds with `MainActor` default isolation, so this has to be said out loud.
nonisolated struct CallSummaryService {

    /// Handles audio natively, and is the cheapest model that does.
    static let modelName = "gemini-2.5-flash"

    /// The `.m4a` that `CallAudioExtractor` produces. On Firebase's supported
    /// list for audio input.
    static let mimeType = "audio/mp4"

    /// What the model must fill in. All three are required rather than optional:
    /// a model allowed to omit a list will omit the one it found hardest, and
    /// "no wishes" and "did not look for wishes" would then be the same answer.
    static var responseSchema: Schema {
        .object(
            properties: [
                "wishes": .array(
                    items: .string(),
                    description: "Presents or things the child asked for, in the child's own words."
                ),
                "promises": .array(
                    items: .string(),
                    description: "Things the child said they would do. Never what Santa said."
                ),
                "notable": .array(
                    items: .string(),
                    description: "Anything else the parent would be glad to know."
                )
            ]
        )
    }

    /// `language` is a `Language.english` — the parent's chosen language, which
    /// is what the answer is written in even when the call was in another.
    func summarise(audio: Data, childName: String, language: String) async throws -> CallSummary {
        let model = FirebaseAI
            // Vertex AI, under the name it goes by now. The location is pinned
            // rather than left to default so an SDK bump cannot quietly move
            // which region a child's voice is processed in.
            .firebaseAI(backend: .agentPlatform(location: "global"))
            .generativeModel(
                modelName: Self.modelName,
                generationConfig: GenerationConfig(
                    // Extraction, not invention. The near-zero temperature is the
                    // difference between reporting a wish and improving on it.
                    temperature: 0.1,
                    responseMIMEType: "application/json",
                    responseSchema: Self.responseSchema
                ),
                systemInstruction: ModelContent(
                    parts: SummaryPrompt.system(childName: childName, language: language)
                )
            )

        let response = try await model.generateContent(
            InlineDataPart(data: audio, mimeType: Self.mimeType),
            SummaryPrompt.instruction
        )

        // A response with no text is a refusal, a safety block, or an empty
        // candidate list. None of those are a summary, and none are worth
        // telling a parent apart.
        guard let text = response.text else { throw CallSummaryError.unreadableAnswer }

        return try CallSummaryDecoder.decode(text, generatedAt: Date())
    }
}
