import Application
import CoreGraphics
import CryptoKit
import Domain
import Foundation
import ImageIO
@testable import Infrastructure
import Testing

private let noReadingAllowed = 0o000
private let readableByOwner = 0o644
private let pngTypeIdentifier = "public.png"

private struct VideoFolder {
    let url: URL

    static func make() throws -> Self {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "AVFoundationVideoFramesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return Self(url: url)
    }

    var namesOfItsFiles: Set<String> {
        get throws {
            try Set(FileManager.default.contentsOfDirectory(atPath: url.path))
        }
    }

    func remove() {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
        for case let item as URL in enumerator?.allObjects ?? [] {
            try? FileManager.default.setAttributes([.posixPermissions: readableByOwner], ofItemAtPath: item.path)
        }
        try? FileManager.default.removeItem(at: url)
    }
}

private func withVideoFolder(_ test: (VideoFolder) async throws -> Void) async throws {
    let folder = try VideoFolder.make()
    defer { folder.remove() }
    try await test(folder)
}

private func sha256InLowercaseHexadecimal(of content: Data) -> String {
    SHA256.hash(data: content).reduce(into: "") { text, byte in
        let digits = String(byte, radix: 16)
        text += digits.count == 1 ? "0" + digits : digits
    }
}

private func picture(in file: URL) async throws -> PictureFile {
    try await AVFoundationVideoFrames().picture(in: file)
}

private func readingFails(
    with expectedError: PictureFileError,
    for file: URL,
) async {
    await #expect(throws: expectedError) {
        try await AVFoundationVideoFrames().picture(in: file)
    }
}

