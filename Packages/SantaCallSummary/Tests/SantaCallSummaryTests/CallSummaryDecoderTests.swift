import Foundation
import Testing
@testable import SantaCallSummary

@Suite("CallSummaryDecoder")
struct CallSummaryDecoderTests {

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private func decode(_ text: String) throws -> CallSummary {
        try CallSummaryDecoder.decode(text, generatedAt: now)
    }

    // MARK: The good case

    @Test("reads the three lists the schema asks for")
    func readsAllThreeLists() throws {
        let summary = try decode("""
        {
          "wishes": ["A red bicycle", "Lego space set"],
          "promises": ["Tidy her room"],
          "notable": ["Nervous about the school play on Friday"]
        }
        """)

        #expect(summary.wishes == ["A red bicycle", "Lego space set"])
        #expect(summary.promises == ["Tidy her room"])
        #expect(summary.notable == ["Nervous about the school play on Friday"])
        #expect(summary.generatedAt == now)
        #expect(!summary.isEmpty)
    }

    @Test("three empty lists is a valid answer, not a failure")
    func emptyIsAnAnswer() throws {
        let summary = try decode(#"{"wishes": [], "promises": [], "notable": []}"#)

        #expect(summary.isEmpty)
    }

    // MARK: Keys that are missing or wrong

    @Test("a missing key means nothing under that heading, not a thrown error")
    func missingKeyIsEmpty() throws {
        let summary = try decode(#"{"wishes": ["A kite"]}"#)

        #expect(summary.wishes == ["A kite"])
        #expect(summary.promises.isEmpty)
        #expect(summary.notable.isEmpty)
    }

    @Test("a key holding the wrong type does not discard the lists that arrived")
    func wrongTypeKeepsTheRest() throws {
        let summary = try decode("""
        {"wishes": "a red bicycle", "promises": ["Be kind"], "notable": null}
        """)

        #expect(summary.wishes.isEmpty)
        #expect(summary.promises == ["Be kind"])
        #expect(summary.notable.isEmpty)
    }

    @Test("keys the schema never asked for are ignored")
    func extraKeysIgnored() throws {
        let summary = try decode("""
        {"wishes": ["A kite"], "mood": "happy", "confidence": 0.8}
        """)

        #expect(summary.wishes == ["A kite"])
    }

    // MARK: Entries inside a list

    @Test("non-string entries are dropped rather than described")
    func nonStringEntriesDropped() throws {
        let summary = try decode("""
        {"wishes": ["A kite", {"item": "bike"}, 42, null, "A drum"]}
        """)

        #expect(summary.wishes == ["A kite", "A drum"])
    }

    @Test("blank and whitespace-only entries are dropped")
    func blankEntriesDropped() throws {
        let summary = try decode(#"{"promises": ["", "   ", "\n", "Tidy up"]}"#)

        #expect(summary.promises == ["Tidy up"])
    }

    @Test("entries are trimmed")
    func entriesTrimmed() throws {
        let summary = try decode(#"{"wishes": ["  A red bicycle  "]}"#)

        #expect(summary.wishes == ["A red bicycle"])
    }

    @Test("a list marker the model added is taken off — the view draws its own")
    func listMarkersStripped() throws {
        let summary = try decode("""
        {"wishes": ["- A red bicycle", "* Lego", "• A drum", "– A kite", "— A ball"]}
        """)

        #expect(summary.wishes == ["A red bicycle", "Lego", "A drum", "A kite", "A ball"])
    }

    @Test("a hyphen inside an entry survives — only a leading marker goes")
    func innerHyphenSurvives() throws {
        let summary = try decode(#"{"wishes": ["A walkie-talkie set"]}"#)

        #expect(summary.wishes == ["A walkie-talkie set"])
    }

    @Test("the same wish twice reads like the child asked twice, so it is deduped")
    func duplicatesRemoved() throws {
        let summary = try decode("""
        {"wishes": ["A red bicycle", "a red bicycle", "  A RED BICYCLE  ", "Lego"]}
        """)

        #expect(summary.wishes == ["A red bicycle", "Lego"])
    }

    @Test("order is kept as the model gave it")
    func orderPreserved() throws {
        let summary = try decode(#"{"notable": ["Third", "First", "Second"]}"#)

        #expect(summary.notable == ["Third", "First", "Second"])
    }

    // MARK: Wrapping and malformed input

    @Test("json wrapped in a code fence is unwrapped")
    func codeFenceStripped() throws {
        let summary = try decode("""
        ```json
        {"wishes": ["A kite"]}
        ```
        """)

        #expect(summary.wishes == ["A kite"])
    }

    @Test("a bare code fence with no language is unwrapped too")
    func bareCodeFenceStripped() throws {
        let summary = try decode("```\n{\"promises\": [\"Be good\"]}\n```")

        #expect(summary.promises == ["Be good"])
    }

    @Test("text that is not json throws")
    func notJSONThrows() {
        #expect(throws: CallSummaryDecoder.Failure.notJSON) {
            try decode("Santa and the child had a lovely chat.")
        }
    }

    @Test("empty text throws")
    func emptyTextThrows() {
        #expect(throws: CallSummaryDecoder.Failure.notJSON) {
            try decode("   \n  ")
        }
    }

    @Test("valid json that is not an object throws — we no longer know what we are reading")
    func topLevelArrayThrows() {
        #expect(throws: CallSummaryDecoder.Failure.notAnObject) {
            try decode(#"["A red bicycle", "Lego"]"#)
        }
    }

    @Test("a bare json string throws rather than being read as an entry")
    func topLevelStringThrows() {
        #expect(throws: CallSummaryDecoder.Failure.notAnObject) {
            try decode(#""a red bicycle""#)
        }
    }

    // MARK: Round trip

    @Test("a summary survives the round trip through Codable")
    func codableRoundTrip() throws {
        let original = CallSummary(
            wishes: ["A red bicycle"],
            promises: ["Tidy her room"],
            notable: ["Named her cat Mittens"],
            generatedAt: now
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CallSummary.self, from: data)

        #expect(restored == original)
    }

    @Test("a summary with nothing in it reports itself empty")
    func emptySummaryIsEmpty() {
        #expect(CallSummary(generatedAt: now).isEmpty)
    }

    @Test("one entry anywhere is enough to not be empty")
    func oneEntryIsNotEmpty() {
        #expect(!CallSummary(notable: ["Sounded delighted"], generatedAt: now).isEmpty)
    }
}
