import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO
import Infrastructure
import Testing
import UniformTypeIdentifiers

private enum PictureMakingFailure: Error {
    case drawingFailed
    case encodingFailed
}

private struct ChosenFolder {
    let url: URL

    static func make() throws -> Self {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ChosenPictureFilesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return Self(url: url)
    }

    func file(named name: String, containing content: Data) throws -> URL {
        let file = url.appending(path: name)
        try content.write(to: file)
        return file
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private func withChosenFolder(_ test: (ChosenFolder) async throws -> Void) async throws {
    let folder = try ChosenFolder.make()
    defer { folder.remove() }
    try await test(folder)
}

private func pngContent(width: Int, height: Int) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ), let image = context.makeImage() else {
        throw PictureMakingFailure.drawingFailed
    }

    let content = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        content as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil,
    ) else {
        throw PictureMakingFailure.encodingFailed
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw PictureMakingFailure.encodingFailed
    }

    return content as Data
}

private func picture(in file: URL) async throws -> PictureFile {
    try await ChosenPictureFiles().picture(in: file)
}

private func readingFails(with expectedError: PictureFileError, for file: URL) async {
    await #expect(throws: expectedError) {
        try await ChosenPictureFiles().picture(in: file)
    }
}

private func isAPNG(_ content: Data) -> Bool {
    guard let source = CGImageSourceCreateWithData(content as CFData, nil) else {
        return false
    }

    return CGImageSourceGetType(source) as String? == UTType.png.identifier
}

private extension Trait where Self == ConditionTrait {
    static var enabledWhenThisMacEncodesVideo: Self {
        .enabled(if: TestVideo.canBeEncodedOnThisMac, "This Mac has no H.264 encoder")
    }
}

struct ChosenPictureFilesTests {
    @Test func aPNGFileGivesItsOwnBytesAndPixelSize() async throws {
        try await withChosenFolder { folder in
            let content = try pngContent(width: 64, height: 48)
            let file = try folder.file(named: "picture.png", containing: content)

            let picture = try await picture(in: file)

            #expect(picture.content == content)
            #expect(try picture.pixelSize == PixelSize(width: 64, height: 48))
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [TestVideo.Container.mov, .mp4])
    func aVideoFileGivesAPNGOfItsFrame(container: TestVideo.Container) async throws {
        try await withChosenFolder { folder in
            let file = try await TestVideo(frameCount: 4, container: container).written(into: folder.url)

            let picture = try await picture(in: file)

            #expect(isAPNG(picture.content))
            #expect(try picture.pixelSize == PixelSize(width: 640, height: 360))
        }
    }

    @Test func anM4AFileWithSoundOnlyIsSoundOnly() async throws {
        try await withChosenFolder { folder in
            let written = try await TestVideo(tracks: .soundOnly).written(into: folder.url)
            let file = folder.url.appending(path: "song.m4a")
            try FileManager.default.moveItem(at: written, to: file)

            await readingFails(with: .soundOnly, for: file)
        }
    }

    @Test func aTextFileNamedNotesTxtIsNotAPicture() async throws {
        try await withChosenFolder { folder in
            let file = try folder.file(named: "notes.txt", containing: Data("Buy milk and film".utf8))

            await readingFails(with: .notAPicture, for: file)
        }
    }

    @Test func aFileWithNoExtensionIsNotAPicture() async throws {
        try await withChosenFolder { folder in
            let file = try folder.file(named: "notes", containing: Data("Buy milk and film".utf8))

            await readingFails(with: .notAPicture, for: file)
        }
    }

    @Test func aFileNamedClipMovWhoseBytesAreNotAVideoIsDamaged() async throws {
        try await withChosenFolder { folder in
            let file = try await TestVideo(damage: .bytesThatAreNotAVideo).written(into: folder.url, named: "clip")

            await readingFails(with: .damaged, for: file)
        }
    }

    @Test(arguments: ["missing.png", "missing.mov"])
    func aPathWhereNoFileIsIsNotFound(name: String) async throws {
        try await withChosenFolder { folder in
            await readingFails(with: .notFound, for: folder.url.appending(path: name))
        }
    }
}
