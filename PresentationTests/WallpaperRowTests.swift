import CoreGraphics
import Presentation
import SwiftUI
import Testing

@MainActor
private func renderedSize(
    of view: some View,
    proposedWidth: CGFloat? = nil,
) -> CGSize? {
    let renderer = ImageRenderer(content: view)
    if let proposedWidth {
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
    }
    return renderer.nsImage?.size
}

private func makePicture(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )
    guard let context else {
        preconditionFailure("A test picture needs a drawing context")
    }

    context.setFillColor(CGColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let picture = context.makeImage() else {
        preconditionFailure("A test picture needs an image")
    }

    return picture
}

private func makePictures(count: Int, width: Int = 60, height: Int = 60) -> [CGImage] {
    (0 ..< count).map { _ in makePicture(width: width, height: height) }
}

@MainActor
struct WallpaperRowTests {
    private let longName = String(repeating: "N", count: 50)

    @Test func rendersThreePicturesInTheLightAppearance() throws {
        let view = WallpaperRow(name: "Dunes", pictures: makePictures(count: 3), caption: "3 of 8 pictures")
            .environment(\.colorScheme, .light)
        let size = try #require(renderedSize(of: view))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersThreePicturesInTheDarkAppearance() throws {
        let view = WallpaperRow(name: "Dunes", pictures: makePictures(count: 3), caption: "3 of 8 pictures")
            .environment(\.colorScheme, .dark)
        let size = try #require(renderedSize(of: view))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersEightPictures() throws {
        let size = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: makePictures(count: 8), caption: "8 of 8 pictures"),
        ))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersNoPicturesWithTheHeightOfARowWithPictures() throws {
        let empty = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: [], caption: "0 of 8 pictures"),
            proposedWidth: 300,
        ))
        let filled = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: makePictures(count: 3), caption: "3 of 8 pictures"),
            proposedWidth: 300,
        ))
        #expect(empty.height == filled.height)
        #expect(empty.height >= 44)
        #expect(empty.height <= 56)
    }

    @Test func staysInsideTheWidthItIsGivenWithALongNameAndEightPictures() throws {
        let size = try #require(renderedSize(
            of: WallpaperRow(name: longName, pictures: makePictures(count: 8), caption: "8 of 8 pictures"),
            proposedWidth: 240,
        ))
        #expect(size.width <= 240)
        #expect(size.width > 0)
    }

    @Test func keepsALongNameOnOneLine() throws {
        let long = try #require(renderedSize(
            of: WallpaperRow(name: longName, pictures: makePictures(count: 8), caption: "8 of 8 pictures"),
            proposedWidth: 240,
        ))
        let short = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: makePictures(count: 8), caption: "8 of 8 pictures"),
            proposedWidth: 240,
        ))
        #expect(long.height == short.height)
    }

    @Test func picturesOfDifferentShapesGiveTheSameHeightAsOneShape() throws {
        let mixed = [
            makePicture(width: 200, height: 40),
            makePicture(width: 40, height: 200),
            makePicture(width: 90, height: 90),
        ]
        let mixedSize = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: mixed, caption: "3 of 8 pictures"),
            proposedWidth: 300,
        ))
        let squareSize = try #require(renderedSize(
            of: WallpaperRow(name: "Dunes", pictures: makePictures(count: 3), caption: "3 of 8 pictures"),
            proposedWidth: 300,
        ))
        #expect(mixedSize.height == squareSize.height)
        #expect(mixedSize.height <= 56)
    }
}
