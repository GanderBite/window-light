public enum Slot: CaseIterable, Comparable, Hashable, Sendable {
    case dawn, sunrise, morning, midday, afternoon, sunset, dusk, night

    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600
    private static let secondsPerDay = 86400
    private static let dayStartHour = 5

    public static func matching(_ captureTime: CaptureTime) -> Self {
        let seconds = secondsIntoTheDay(of: captureTime)
        return allCases.last { $0.range.lowerBound <= seconds } ?? .dawn
    }

    public var mirror: Self? {
        switch self {
        case .dawn: .dusk
        case .sunrise: .sunset
        case .morning: .afternoon
        case .afternoon: .morning
        case .sunset: .sunrise
        case .dusk: .dawn
        case .midday, .night: nil
        }
    }

    public func steps(to other: Self) -> Int {
        let direct = abs(position - other.position)
        return min(direct, Self.allCases.count - direct)
    }

    static func secondsIntoTheDay(of captureTime: CaptureTime) -> Int {
        secondsIntoTheDay(hour: captureTime.hour, minute: captureTime.minute, second: captureTime.second)
    }

    func secondsBetweenTheMiddle(and captureTime: CaptureTime) -> Int {
        let middle = (range.lowerBound + range.upperBound) / 2
        let direct = abs(middle - Self.secondsIntoTheDay(of: captureTime))
        return min(direct, Self.secondsPerDay - direct)
    }

    private var position: Int {
        switch self {
        case .dawn: 0
        case .sunrise: 1
        case .morning: 2
        case .midday: 3
        case .afternoon: 4
        case .sunset: 5
        case .dusk: 6
        case .night: 7
        }
    }

    private var range: Range<Int> {
        switch self {
        case .dawn: Self.range(from: (5, 0), to: (6, 0))
        case .sunrise: Self.range(from: (6, 0), to: (7, 30))
        case .morning: Self.range(from: (7, 30), to: (10, 30))
        case .midday: Self.range(from: (10, 30), to: (14, 30))
        case .afternoon: Self.range(from: (14, 30), to: (17, 0))
        case .sunset: Self.range(from: (17, 0), to: (18, 30))
        case .dusk: Self.range(from: (18, 30), to: (20, 0))
        case .night: Self.range(from: (20, 0), to: (5, 0))
        }
    }

    private static func range(from start: (hour: Int, minute: Int), to end: (hour: Int, minute: Int)) -> Range<Int> {
        let startSeconds = secondsIntoTheDay(hour: start.hour, minute: start.minute, second: 0)
        let endSeconds = secondsIntoTheDay(hour: end.hour, minute: end.minute, second: 0)
        return startSeconds ..< (endSeconds == 0 ? secondsPerDay : endSeconds)
    }

    private static func secondsIntoTheDay(hour: Int, minute: Int, second: Int) -> Int {
        let hoursSinceDayStart = (hour - dayStartHour + 24) % 24
        return hoursSinceDayStart * secondsPerHour + minute * secondsPerMinute + second
    }
}
