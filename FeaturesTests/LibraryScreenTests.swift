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

    context.setFillColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1)
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

@discardableResult
private func addWallpaper(
    named text: String,
    filling slots: [Slot],
    to library: WallpaperLibraryStandIn,
) async throws -> Wallpaper {
    var picturesBySlot: [Slot: Domain.Picture] = [:]
    for slot in slots {
        picturesBySlot[slot] = try Domain.Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: nil,
            fingerprint: ContentFingerprint(UUID().uuidString),
        )
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(text), pictures: picturesBySlot)
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for (slot, picture) in picturesBySlot {
        contents[picture.id] = Data("content \(text) \(slot)".utf8)
        previews[picture.id] = try previewBytes()
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return wallpaper
}

@MainActor
private func libraryModel(over library: WallpaperLibraryStandIn) -> LibraryModel {
    LibraryModel(
        openLibrary: OpenLibrary(library: library),
        openWallpaper: OpenWallpaper(library: library),
        renameWallpaper: RenameWallpaper(library: library),
        deleteWallpaper: DeleteWallpaper(library: library),
    )
}

@MainActor
private func renderedSize(of screen: LibraryScreen, width: CGFloat, height: CGFloat?) throws -> CGSize {
    let renderer = ImageRenderer(content: screen)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    return try #require(renderer.nsImage?.size)
}

@MainActor
struct LibraryScreenTests {
    @Test func rendersAnEmptyLibrary() async throws {
        let model = libraryModel(over: WallpaperLibraryStandIn())
        await model.open()
        try #require(model.isEmpty)
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: nil)
        #expect(model.isEmpty)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAnUnreadableLibrary() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpapers, with: .unreadable)
        let model = libraryModel(over: library)
        await model.open()
        try #require(model.phase == .unreadable)
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: nil)
        #expect(model.phase == .unreadable)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAnUnavailableLibrary() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpapers, with: .unavailable)
        let model = libraryModel(over: library)
        await model.open()
        try #require(model.phase == .unavailable)
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: nil)
        #expect(model.phase == .unavailable)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersALibraryThatIsStillOpening() throws {
        let model = libraryModel(over: WallpaperLibraryStandIn())
        try #require(model.phase == .opening)
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: nil)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersALibraryOfThreeWallpapers() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Summer", filling: [.dawn, .midday, .dusk], to: library)
        try await addWallpaper(named: "Winter", filling: [.dawn, .night], to: library)
        try await addWallpaper(named: "Autumn", filling: Slot.allCases, to: library)
        let model = libraryModel(over: library)
        await model.open()
        try #require(model.wallpapers.count == 3)
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: 400)
        #expect(model.phase == .open)
        #expect(model.wallpapers.count == 3)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAWallpaperBeingRenamedWithANameProblem() async throws {
        let library = WallpaperLibraryStandIn()
        let summer = try await addWallpaper(named: "Summer", filling: [.dawn, .midday, .dusk], to: library)
        try await addWallpaper(named: "Winter", filling: [.dawn, .night], to: library)
        try await addWallpaper(named: "Autumn", filling: [.midday, .night], to: library)
        let model = libraryModel(over: library)
        await model.open()
        model.startRenaming(summer.id)
        await model.rename(to: String(repeating: "a", count: 51))
        try #require(model.wallpaperBeingRenamed == summer.id)
        try #require(model.nameProblem == .tooLong(limit: 50))
        let size = try renderedSize(of: LibraryScreen(model: model), width: 500, height: 400)
        #expect(model.phase == .open)
        #expect(model.wallpaperBeingRenamed == summer.id)
        #expect(model.nameProblem == .tooLong(limit: 50))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func anEmptyLibraryWithACreateActionIsTallerThanOneWithout() async throws {
        let model = libraryModel(over: WallpaperLibraryStandIn())
        await model.open()
        try #require(model.isEmpty)
        let withoutCreating = try renderedSize(of: LibraryScreen(model: model), width: 500, height: nil)
        let withCreating = try renderedSize(
            of: LibraryScreen(model: model, createWallpaper: {}),
            width: 500,
            height: nil,
        )
        #expect(model.isEmpty)
        #expect(withCreating.height > withoutCreating.height)
    }

    @Test(arguments: [false, true], [false, true])
    func rendersEmptyAndFilledLibrariesWithEachCombinationOfTheTwoClosures(
        givenCreate: Bool,
        givenFiles: Bool,
    ) async throws {
        try await renderEmptyLibrary(givenCreate: givenCreate, givenFiles: givenFiles)
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Summer", filling: [.dawn, .midday], to: library)
        let model = libraryModel(over: library)
        await model.open()
        try #require(!model.isEmpty)
        let size = try renderedSize(
            of: screen(over: model, givenCreate: givenCreate, givenFiles: givenFiles),
            width: 500,
            height: 400,
        )
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    private func screen(over model: LibraryModel, givenCreate: Bool, givenFiles: Bool) -> LibraryScreen {
        LibraryScreen(
            model: model,
            createWallpaper: givenCreate ? {} : nil,
            createWallpaperFromFiles: givenFiles ? { _ in } : nil,
        )
    }

    private func renderEmptyLibrary(givenCreate: Bool, givenFiles: Bool) async throws {
        let model = libraryModel(over: WallpaperLibraryStandIn())
        await model.open()
        try #require(model.isEmpty)
        let size = try renderedSize(
            of: screen(over: model, givenCreate: givenCreate, givenFiles: givenFiles),
            width: 500,
            height: nil,
        )
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
