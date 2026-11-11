public enum WallpaperNameError: Error, Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
}