private func decodedByImageIO(_ content: Data) throws -> CGImage {
    let source = try #require(CGImageSourceCreateWithData(content as CFData, nil))
    #expect(CGImageSourceGetType(source) as String? == pngTypeIdentifier)
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

private func frameNumber(shownIn picture: PictureFile) throws -> Int {
    try TestVideo.counter(shownIn: decodedByImageIO(picture.content))
}

private extension Trait where Self == ConditionTrait {
    static var enabledWhenThisMacEncodesVideo: Self {
        .enabled(if: TestVideo.canBeEncodedOnThisMac, "This Mac has no H.264 encoder")
    }

    static var enabledWhenThisMacEncodesHLGVideo: Self {
        .enabled(
            if: TestVideo.canBeEncodedOnThisMac && TestVideo.hybridLogGammaCanBeEncodedOnThisMac,
            "This Mac has no 10-bit HEVC encoder for HLG video",
        )
    }
}

private let largestMidGreyDifference = 0.1
private let largestRoundingStep = 2
private let brightnessOfWhite = 0.98

private func decodedColourSpace(of content: Data) throws -> CGColorSpace {
    try #require(decodedByImageIO(content).colorSpace)
}

private func largestStepBetween(_ first: [UInt8], _ second: [UInt8]) -> Int {
    zip(first, second).map { abs(Int($0) - Int($1)) }.max() ?? .max
}

struct AVFoundationVideoFramesTests {
    @Test(.enabledWhenThisMacEncodesVideo, arguments: TestVideo.Container.allCases)
    func aVideoOfAKindTheMacPlaysGivesOnePicture(container: TestVideo.Container) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(container: container).written(into: folder.url)

            let picture = try await picture(in: file)

            #expect(try picture.pixelSize == PixelSize(width: 640, height: 360))
            #expect(picture.captureTime == nil)
            #expect(try frameNumber(shownIn: picture) == 5)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [(10, 5), (9, 4), (30, 15), (31, 15)])
    func theFrameIsTheOneShownAtHalfTheLengthAndNotAKeyFrame(frameCount: Int, middleFrame: Int) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: frameCount).written(into: folder.url)

            #expect(try await TestVideo.keyFrameNumbers(in: file) == [0])
            #expect(try await frameNumber(shownIn: picture(in: file)) == middleFrame)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [(1920, 1080), (3840, 2160)])
    func theFrameHasTheFullSizeOfTheVideo(width: Int, height: Int) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(width: width, height: height, frameCount: 6).written(into: folder.url)

            let picture = try await picture(in: file)

            let decoded = try decodedByImageIO(picture.content)
            #expect(try picture.pixelSize == PixelSize(width: width, height: height))
            #expect(decoded.width == width)
            #expect(decoded.height == height)
            #expect(!picture.pixelSize.mayLookBlurryOnTheDesktop)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func a1280By720VideoGivesAPictureThatMayLookBlurry() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(width: 1280, height: 720).written(into: folder.url)

            #expect(try await picture(in: file).pixelSize.mayLookBlurryOnTheDesktop)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theContentIsAPNGThatImageIODecodes() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)

            let decoded = try await decodedByImageIO(picture(in: file).content)

            #expect(decoded.width == 640)
            #expect(decoded.height == 360)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theFingerprintIsTheSHA256OfTheContentInLowercaseHexadecimal() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)

            let picture = try await picture(in: file)

            #expect(try picture.fingerprint == ContentFingerprint(sha256InLowercaseHexadecimal(of: picture.content)))
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theSameVideoReadTwiceGivesTheSameFingerprint() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)

            let first = try await picture(in: file)
            let second = try await picture(in: file)

            #expect(first.fingerprint == second.fingerprint)
            #expect(first.content == second.content)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func twoDifferentVideosGiveDifferentFingerprints() async throws {
        try await withVideoFolder { folder in
            let first = try await TestVideo(frameCount: 10).written(into: folder.url, named: "first")
            let second = try await TestVideo(frameCount: 20).written(into: folder.url, named: "second")

            #expect(try await picture(in: first).fingerprint != picture(in: second).fingerprint)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theVideoFileIsUntouchedAndItsFolderHoldsNoNewFile() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)
            let digestBefore = try sha256InLowercaseHexadecimal(of: Data(contentsOf: file))
            let filesBefore = try folder.namesOfItsFiles

            _ = try await picture(in: file)

            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(try sha256InLowercaseHexadecimal(of: Data(contentsOf: file)) == digestBefore)
            #expect(try folder.namesOfItsFiles == filesBefore)
            #expect(filesBefore == [file.lastPathComponent])
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theContentStillDecodesToTheFrameAfterTheVideoIsDeleted() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)
            let picture = try await picture(in: file)

            try FileManager.default.removeItem(at: file)

            #expect(try frameNumber(shownIn: picture) == 5)
        }
    }

    @Test func aFileWithSoundAndNoVideoPictureIsSoundOnly() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(tracks: .soundOnly).written(into: folder.url)

            await readingFails(with: .soundOnly, for: file)
        }
    }

    @Test(arguments: [(true, true), (true, false), (false, true), (false, false)])
    func aCopyProtectedFileIsRefusedAsCopyProtectedWhateverElseItHolds(
        hasAVideoPicture: Bool,
        hasSound: Bool,
    ) {
        let contents = VideoFileContents(hasAVideoPicture: hasAVideoPicture, hasSound: hasSound, isCopyProtected: true)

        #expect(AVFoundationVideoFrames.refusal(of: contents) == .copyProtected)
    }

    @Test(arguments: [true, false])
    func aFileWithAVideoPictureThatIsNotCopyProtectedGivesAFrame(hasSound: Bool) {
        let contents = VideoFileContents(hasAVideoPicture: true, hasSound: hasSound, isCopyProtected: false)

        #expect(AVFoundationVideoFrames.refusal(of: contents) == nil)
    }

    @Test func aFileWithoutAVideoPictureIsSoundOnlyWhenItHasSoundAndDamagedWhenItHasNone() {
        let onlySound = VideoFileContents(hasAVideoPicture: false, hasSound: true, isCopyProtected: false)
        let nothing = VideoFileContents(hasAVideoPicture: false, hasSound: false, isCopyProtected: false)

        #expect(AVFoundationVideoFrames.refusal(of: onlySound) == .soundOnly)
        #expect(AVFoundationVideoFrames.refusal(of: nothing) == .damaged)
    }

    @Test(arguments: TestVideo.Container.allCases)
    func aFileNamedLikeAVideoWhoseBytesAreNotAVideoIsDamaged(container: TestVideo.Container) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(container: container, damage: .bytesThatAreNotAVideo)
                .written(into: folder.url)

            await readingFails(with: .damaged, for: file)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func aVideoWhoseMiddleCannotBeReadGivesTheFrameAtTheNearestPointThatCan() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: 20, damage: .cutOffSoThatTheLastWholeFrameIs(6))
                .written(into: folder.url)

            #expect(try await frameNumber(shownIn: picture(in: file)) == 6)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func aVideoOfWhichNoPointCanBeReadIsDamaged() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: 20, damage: .cutOffSoThatNoFrameIsWhole)
                .written(into: folder.url)

            await readingFails(with: .damaged, for: file)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [1, 2, 3])
    func aVideoShorterThanOneSecondGivesOneFrame(frameCount: Int) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: frameCount).written(into: folder.url)

            #expect(try await frameNumber(shownIn: picture(in: file)) == frameCount / 2)
        }
    }

    @Test func aPathWhereNoFileIsIsNotFound() async throws {
        try await withVideoFolder { folder in
            await readingFails(with: .notFound, for: folder.url.appending(path: "missing.mov"))
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func aFileWithoutReadPermissionIsNotPermitted() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo().written(into: folder.url)
            try FileManager.default.setAttributes([.posixPermissions: noReadingAllowed], ofItemAtPath: file.path)

            await readingFails(with: .notPermitted, for: file)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [0, 20])
    func cancellingTheTaskWhileAFrameIsBeingTakenEndsTheCallAsUnexpected(millisecondsIntoTheRead: Int) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(width: 3840, height: 2160, frameCount: 60).written(into: folder.url)
            let reading = Task {
                try await AVFoundationVideoFrames().picture(in: file)
            }

            try await Task.sleep(for: .milliseconds(millisecondsIntoTheRead))
            reading.cancel()

            let failure = await #expect(throws: PictureFileError.self) {
                try await reading.value
            }
            guard case let .unexpected(description) = failure else {
                Issue.record("The cancelled read ended with \(String(describing: failure))")
                return
            }

            #expect(description.contains("stopped"))
        }
    }

    @Test func theSourceReadsNoWholeFileIntoMemoryAndWorksOffTheMainActor() throws {
        let source = try String(
            contentsOf: URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Infrastructure/AVFoundationVideoFrames.swift"),
            encoding: .utf8,
        )

        #expect(!source.contains("Data(contentsOf"))
        #expect(!source.contains("readToEnd"))
        #expect(!source.contains("MainActor"))
        #expect(source.contains("@concurrent\n    public func picture(in file: URL)"))
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [TestVideo.Turn.quarterToTheRight, .quarterToTheLeft])
    func aVideoRecordedUprightGivesAnUprightFrameOfTheUprightSize(turn: TestVideo.Turn) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(
                width: 1920,
                height: 1080,
                frameCount: 6,
                tracks: .sceneWithItsTopLeftCornerMarked,
                turn: turn,
            ).written(into: folder.url)

            let picture = try await picture(in: file)

            let decoded = try decodedByImageIO(picture.content)
            #expect(try picture.pixelSize == PixelSize(width: 1080, height: 1920))
            #expect(decoded.width == 1080)
            #expect(decoded.height == 1920)
            #expect(try TestVideo.cornersShowingTheMark(in: decoded) == [.topLeft])
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo, arguments: [TestVideo.Turn.upsideDown, .mirrored, .notTurned])
    func aVideoTurnedUpsideDownMirroredOrNotAtAllGivesAFrameOfTheStoredSizeShownAsAPlayerShowsIt(
        turn: TestVideo.Turn,
    ) async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: 6, tracks: .sceneWithItsTopLeftCornerMarked, turn: turn)
                .written(into: folder.url)

            let picture = try await picture(in: file)

            let decoded = try decodedByImageIO(picture.content)
            #expect(try picture.pixelSize == PixelSize(width: 640, height: 360))
            #expect(decoded.width == 640)
            #expect(decoded.height == 360)
            #expect(try TestVideo.cornersShowingTheMark(in: decoded) == [.topLeft])
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func aVideoWithNoTurnGivesTheSameFrameAsTheVideoStoresIt() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(frameCount: 10).written(into: folder.url)

            let picture = try await picture(in: file)

            let decoded = try decodedByImageIO(picture.content)
            let storedFrame = try await TestVideo.frame(5, decodedFrom: file)
            #expect(try picture.pixelSize == PixelSize(width: 640, height: 360))
            #expect(try TestVideo.counter(shownIn: decoded) == 5)
            #expect(try largestStepBetween(
                TestVideo.standardRGBValues(of: decoded),
                TestVideo.standardRGBValues(of: storedFrame),
            ) <= largestRoundingStep)
        }
    }

    @Test(.enabledWhenThisMacEncodesHLGVideo)
    func aVideoInHybridLogGammaGivesTheSameMidGreyAsTheSameSceneInStandardRange() async throws {
        try await withVideoFolder { folder in
            let standard = try await TestVideo(tracks: .midGreyWithColourPatches(.standard))
                .written(into: folder.url, named: "standard")
            let extended = try await TestVideo(tracks: .midGreyWithColourPatches(.hybridLogGamma))
                .written(into: folder.url, named: "extended")

            let standardGrey = try await TestVideo.colourOfTheMidGreyArea(
                in: decodedByImageIO(picture(in: standard).content),
            )
            let extendedGrey = try await TestVideo.colourOfTheMidGreyArea(
                in: decodedByImageIO(picture(in: extended).content),
            )

            let difference = extendedGrey.largestChannelDifference(from: standardGrey)
            #expect(difference < largestMidGreyDifference)
            #expect(extendedGrey.brightness < brightnessOfWhite)
            #expect(extendedGrey.brightness >= standardGrey.brightness / 2)
        }
    }

    @Test(.enabledWhenThisMacEncodesHLGVideo)
    func theFrameOfAnExtendedBrightnessVideoIsAStandardRangePictureWithAColourProfile() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(tracks: .midGreyWithColourPatches(.hybridLogGamma)).written(into: folder.url)

            let colourSpace = try await decodedColourSpace(of: picture(in: file).content)

            #expect(colourSpace.copyICCData() != nil)
            #expect(!CGColorSpaceUsesITUR_2100TF(colourSpace))
            #expect(!CGColorSpaceUsesExtendedRange(colourSpace))
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func thePNGOfAStandardRangeFrameCarriesAColourProfile() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(tracks: .midGreyWithColourPatches(.standard)).written(into: folder.url)

            let colourSpace = try await decodedColourSpace(of: picture(in: file).content)

            #expect(colourSpace.copyICCData() != nil)
        }
    }

    @Test(.enabledWhenThisMacEncodesVideo)
    func theFrameOfAStandardRangeVideoHasThePixelValuesTheVideoShowsAtItsMiddle() async throws {
        try await withVideoFolder { folder in
            let file = try await TestVideo(tracks: .midGreyWithColourPatches(.standard)).written(into: folder.url)

            let decoded = try await decodedByImageIO(picture(in: file).content)

            let frameShownAtTheMiddle = try await TestVideo.frame(5, decodedFrom: file)
            #expect(try largestStepBetween(
                TestVideo.standardRGBValues(of: decoded),
                TestVideo.standardRGBValues(of: frameShownAtTheMiddle),
            ) <= largestRoundingStep)
        }
    }
}
