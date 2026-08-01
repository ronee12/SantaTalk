import Foundation
import Testing
@testable import SantaScheduling

@Suite("CallLink")
struct CallLinkTests {

    private var payload: CallLinkPayload {
        CallLinkPayload(
            scheduleID: UUID(uuidString: "8B2A6E1C-4F3D-4A9B-9C11-0D5E7F2A1B34")!,
            childName: "Maya",
            topic: "The Christmas wish list",
            wantsVideo: true,
            languageID: "English",
            fireAt: TestClock.date(hour: 18, minute: 30)
        )
    }

    @Test("a payload survives the round trip through a URL")
    func roundTrip() throws {
        let url = try #require(CallLink.url(for: payload))
        let decoded = try #require(CallLink.payload(from: url))

        #expect(decoded == payload)
    }

    @Test("the link is a santatalk call URL")
    func shape() throws {
        let url = try #require(CallLink.url(for: payload))

        #expect(url.scheme == "santatalk")
        #expect(url.host == "call")
        #expect(url.absoluteString.contains("schedule=8B2A6E1C-4F3D-4A9B-9C11-0D5E7F2A1B34"))
    }

    /// Topics are free text — a parent can type anything into the topic sheet,
    /// and it has to come back out of the link unchanged.
    @Test("names and topics with spaces and symbols survive")
    func escaping() throws {
        let awkward = CallLinkPayload(
            scheduleID: UUID(),
            childName: "Zoë & Théo",
            topic: "Being kind — 100% of the time?",
            wantsVideo: false,
            languageID: "French",
            fireAt: TestClock.date(hour: 7)
        )

        let url = try #require(CallLink.url(for: awkward))
        let decoded = try #require(CallLink.payload(from: url))

        #expect(decoded == awkward)
    }

    @Test("a foreign URL is not a call link")
    func rejectsOtherSchemes() throws {
        let url = try #require(URL(string: "https://example.com/call?schedule=\(UUID().uuidString)"))

        #expect(CallLink.payload(from: url) == nil)
    }

    @Test("a call link without an id or a time is refused")
    func rejectsIncomplete() throws {
        let noID = try #require(URL(string: "santatalk://call?child=Maya&at=2026-08-01T18:30:00Z"))
        let noDate = try #require(URL(string: "santatalk://call?schedule=\(UUID().uuidString)"))
        let badID = try #require(URL(string: "santatalk://call?schedule=not-a-uuid&at=2026-08-01T18:30:00Z"))

        #expect(CallLink.payload(from: noID) == nil)
        #expect(CallLink.payload(from: noDate) == nil)
        #expect(CallLink.payload(from: badID) == nil)
    }

    @Test("a notification's userInfo decodes to the same payload")
    func userInfoRoundTrip() throws {
        let userInfo = CallLink.userInfo(for: payload)
        let decoded = try #require(CallLink.payload(fromUserInfo: userInfo))

        #expect(decoded == payload)
    }

    @Test("userInfo without our key is ignored")
    func rejectsForeignUserInfo() {
        #expect(CallLink.payload(fromUserInfo: ["aps": ["alert": "hello"]]) == nil)
    }

    @Test("video is carried both ways")
    func videoFlag() throws {
        let audio = CallLinkPayload(
            scheduleID: UUID(), childName: "Ben", topic: "",
            wantsVideo: false, languageID: "English",
            fireAt: TestClock.date(hour: 18)
        )

        let url = try #require(CallLink.url(for: audio))
        let decoded = try #require(CallLink.payload(from: url))

        #expect(decoded.wantsVideo == false)
    }
}
