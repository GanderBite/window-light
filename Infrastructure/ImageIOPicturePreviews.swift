import Application
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageIOPicturePreviews: PicturePreviews {
    private static let longestPreviewSideInPixels = 320
    private static let firstFrame = 0

    public init() {}

    public func preview(ofPictureWith content: Data) async throws(PicturePreviewError) -> Data {
        let previewImage = try Self.uprightPreviewImage(ofPictureWith: content)
        return try Self.jpegContent(of: previewImage)
    }

    private static func uprightPreviewImage(ofPictureWith content: Data) throws(PicturePreviewError) -> CGImage {
        guard let source = CGImageSourceCreateWithData(content as CFData, nil) else {
            throw .unreadable
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestPreviewSideInPixels,
        ]
        guard let previewImage = CGImageSourceCreateThumbnailAtIndex(source, firstFrame, options as CFDictionary) else {
            throw .unreadable
        }

        return previewImage
    }

    private static func jpegContent(of image: CGImage) throws(PicturePreviewError) -> Data {
        let content = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            content as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil,
        ) else {
            throw .unexpected(description: "The JPEG encoder for the preview could not be created")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .unexpected(
                description: "The preview of \(image.width) × \(image.height) pixels could not be encoded as JPEG",
            )
        }

        return content as Data
    }
}
