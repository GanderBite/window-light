import Foundation

public protocol PicturePreviews: Sendable {
    func preview(ofPictureWith content: Data) async throws(PicturePreviewError) -> Data
}

public enum PicturePreviewError: Error, Equatable, Sendable {
    case unreadable
    case unexpected(description: String)
}
