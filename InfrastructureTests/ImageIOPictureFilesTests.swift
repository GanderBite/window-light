import Application
import CoreGraphics
import CryptoKit
import Domain
import Foundation
import ImageIO
import Infrastructure
import Testing
import UniformTypeIdentifiers

private enum PictureKind: CaseIterable {
    case png
    case jpeg
    case tiff
    case heic

    var typeIdentifier: CFString {
        switch self {
        case .png: UTType.png.identifier as CFString
        case .jpeg: UTType.jpeg.identifier as CFString
        case .tiff: UTType.tiff.identifier as CFString
        case .heic: UTType.heic.identifier as CFString
        }
    }

    var fileName: String {
        switch self {
        case .png: "picture.png"
        case .jpeg: "picture.jpg"
        case .tiff: "picture.tiff"
        case .heic: "picture.heic"
        }
    }

    var canBeEncodedOnThisMac: Bool {
        let encodableIdentifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return encodableIdentifiers.contains(typeIdentifier as String)
    }
}

private struct StoredSize {
    let width: Int
    let height: Int
}

private struct PictureFrame {
    let size: StoredSize
    var orientation: Int?
    var dateTimeOriginal: String?
    var tiffDateTime: String?
}

private enum PictureMakingFailure: Error {
    case drawingFailed
    case encodingFailed
}

private let rotatedNinetyDegreesClockwise = 6
private let makerThatGetsTheTIFFGroupWritten = "Window Light Tests"
private let noReadingAllowed = 0o000
private let readableByOwner = 0o644

private struct PictureFolder {
    let url: URL

    static func make() throws -> Self {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImageIOPictureFilesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return Self(url: url)
    }

    func file(named name: String, containing content: Data) throws -> URL {
        let file = url.appending(path: name)
        try content.write(to: file)
        return file
    }

    func remove() {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
        for case let item as URL in enumerator?.allObjects ?? [] {
            try? FileManager.default.setAttributes([.posixPermissions: readableByOwner], ofItemAtPath: item.path)
        }
        try? FileManager.default.removeItem(at: url)
    }
}

private func withPictureFolder(_ test: (PictureFolder) async throws -> Void) async throws {
    let folder = try PictureFolder.make()
    defer { folder.remove() }
    try await test(folder)
}

private func drawnImage(of size: StoredSize) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: size.width,
        height: size.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
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

private func properties(of frame: PictureFrame) -> [CFString: Any] {
    var properties: [CFString: Any] = [:]
    if let orientation = frame.orientation {
        properties[kCGImagePropertyOrientation] = orientation
    }
    if let dateTimeOriginal = frame.dateTimeOriginal {
        properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: dateTimeOriginal]
    }
    if let tiffDateTime = frame.tiffDateTime {
        properties[kCGImagePropertyTIFFDictionary] = [
            kCGImagePropertyTIFFDateTime: tiffDateTime,
            kCGImagePropertyTIFFMake: makerThatGetsTheTIFFGroupWritten,
        ]
    }
    return properties
}

private func pictureContent(_ kind: PictureKind, frames: [PictureFrame]) throws -> Data {
    let content = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        content as CFMutableData,
        kind.typeIdentifier,
        frames.count,
        nil,
    ) else {
        throw PictureMakingFailure.encodingFailed
    }

    for frame in frames {
        try CGImageDestinationAddImage(destination, drawnImage(of: frame.size), properties(of: frame) as CFDictionary)
    }
    guard CGImageDestinationFinalize(destination) else {
        throw PictureMakingFailure.encodingFailed
    }

    return content as Data
}

private func pictureContent(
    _ kind: PictureKind,
    width: Int,
    height: Int,
    orientation: Int? = nil,
    dateTimeOriginal: String? = nil,
    tiffDateTime: String? = nil,
) throws -> Data {
    try pictureContent(kind, frames: [
        PictureFrame(
            size: StoredSize(width: width, height: height),
            orientation: orientation,
            dateTimeOriginal: dateTimeOriginal,
            tiffDateTime: tiffDateTime,
        ),
    ])
}

private func writtenText(of key: CFString, inGroup group: CFString, of content: Data) throws -> String? {
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let groupProperties = properties[group] as? [CFString: Any]
    return groupProperties?[key] as? String
}

private func writtenDateTimeOriginal(in content: Data) throws -> String? {
    try writtenText(of: kCGImagePropertyExifDateTimeOriginal, inGroup: kCGImagePropertyExifDictionary, of: content)
}

