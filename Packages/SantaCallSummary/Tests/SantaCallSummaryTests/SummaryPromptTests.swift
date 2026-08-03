import Foundation
import Testing
@testable import SantaCallSummary

@Suite("SummaryPrompt")
struct SummaryPromptTests {

    @Test("the child's name is used, so the model knows which voice to report on")
    func namesTheChild() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "English")

        #expect(prompt.contains("Maya"))
    }

    @Test("an unnamed child does not leave a hole in the sentence")
    func unnamedChildReadsSensibly() {
        let prompt = SummaryPrompt.system(childName: "", language: "English")

        #expect(prompt.contains("the child"))
        #expect(!prompt.contains("  ,"))
        #expect(!prompt.contains(" ,"))
    }

    @Test("a name of nothing but whitespace is treated as no name")
    func whitespaceNameIsNoName() {
        let prompt = SummaryPrompt.system(childName: "   ", language: "English")

        #expect(prompt.contains("the child"))
    }

    @Test("the parent's language is what the answer is written in")
    func statesTheOutputLanguage() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "Spanish")

        #expect(prompt.contains("Spanish"))
    }

    @Test("a missing language falls back to English rather than an empty instruction")
    func missingLanguageFallsBack() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "")

        #expect(prompt.contains("English"))
    }

    @Test("the prompt tells the model to keep Santa's lines out of the child's lists")
    func guardsAgainstAttributingSantaToTheChild() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "English")

        // The single biggest failure mode: both voices are on one track, and a
        // present Santa offered is not a present the child asked for.
        #expect(prompt.contains("Santa's lines are context, never content."))
        #expect(prompt.contains("If Santa offers a present, that is not a wish."))
    }

    @Test("the prompt forbids padding an empty list")
    func forbidsInvention() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "English")

        #expect(prompt.contains("Never invent."))
        #expect(prompt.contains("empty list"))
    }

    @Test("all three list names appear, spelled as the schema spells them")
    func namesEveryList() {
        let prompt = SummaryPrompt.system(childName: "Maya", language: "English")

        #expect(prompt.contains("wishes"))
        #expect(prompt.contains("promises"))
        #expect(prompt.contains("notable"))
    }

    @Test("the instruction sent with the audio is not empty")
    func instructionIsPresent() {
        #expect(!SummaryPrompt.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
