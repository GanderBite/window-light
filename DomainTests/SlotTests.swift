@testable import Domain
import Testing

struct SlotTests {
    struct Clock: CustomTestStringConvertible {
        let hour: Int
        let minute: Int
        let second: Int

        init(_ hour: Int, _ minute: Int, _ second: Int = 0) {
            self.hour = hour
            self.minute = minute
            self.second = second
        }

        var testDescription: String {
            "\(hour):\(minute):\(second)"
        }

        func captureTime(day: Int = 15) throws -> CaptureTime {
            try CaptureTime(year: 2026, month: 6, day: day, hour: hour, minute: minute, second: second)
        }
    }

    struct Boundary: CustomTestStringConvertible {
        let clock: Clock
        let before: Slot
        let after: Slot

        var testDescription: String {
            clock.testDescription
        }
    }

    static let boundaries = [
        Boundary(clock: Clock(5, 0), before: .night, after: .dawn),
        Boundary(clock: Clock(6, 0), before: .dawn, after: .sunrise),
        Boundary(clock: Clock(7, 30), before: .sunrise, after: .morning),
        Boundary(clock: Clock(10, 30), before: .morning, after: .midday),
        Boundary(clock: Clock(14, 30), before: .midday, after: .afternoon),
        Boundary(clock: Clock(17, 0), before: .afternoon, after: .sunset),
        Boundary(clock: Clock(18, 30), before: .sunset, after: .dusk),
        Boundary(clock: Clock(20, 0), before: .dusk, after: .night),
    ]

    static let middles: [(Slot, Clock)] = [
        (.dawn, Clock(5, 30)),
        (.sunrise, Clock(6, 45)),
        (.morning, Clock(9, 0)),
        (.midday, Clock(12, 30)),
        (.afternoon, Clock(15, 45)),
        (.sunset, Clock(17, 45)),
        (.dusk, Clock(19, 15)),
        (.night, Clock(0, 30)),
    ]

    static let mirrors: [(Slot, Slot?)] = [
        (.dawn, .dusk),
        (.sunrise, .sunset),
        (.morning, .afternoon),
        (.afternoon, .morning),
        (.sunset, .sunrise),
        (.dusk, .dawn),
        (.midday, nil),
        (.night, nil),
    ]

    @Test func slotsFollowTheDayFromDawnToNight() {
        #expect(Slot.allCases == [.dawn, .sunrise, .morning, .midday, .afternoon, .sunset, .dusk, .night])
    }

    @Test func dawnComesBeforeNight() {
        #expect(Slot.dawn < Slot.night)
    }

    @Test(arguments: boundaries)
    func aTimeOnABoundaryBelongsToTheSlotThatStartsThere(boundary: Boundary) throws {
        let captureTime = try boundary.clock.captureTime()

        #expect(Slot.matching(captureTime) == boundary.after)
    }

    @Test(arguments: boundaries)
    func aTimeOneSecondBeforeABoundaryBelongsToTheSlotBefore(boundary: Boundary) throws {
        let clock = boundary.clock
        let oneSecondEarlier = Clock(
            clock.minute == 0 ? (clock.hour + 23) % 24 : clock.hour,
            clock.minute == 0 ? 59 : clock.minute - 1,
            59,
        )

        #expect(try Slot.matching(oneSecondEarlier.captureTime()) == boundary.before)
    }

    @Test(arguments: [(Clock(6, 59), Slot.sunrise), (Clock(7, 30), Slot.morning)])
    func sunriseEndsAtHalfPastSeven(clock: Clock, slot: Slot) throws {
        #expect(try Slot.matching(clock.captureTime()) == slot)
    }

    @Test(arguments: [Clock(23, 59, 59), Clock(0, 0), Clock(0, 30), Clock(4, 59, 59)])
    func nightRunsOverMidnight(clock: Clock) throws {
        #expect(try Slot.matching(clock.captureTime()) == .night)
    }

    @Test func theDateDoesNotChangeTheAnswers() throws {
        let clock = Clock(12, 25)
        let first = try clock.captureTime(day: 1)
        let second = try clock.captureTime(day: 20)

        #expect(Slot.matching(first) == Slot.matching(second))
        #expect(Slot.secondsIntoTheDay(of: first) == Slot.secondsIntoTheDay(of: second))
        #expect(Slot.midday.secondsBetweenTheMiddle(and: first) == Slot.midday.secondsBetweenTheMiddle(and: second))
    }

    @Test(arguments: mirrors)
    func mirrorIsTheSlotWithSimilarLightOnTheOtherSideOfTheDay(slot: Slot, expected: Slot?) {
        #expect(slot.mirror == expected)
    }

    @Test(arguments: Slot.allCases)
    func aSlotIsZeroStepsFromItself(slot: Slot) {
        #expect(slot.steps(to: slot) == 0)
    }

    @Test func nightIsOneStepFromDawnAndFromDusk() {
        #expect(Slot.night.steps(to: .dawn) == 1)
        #expect(Slot.night.steps(to: .dusk) == 1)
    }

    @Test func theFarthestSlotsAreFourStepsApart() {
        #expect(Slot.midday.steps(to: .night) == 4)
        #expect(Slot.dawn.steps(to: .afternoon) == 4)
    }

    @Test(arguments: Slot.allCases, Slot.allCases)
    func stepsAreTheSameInBothDirectionsAndNeverMoreThanFour(first: Slot, second: Slot) {
        #expect(first.steps(to: second) == second.steps(to: first))
        #expect(first.steps(to: second) <= 4)
    }

    @Test func theDayOfTheSlotsStartsAtFive() throws {
        #expect(try Slot.secondsIntoTheDay(of: Clock(5, 0).captureTime()) == 0)
        #expect(try Slot.secondsIntoTheDay(of: Clock(4, 59, 59).captureTime()) == 86399)
        #expect(try Slot.secondsIntoTheDay(of: Clock(23, 30).captureTime()) == 66600)
        #expect(try Slot.secondsIntoTheDay(of: Clock(1, 30).captureTime()) == 73800)
    }

    @Test(arguments: middles)
    func distanceFromTheMiddleIsZeroAtTheMiddle(slot: Slot, middle: Clock) throws {
        #expect(try slot.secondsBetweenTheMiddle(and: middle.captureTime()) == 0)
    }

    @Test(arguments: [Clock(23, 30), Clock(1, 30)])
    func nightDistanceIsCountedAcrossMidnight(clock: Clock) throws {
        #expect(try Slot.night.secondsBetweenTheMiddle(and: clock.captureTime()) == 3600)
    }

    @Test func middayDistanceIsCountedInSeconds() throws {
        #expect(try Slot.midday.secondsBetweenTheMiddle(and: Clock(12, 25).captureTime()) == 300)
    }
}
