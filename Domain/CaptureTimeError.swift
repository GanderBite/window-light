public enum CaptureTimeError: Error, Equatable, Sendable {
    case notADate(year: Int, month: Int, day: Int)
    case notAClockTime(hour: Int, minute: Int, second: Int)
    case frameBeforeTheRecordingStarted(secondsIntoTheRecording: Int)
}
