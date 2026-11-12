import Domain
import Foundation

public protocol PictureFiles: Sendable {
    func picture(in file: URL) async throws(PictureFileError) -> PictureFile
}

public struct PictureFile: Equatable, Sendable {
    public let content: Data
    public let fingerprint: ContentFingerprint
    public let captureTime: CaptureTime?
    public let pixelSize: PixelSize

    public init(content: Data, fingerprint: ContentFingerprint, captureTime: CaptureTime?, pixelSize: PixelSize) {
        self.content = content
        self.fingerprint = fingerprint
        self.captureTime = captureTime
        self.pixelSize = pixelSize
    }
}

public enum PictureFileError: Error, Equatable, Sendable {
    case notAPicture
    case damaged
    case notFound
    case notPermitted
    case unexpected(description: String)
}