private func writtenTIFFDateTime(in content: Data) throws -> String? {
    try writtenText(of: kCGImagePropertyTIFFDateTime, inGroup: kCGImagePropertyTIFFDictionary, of: content)
}

private let wellFormedDateTimeToBeOverwritten = "2001:01:01 01:01:01"

private func jpegContentWithDateTimeOriginalWrittenAsIs(_ written: String) throws -> Data {
    let placeholder = Data(wellFormedDateTimeToBeOverwritten.utf8)
    let replacement = Data(written.utf8)
    try #require(replacement.count <= placeholder.count)
    let paddedReplacement = replacement + Data(repeating: 0, count: placeholder.count - replacement.count)

    var content = try pictureContent(
        .jpeg,
        width: 640,
        height: 480,
        dateTimeOriginal: wellFormedDateTimeToBeOverwritten,
    )
    let placeholderRange = try #require(content.firstRange(of: placeholder))
    content.replaceSubrange(placeholderRange, with: paddedReplacement)
    return content
}

private func sha256InLowercaseHexadecimal(of content: Data) -> String {
    SHA256.hash(data: content).reduce(into: "") { text, byte in
        let digits = String(byte, radix: 16)
        text += digits.count == 1 ? "0" + digits : digits
    }
}

private func picture(in file: URL) async throws -> PictureFile {
    try await ImageIOPictureFiles().picture(in: file)
}

private func readingFails(
    with expectedError: PictureFileError,
    for file: URL,
) async {
    await #expect(throws: expectedError) {
        try await ImageIOPictureFiles().picture(in: file)
    }
}

struct ImageIOPictureFilesTests {
    @Test(arguments: [PictureKind.jpeg, .png, .tiff])
    private func aFileOfACommonKindIsReadAsAPicture(kind: PictureKind) async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(kind, width: 640, height: 480)
            let file = try folder.file(named: kind.fileName, containing: content)

            let picture = try await picture(in: file)

