public struct Picture: Identifiable, Hashable, Sendable {
    public let id: PictureID
    public let origin: PictureOrigin
    public let captureTime: CaptureTime?
    public let fingerprint: ContentFingerprint

    public init(id: PictureID, origin: PictureOrigin, captureTime: CaptureTime?, fingerprint: ContentFingerprint) {
        self.id = id
        self.origin = origin
        self.captureTime = captureTime
        self.fingerprint = fingerprint
    }

    public var isReal: Bool {
        origin.isReal
    }

    public func isIdentical(to other: Self) -> Bool {
        fingerprint == other.fingerprint
    }
}
