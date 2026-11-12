public enum PixelSizeError: Error, Equatable, Sendable {
    case notPositive(width: Int, height: Int)
}
