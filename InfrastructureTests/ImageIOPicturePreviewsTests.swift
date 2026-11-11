import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import Application
import Infrastructure

private struct PixelSize: Equatable, CustomStringConvertible {
    let width: Int
    let height: Int

    var description: String { "\(width) × \(height)" }
}

private enum PictureKind {
    case png
    case jpeg
    case tiff

    var typeIdentifier: CFString {
        switch self {
        case .png: UTType.png.identifier as CFString
        case .jpeg: UTType.jpeg.identifier as CFString
        case .tiff: UTType.tiff.identifier as CFString
        }
    }
}

private struct PictureFrame {
    let size: PixelSize
    var orientation: Int?
}

private enum PictureMakingFailure: Error {
    case drawingFailed
    case encodingFailed
}

private let rotatedNinetyDegreesClockwise = 6

private func drawnImage(of size: PixelSize) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: size.width,
        height: size.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw PictureMakingFailure.drawingFailed
    }
    context.setFillColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
    context.setFillColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
    guard let image = context.makeImage() else {
        throw PictureMakingFailure.drawingFailed
    }
    return image
}

private func pictureContent(_ kind: PictureKind, frames: [PictureFrame]) throws -> Data {
    let content = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        content as CFMutableData,
        kind.typeIdentifier,
        frames.count,
        nil
    ) else {
        throw PictureMakingFailure.encodingFailed
    }
    for frame in frames {
        var properties: [CFString: Any] = [:]
        if let orientation = frame.orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, try drawnImage(of: frame.size), properties as CFDictionary)
    }
    guard CGImageDestinationFinalize(destination) else {
        throw PictureMakingFailure.encodingFailed
    }
    return content as Data
}

private func pictureContent(_ kind: PictureKind, width: Int, height: Int, orientation: Int? = nil) throws -> Data {
    try pictureContent(kind, frames: [PictureFrame(size: PixelSize(width: width, height: height), orientation: orientation)])
}

private func pixelSize(of content: Data) throws -> PixelSize {
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
    let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
    return PixelSize(width: width, height: height)
}

private func kindIdentifier(of content: Data) throws -> String {
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    return try #require(CGImageSourceGetType(source) as String?)
}

private func preview(of content: Data) async throws -> Data {
    try await ImageIOPicturePreviews().preview(ofPictureWith: content)
}

struct ImageIOPicturePreviewsTests {
    @Test func aWidePictureOf1600By900GivesAPreviewOf320By180() async throws {
        let picture = try pictureContent(.png, width: 1600, height: 900)

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 320, height: 180))
    }

    @Test func aTallPictureOf900By1600GivesAPreviewOf180By320() async throws {
        let picture = try pictureContent(.png, width: 900, height: 1600)

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 180, height: 320))
    }

    @Test func aSquarePictureOf1000By1000GivesAPreviewOf320By320() async throws {
        let picture = try pictureContent(.png, width: 1000, height: 1000)

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 320, height: 320))
    }

    @Test func aPictureSmallerThanThePreviewKeepsItsSizeOf100By50() async throws {
        let picture = try pictureContent(.png, width: 100, height: 50)

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 100, height: 50))
    }

    @Test(arguments: [PictureKind.png, .jpeg, .tiff])
    fileprivate func thePreviewOfAPictureOfAnyKindIsAJPEGImage(kind: PictureKind) async throws {
        let picture = try pictureContent(kind, width: 800, height: 600)

        #expect(try kindIdentifier(of: try await preview(of: picture)) == UTType.jpeg.identifier)
    }

    @Test func aPictureStoredAs400By200AndMarkedAsRotatedGivesAnUprightPreviewOf160By320() async throws {
        let picture = try pictureContent(.jpeg, width: 400, height: 200, orientation: rotatedNinetyDegreesClockwise)

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 160, height: 320))
    }

    @Test func aPictureWithSeveralFramesGivesAPreviewOfItsFirstFrame() async throws {
        let picture = try pictureContent(.tiff, frames: [
            PictureFrame(size: PixelSize(width: 200, height: 100)),
            PictureFrame(size: PixelSize(width: 100, height: 300))
        ])

        #expect(try pixelSize(of: try await preview(of: picture)) == PixelSize(width: 200, height: 100))
    }

    @Test func bytesThatAreNotAPictureAreReportedAsUnreadable() async {
        let notAPicture = Data("This is a note, not a picture".utf8)

        await #expect(throws: PicturePreviewError.unreadable) {
            try await ImageIOPicturePreviews().preview(ofPictureWith: notAPicture)
        }
    }

    @Test func noBytesAtAllAreReportedAsUnreadable() async {
        await #expect(throws: PicturePreviewError.unreadable) {
            try await ImageIOPicturePreviews().preview(ofPictureWith: Data())
        }
    }
}
