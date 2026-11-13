public struct CaptureTime: Hashable, Sendable {
    private static let validYears = 1 ... 9999
    private static let validMonths = 1 ... 12
    private static let validHours = 0 ... 23
    private static let validMinutesAndSeconds = 0 ... 59
    private static let daysInMonths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600
    private static let secondsPerDay = 86400
    private static let february = 2
    private static let daysInLeapFebruary = 29

    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
    ) throws(CaptureTimeError) {
        guard Self.dateExists(year: year, month: month, day: day) else {
            throw .notADate(year: year, month: month, day: day)
        }
        guard Self.validHours.contains(hour),
              Self.validMinutesAndSeconds.contains(minute),
              Self.validMinutesAndSeconds.contains(second)
        else {
            throw .notAClockTime(hour: hour, minute: minute, second: second)
        }

        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    public func captureTimeOfFrame(secondsIntoTheRecording seconds: Int) throws(CaptureTimeError) -> Self {
        guard seconds >= 0 else {
            throw .frameBeforeTheRecordingStarted(secondsIntoTheRecording: seconds)
        }

        let (fullDays, secondsWithinDay) = seconds.quotientAndRemainder(dividingBy: Self.secondsPerDay)
        let clockSeconds = secondOfDay + secondsWithinDay
        var daysToAdvance = fullDays + clockSeconds / Self.secondsPerDay
        var reachedYear = year
        var reachedMonth = month
        var reachedDay = day

        while daysToAdvance > 0 {
            let daysLeftInMonth = Self.daysIn(month: reachedMonth, ofYear: reachedYear) - reachedDay
            if daysToAdvance <= daysLeftInMonth {
                reachedDay += daysToAdvance
                daysToAdvance = 0
            } else {
                daysToAdvance -= daysLeftInMonth + 1
                reachedDay = 1
                reachedMonth += 1
                if reachedMonth > Self.validMonths.upperBound {
                    reachedMonth = Self.validMonths.lowerBound
                    reachedYear += 1
                }
                guard Self.validYears.contains(reachedYear) else {
                    throw .notADate(year: reachedYear, month: reachedMonth, day: reachedDay)
                }
            }
        }

        let reachedSecondOfDay = clockSeconds % Self.secondsPerDay
        return try Self(
            year: reachedYear,
            month: reachedMonth,
            day: reachedDay,
            hour: reachedSecondOfDay / Self.secondsPerHour,
            minute: reachedSecondOfDay % Self.secondsPerHour / Self.secondsPerMinute,
            second: reachedSecondOfDay % Self.secondsPerMinute,
        )
    }

    private var secondOfDay: Int {
        hour * Self.secondsPerHour + minute * Self.secondsPerMinute + second
    }

    private static func dateExists(year: Int, month: Int, day: Int) -> Bool {
        guard validYears.contains(year), validMonths.contains(month) else { return false }

        return (1 ... daysIn(month: month, ofYear: year)).contains(day)
    }

    private static func daysIn(month: Int, ofYear year: Int) -> Int {
        if month == february, isLeap(year) {
            return daysInLeapFebruary
        }
        return daysInMonths[month - 1]
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year.isMultiple(of: 4) && !year.isMultiple(of: 100)) || year.isMultiple(of: 400)
    }
}
