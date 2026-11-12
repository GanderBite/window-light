public struct PixelSize: Hashable, Sendable {
    public static let sharpDesktopWidth = 1920
    public static let sharpDesktopHeight = 1080

    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) throws(PixelSizeError) {
        guard width >= 1, height >= 1 else {
            throw .notPositive(width: width, height: height)
        }

        self.width = width
        self.height = height
    }

    public var mayLookBlurryOnTheDesktop: Bool {
        width < Self.sharpDesktopWidth || height < Self.sharpDesktopHeight
    }
}