            #expect(picture.content == content)
            #expect(try picture.pixelSize == PixelSize(width: 640, height: 480))
        }
    }

    @Test(.enabled(if: PictureKind.heic.canBeEncodedOnThisMac, "This Mac has no HEIC encoder"))
    func aHEICFileIsReadAsAPicture() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.heic, width: 640, height: 480)
            let file = try folder.file(named: PictureKind.heic.fileName, containing: content)

            let picture = try await picture(in: file)

            #expect(picture.content == content)
            #expect(try picture.pixelSize == PixelSize(width: 640, height: 480))
        }
    }

    @Test func theFileIsStillAtItsPathWithTheSameBytesAfterItIsRead() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.jpeg, width: 640, height: 480)
            let file = try folder.file(named: "picture.jpg", containing: content)

            let picture = try await picture(in: file)

            #expect(picture.content == content)
            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(try Data(contentsOf: file) == content)
        }
    }

    @Test(arguments: [(4000, 3000), (3000, 1000), (1000, 3000), (2000, 2000)])
    func aFileReportsItsSize(width: Int, height: Int) async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(
                named: "picture.jpg",
                containing: pictureContent(.jpeg, width: width, height: height),
            )

            #expect(try await picture(in: file).pixelSize == PixelSize(width: width, height: height))
        }
    }

    @Test func aFileStoredAs320By160WithOrientation6Reports160By320() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(
                named: "picture.jpg",
                containing: pictureContent(.jpeg, width: 320, height: 160, orientation: rotatedNinetyDegreesClockwise),
            )

            #expect(try await picture(in: file).pixelSize == PixelSize(width: 160, height: 320))
        }
    }

    @Test func aTIFFWithTwoFramesOfDifferentSizesReportsTheSizeOfTheFirst() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.tiff, frames: [
                PictureFrame(size: StoredSize(width: 200, height: 100)),
                PictureFrame(size: StoredSize(width: 100, height: 300)),
            ])
            let file = try folder.file(named: "picture.tiff", containing: content)

            #expect(try await picture(in: file).pixelSize == PixelSize(width: 200, height: 100))
        }
    }

    @Test func theCaptureTimeIsTheDateTimeOriginalAsWrittenWithNoTimeZoneApplied() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(
                named: "picture.jpg",
                containing: pictureContent(.jpeg, width: 640, height: 480, dateTimeOriginal: "2026:06:21 17:45:03"),
            )

            let captureTime = try await picture(in: file).captureTime

            #expect(try captureTime == CaptureTime(year: 2026, month: 6, day: 21, hour: 17, minute: 45, second: 3))
        }
    }

    @Test func aFileWithoutDateTimeOriginalHasNoCaptureTime() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(named: "picture.jpg", containing: pictureContent(.jpeg, width: 640, height: 480))

            #expect(try await picture(in: file).captureTime == nil)
        }
    }

    @Test func aFileWithoutDateTimeOriginalHasNoCaptureTimeEvenWhenItsCreationDateIsSet() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(named: "picture.jpg", containing: pictureContent(.jpeg, width: 640, height: 480))
            let creationDate = Date(timeIntervalSince1970: 1_750_000_000)
            try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: file.path)

            #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.creationDate] as? Date == creationDate)
            #expect(try await picture(in: file).captureTime == nil)
        }
    }

    @Test func aFileWithoutDateTimeOriginalHasNoCaptureTimeEvenWhenItCarriesATIFFDateTime() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.jpeg, width: 640, height: 480, tiffDateTime: "2026:06:21 17:45:03")
            let file = try folder.file(named: "picture.jpg", containing: content)

            #expect(try writtenTIFFDateTime(in: content) == "2026:06:21 17:45:03")
            #expect(try writtenDateTimeOriginal(in: content) == nil)
            #expect(try await picture(in: file).captureTime == nil)
        }
    }

    @Test(arguments: ["2026:02:30 10:00:00", "yesterday"])
    func aFileWhoseDateTimeOriginalIsNotARealDateAndTimeIsReadWithNoCaptureTime(written: String) async throws {
        try await withPictureFolder { folder in
            let content = try jpegContentWithDateTimeOriginalWrittenAsIs(written)
            let file = try folder.file(named: "picture.jpg", containing: content)

            #expect(content.firstRange(of: Data(written.utf8)) != nil)
            let picture = try await picture(in: file)

            #expect(picture.captureTime == nil)
            #expect(picture.content == content)
        }
    }

    @Test func twoFilesWithTheSameBytesHaveTheSameFingerprint() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.png, width: 640, height: 480)
            let first = try folder.file(named: "first.png", containing: content)
            let second = try folder.file(named: "second.png", containing: content)

            #expect(try await picture(in: first).fingerprint == picture(in: second).fingerprint)
        }
    }

    @Test func twoFilesWithDifferentBytesHaveDifferentFingerprints() async throws {
        try await withPictureFolder { folder in
            let first = try folder.file(named: "first.png", containing: pictureContent(.png, width: 640, height: 480))
            let second = try folder.file(named: "second.png", containing: pictureContent(.png, width: 480, height: 640))

            #expect(try await picture(in: first).fingerprint != picture(in: second).fingerprint)
        }
    }

    @Test func theFingerprintIsTheSHA256OfTheContentInLowercaseHexadecimal() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.png, width: 640, height: 480)
            let file = try folder.file(named: "picture.png", containing: content)

            let fingerprint = try await picture(in: file).fingerprint

            #expect(try fingerprint == ContentFingerprint(sha256InLowercaseHexadecimal(of: content)))
        }
    }

    @Test func aTextFileNamedNotesTxtIsNotAPicture() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(named: "notes.txt", containing: Data("Buy milk and film".utf8))

            await readingFails(with: .notAPicture, for: file)
        }
    }

    @Test func aTextFileNamedPhotoJpgIsDamaged() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(named: "photo.jpg", containing: Data("Buy milk and film".utf8))

            await readingFails(with: .damaged, for: file)
        }
    }

    @Test func aJPEGCutOffAfterItsFirstHundredBytesIsDamaged() async throws {
        try await withPictureFolder { folder in
            let content = try pictureContent(.jpeg, width: 640, height: 480)
            let file = try folder.file(named: "photo.jpg", containing: content.prefix(100))

            await readingFails(with: .damaged, for: file)
        }
    }

    @Test func aPathWhereNoFileIsIsNotFound() async throws {
        try await withPictureFolder { folder in
            await readingFails(with: .notFound, for: folder.url.appending(path: "missing.jpg"))
        }
    }

    @Test func aFileWithoutReadPermissionIsNotPermitted() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(named: "photo.jpg", containing: pictureContent(.jpeg, width: 640, height: 480))
            try FileManager.default.setAttributes([.posixPermissions: noReadingAllowed], ofItemAtPath: file.path)

            await readingFails(with: .notPermitted, for: file)
        }
    }

    @Test func aFileSmallerThan1920By1080IsReadAndMayLookBlurry() async throws {
        try await withPictureFolder { folder in
            let file = try folder.file(
                named: "picture.jpg",
                containing: pictureContent(.jpeg, width: 1280, height: 720),
            )

            #expect(try await picture(in: file).pixelSize.mayLookBlurryOnTheDesktop)
        }
    }
}
