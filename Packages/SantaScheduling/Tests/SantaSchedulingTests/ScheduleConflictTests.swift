import Foundation
import Testing
@testable import SantaScheduling

@Suite("ScheduleConflict")
struct ScheduleConflictTests {

    private func slot(_ name: String, hour: Int, minute: Int = 0) -> ScheduleSlot {
        ScheduleSlot(id: UUID(), childName: name, fireAt: TestClock.date(hour: hour, minute: minute))
    }

    @Test("nothing booked means nothing to clash with")
    func emptyIsClear() {
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 30),
            among: []
        )

        #expect(conflict == nil)
    }

    @Test("a call inside the window clashes")
    func insideWindow() {
        let ben = slot("Ben", hour: 18, minute: 30)
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 40),
            among: [ben]
        )

        #expect(conflict?.id == ben.id)
    }

    @Test("a call outside the window does not")
    func outsideWindow() {
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 19, minute: 0),
            among: [slot("Ben", hour: 18, minute: 30)]
        )

        #expect(conflict == nil)
    }

    /// The boundary is exclusive: exactly fifteen minutes apart is allowed, so
    /// the copy — "fifteen minutes either side" — stays literally true.
    @Test("exactly the window apart is allowed")
    func onTheBoundary() {
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 45),
            among: [slot("Ben", hour: 18, minute: 30)]
        )

        #expect(conflict == nil)
    }

    @Test("clashes are found before the new time as well as after")
    func earlierClashes() {
        let ben = slot("Ben", hour: 18, minute: 30)
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 20),
            among: [ben]
        )

        #expect(conflict?.id == ben.id)
    }

    @Test("the nearest clashing call is the one named")
    func nearestWins() {
        let far = slot("Ben", hour: 18, minute: 20)
        let near = slot("Maya", hour: 18, minute: 33)

        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 30),
            among: [far, near]
        )

        #expect(conflict?.childName == "Maya")
    }

    /// Rebooking Ben's 6:30 for 6:35 must not report Ben's own call as the thing
    /// standing in the way.
    @Test("the call being edited does not clash with itself")
    func excludesItself() {
        let ben = slot("Ben", hour: 18, minute: 30)
        let conflict = ScheduleConflict.first(
            against: TestClock.date(hour: 18, minute: 35),
            among: [ben],
            excluding: ben.id
        )

        #expect(conflict == nil)
    }
}
