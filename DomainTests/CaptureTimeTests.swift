@testable import Domain
import Testing

private func captureTime(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    _ second: Int = 0,
) throws -> CaptureTime {
    try CaptureTime(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
}

struct CaptureTimeTests {
    @Test func aCaptureTimeGivesBackItsSixParts() throws {
        let time = try captureTime(2026, 6, 21, 17, 45, 3)
        #expect(time.year == 2026)
        #expect(time.month == 6)
        #expect(time.day == 21)
        #expect(time.hour == 17)
        #expect(time.minute == 45)
        #expect(time.second == 3)
    }

    @Test(arguments: [(2024, 2, 29), (2000, 2, 29), (2023, 12, 31), (9999, 12, 31), (1, 1, 1)])
    func existingDatesAreAccepted(year: Int, month: Int, day: Int) throws {
        #expect(try captureTime(year, month, day).day == day)
    }

    @Test(arguments: [
        (2023, 2, 29), (1900, 2, 29), (2026, 4, 31), (2026, 0, 10), (2026, 13, 10),
        (2026, 6, 0), (0, 6, 10), (10000, 6, 10),
    ])
    func datesThatDoNotExistAreRefused(year: Int, month: Int, day: Int) {
        #expect(throws: CaptureTimeError.notADate(year: year, month: month, day: day)) {
            try captureTime(year, month, day)
        }
    }

    @Test(arguments: [(24, 0, 0), (0, 60, 0), (0, 0, 60), (-1, 0, 0)])
    func clockTimesThatDoNotExistAreRefused(hour: Int, minute: Int, second: Int) {
        #expect(throws: CaptureTimeError.notAClockTime(hour: hour, minute: minute, second: second)) {
            try captureTime(2026, 6, 21, hour, minute, second)
        }
    }

    @Test func theEdgesOfTheDayAreAccepted() throws {
        #expect(try captureTime(2026, 6, 21, 0, 0, 0).hour == 0)
        #expect(try captureTime(2026, 6, 21, 23, 59, 59).second == 59)
    }

    @Test func aWrongDateIsReportedBeforeAWrongClockTime() {
        #expect(throws: CaptureTimeError.notADate(year: 2023, month: 2, day: 29)) {
            try captureTime(2023, 2, 29, 24, 0, 0)
        }
    }

    @Test func captureTimesWithTheSameSixPartsAreEqual() throws {
        let first = try captureTime(2026, 6, 21, 17, 45, 3)
        let second = try captureTime(2026, 6, 21, 17, 45, 3)
        #expect(first == second)
    }

    @Test func captureTimesDifferingInOnePartAreNotEqual() throws {
        let base = try captureTime(2026, 6, 21, 17, 45, 3)
        #expect(try base != captureTime(2027, 6, 21, 17, 45, 3))
        #expect(try base != captureTime(2026, 7, 21, 17, 45, 3))
        #expect(try base != captureTime(2026, 6, 22, 17, 45, 3))
        #expect(try base != captureTime(2026, 6, 21, 18, 45, 3))
        #expect(try base != captureTime(2026, 6, 21, 17, 46, 3))
        #expect(try base != captureTime(2026, 6, 21, 17, 45, 4))
    }

    @Test func aFrameTenMinutesIntoARecordingIsTenMinutesLater() throws {
        let start = try captureTime(2026, 6, 21, 18, 0, 0)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 600) == captureTime(2026, 6, 21, 18, 10, 0))
    }

    @Test func aFrameAtTheStartOfTheRecordingHasTheCaptureTimeOfTheStart() throws {
        let start = try captureTime(2026, 6, 21, 18, 0, 0)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 0) == start)
    }

    @Test func aFrameCrossingMidnightLandsOnTheNextDay() throws {
        let start = try captureTime(2026, 6, 21, 23, 59, 30)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 45) == captureTime(2026, 6, 22, 0, 0, 15))
    }

    @Test func aFrameCrossingTheEndOfAMonthLandsInTheNextMonth() throws {
        let start = try captureTime(2026, 4, 30, 23, 59, 59)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 1) == captureTime(2026, 5, 1, 0, 0, 0))
    }

    @Test func aFrameCrossingTheEndOfAYearLandsInTheNextYear() throws {
        let start = try captureTime(2026, 12, 31, 23, 59, 59)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 1) == captureTime(2027, 1, 1, 0, 0, 0))
    }

    @Test func aFrameCrossingTwentyEighthFebruaryOfALeapYearLandsOnTwentyNinth() throws {
        let start = try captureTime(2024, 2, 28, 23, 59, 59)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 1) == captureTime(2024, 2, 29, 0, 0, 0))
    }

    @Test func aFrameCrossingTwentyEighthFebruaryOfAnotherYearLandsOnFirstMarch() throws {
        let start = try captureTime(2026, 2, 28, 23, 59, 59)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 1) == captureTime(2026, 3, 1, 0, 0, 0))
    }

    @Test func aFrameMoreThanADayIntoARecordingLandsOnTheRightDateAndClockTime() throws {
        let start = try captureTime(2026, 6, 21, 18, 0, 0)
        #expect(try start.captureTimeOfFrame(secondsIntoTheRecording: 90000) == captureTime(2026, 6, 22, 19, 0, 0))
    }

    @Test func aFrameManyYearsIntoARecordingLandsOnTheRightDate() throws {
        let start = try captureTime(2026, 1, 1, 0, 0, 0)
        let secondsInFourYearsWithOneLeapDay = (365 * 4 + 1) * 86400
        #expect(
            try start.captureTimeOfFrame(secondsIntoTheRecording: secondsInFourYearsWithOneLeapDay)
                == captureTime(2030, 1, 1, 0, 0, 0),
        )
    }

    @Test(arguments: [-1, -600, Int.min])
    func aFrameBeforeTheRecordingStartedIsRefused(seconds: Int) throws {
        let start = try captureTime(2026, 6, 21, 18, 0, 0)
        #expect(throws: CaptureTimeError.frameBeforeTheRecordingStarted(secondsIntoTheRecording: seconds)) {
            try start.captureTimeOfFrame(secondsIntoTheRecording: seconds)
        }
    }

    @Test func aFrameAfterTheYearNineThousandNineHundredNinetyNineIsRefused() throws {
        let start = try captureTime(9999, 12, 31, 23, 59, 59)
        #expect(throws: CaptureTimeError.notADate(year: 10000, month: 1, day: 1)) {
            try start.captureTimeOfFrame(secondsIntoTheRecording: 1)
        }
    }

    @Test func aFrameAnImmenseNumberOfSecondsIntoARecordingIsRefusedWithoutOverflowing() throws {
        let start = try captureTime(2026, 6, 21, 18, 0, 0)
        #expect(throws: CaptureTimeError.self) {
            try start.captureTimeOfFrame(secondsIntoTheRecording: Int.max)
        }
    }
}
