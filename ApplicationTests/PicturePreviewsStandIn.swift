import Application
import Foundation

struct PicturePreviewsStandIn: PicturePreviews {
    private static let previewMark = Data("preview of ".utf8)

    private let unreadableContent: Data?
    private let failureForUnreadableContent: PicturePreviewError

    init(failingFor unreadableContent: Data? = nil, with failure: PicturePreviewError = .unreadable) {
        self.unreadableContent = unreadableContent
        self.failureForUnreadableContent = failure
    }

    static func preview(of content: Data) -> Data {
        previewMark + content
    }

    func preview(ofPictureWith content: Data) async throws(PicturePreviewError) -> Data {
        if content == unreadableContent {
            throw failureForUnreadableContent
        }
        return Self.preview(of: content)
    }
}
