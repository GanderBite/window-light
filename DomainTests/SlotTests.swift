import Testing
@testable import Domain

struct SlotTests {
    @Test func slotsFollowTheDayFromDawnToNight() {
        #expect(Slot.allCases == [.dawn, .sunrise, .morning, .midday, .afternoon, .sunset, .dusk, .night])
    }

    @Test func dawnComesBeforeNight() {
        #expect(Slot.dawn < Slot.night)
    }
}
