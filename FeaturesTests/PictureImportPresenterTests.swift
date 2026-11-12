import Application
import Domain
@testable import Features
import Foundation
import SwiftUI
import Testing

private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/Users/someone/Pictures/\(name)")
}

private func readablePictures(_ count: Int) throws -> [URL: Result<PictureFile, PictureFileError>] {
    var answers: [URL: Result<PictureFile, PictureFileError>] = [:]
    for number in 1 ... count {
        answers[file("\(number).jpg")] = try .success(PictureFile(
            content: Data("content of \(number)".utf8),
            fingerprint: ContentFingerprint("fingerprint of \(number)"),
            captureTime: nil,
            pixelSize: PixelSize(width: PixelSize.sharpDesktopWidth, height: PixelSize.sharpDesktopHeight),
        ))
    }
    return answers
}

@MainActor
private func importModel(answering answers: [URL: Result<PictureFile, PictureFileError>]) -> PictureImportModel {
    let library = WallpaperLibraryStandIn()
    let pictureFiles = PictureFilesStandIn(answering: answers)
    let previews = PicturePreviewsStandIn()
    return PictureImportModel(
        createWallpaper: CreateWallpaper(library: library, previews: previews, files: pictureFiles),
        addPictures: AddPictures(library: library, previews: previews, files: pictureFiles),
        addPictureToSlot: AddPictureToSlot(library: library, previews: previews, files: pictureFiles),
        defaultWallpaperNameStem: "Wallpaper",
        wallpaperChanged: { _ in },
    )
}

@MainActor
private func renderedSize(of model: PictureImportModel) throws -> CGSize {
    let screen = Text(verbatim: "Library")
        .frame(width: 500, height: 400)
        .importingPictures(with: model)
    let renderer = ImageRenderer(content: screen)
    return try #require(renderer.nsImage?.size)
}

@MainActor
struct PictureImportPresenterTests {
    @Test func rendersAViewWhenTheModelHasNoOutcome() throws {
        let model = importModel(answering: [:])
        try #require(model.outcome == nil)
        try #require(model.refusal == nil)
        let size = try renderedSize(of: model)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAViewWhenTheModelHasAnOutcome() async throws {
        let answers = try readablePictures(2)
        let model = importModel(answering: answers)
        await model.importFiles(Array(answers.keys), to: .newWallpaper)
        try #require(model.outcome != nil)
        let size = try renderedSize(of: model)
        #expect(model.outcome != nil)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersAViewWhenTheModelHasARefusal() async throws {
        let answers = try readablePictures(9)
        let model = importModel(answering: answers)
        await model.importFiles(Array(answers.keys), to: .newWallpaper)
        try #require(model.refusal == .tooManyFiles(most: 8))
        let size = try renderedSize(of: model)
        #expect(model.refusal == .tooManyFiles(most: 8))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
