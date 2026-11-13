import Application
import CoreGraphics
import Domain
@testable import Features
import Foundation
import ImageIO
import SwiftUI
import Testing

private enum PreviewMakingFailure: Error {
    case noDrawingContext, noImage, noEncoder, notEncoded
}

private func previewBytes() throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: 32,
        height: 18,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ) else { throw PreviewMakingFailure.noDrawingContext }

    context.setFillColor(red: 0.8, green: 0.3, blue: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 18))
    guard let image = context.makeImage() else { throw PreviewMakingFailure.noImage }

    let encoded = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        encoded as CFMutableData,
        "public.jpeg" as CFString,
        1,
        nil,
    ) else {
        throw PreviewMakingFailure.noEncoder
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw PreviewMakingFailure.notEncoded }

    return encoded as Data
}

private func addWallpaper(
    picturesBySlot: [Slot: Domain.Picture],
    to library: WallpaperLibraryStandIn,
) async throws -> Wallpaper {
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Summer"), pictures: picturesBySlot)
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for picture in picturesBySlot.values {
        contents[picture.id] = Data("content \(picture.id)".utf8)
        previews[picture.id] = try previewBytes()
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return wallpaper
}

private func picture(madeWith origin: PictureOrigin) throws -> Domain.Picture {
    try Domain.Picture(
        id: PictureID(UUID()),
        origin: origin,
        captureTime: nil,
        fingerprint: ContentFingerprint(UUID().uuidString),
    )
}

@MainActor
private func renderedSize(of screen: WallpaperScreen, height: CGFloat? = nil) throws -> CGSize {
    let renderer = ImageRenderer(content: screen)
    renderer.proposedSize = ProposedViewSize(width: 500, height: height)
    return try #require(renderer.nsImage?.size)
}

@MainActor
private func screen(of model: WallpaperModel) -> WallpaperScreen {
    WallpaperScreen(
        model: model,
        addPictures: { _ in },
        addPicture: { _, _ in },
        addDroppedFiles: { _, _ in },
        addDroppedFile: { _, _, _ in },
    )
}

@MainActor
private func wallpaperModel(over library: WallpaperLibraryStandIn) -> WallpaperModel {
    WallpaperModel(
        openWallpaper: OpenWallpaper(library: library),
        arrangePictures: ArrangePictures(library: library),
        finishArranging: FinishArranging(library: library),
    )
}

@MainActor
struct WallpaperScreenTests {
    @Test func rendersWithNothingOpen() throws {
        let model = wallpaperModel(over: WallpaperLibraryStandIn())
        try #require(model.phase == .nothingOpen)
        let size = try renderedSize(of: screen(of: model))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAWallpaperThatIsStillOpening() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(picturesBySlot: [.dawn: picture(madeWith: .imported)], to: library)
        let model = wallpaperModel(over: library)
        let sizeWhileOpening = SizeSeenWhileOpening()
        await library.beforeAnswering(.wallpaper) { @MainActor in
            sizeWhileOpening.phase = model.phase
            sizeWhileOpening.size = try? renderedSize(of: screen(of: model))
        }
        await model.show(wallpaper.id)
        #expect(sizeWhileOpening.phase == .opening)
        let size = try #require(sizeWhileOpening.size)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAnOpenWallpaperWithAnEmptySlotYourPictureAndAPictureMadeWithAI() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            picturesBySlot: [.dawn: picture(madeWith: .imported), .dusk: picture(madeWith: .madeWithAI)],
            to: library,
        )
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        let size = try renderedSize(of: screen(of: model), height: 600)
        #expect(model.slots.count == 8)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAWallpaperWithTwoPicturesAndSixBorrowingSlots() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            picturesBySlot: [.morning: picture(madeWith: .imported), .dusk: picture(madeWith: .imported)],
            to: library,
        )
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        let borrowingSlots = model.slots.filter { !$0.isFilled && $0.standIn?.preview != nil }
        try #require(borrowingSlots.count == 6)
        let size = try renderedSize(of: screen(of: model), height: 600)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAWallpaperThatIsGone() async throws {
        let model = wallpaperModel(over: WallpaperLibraryStandIn())
        await model.show(WallpaperID(UUID()))
        try #require(model.phase == .gone)
        let size = try renderedSize(of: screen(of: model))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAnUnavailableWallpaper() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpaper, with: .unavailable)
        let model = wallpaperModel(over: library)
        await model.show(WallpaperID(UUID()))
        try #require(model.phase == .unavailable)
        let size = try renderedSize(of: screen(of: model))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}

@MainActor
private final class SizeSeenWhileOpening {
    var phase: WallpaperModel.Phase?
    var size: CGSize?
}
