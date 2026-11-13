import Application
import Domain
import Foundation
import Testing

private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/Users/someone/Pictures/\(name)")
}

private func content(of name: String) -> Data {
    Data("content of \(name)".utf8)
}

private func fingerprint(of name: String) throws -> ContentFingerprint {
    try ContentFingerprint("fingerprint of \(name)")
}

private func captureTime(hour: Int) throws -> CaptureTime {
    try CaptureTime(year: 2026, month: 6, day: 21, hour: hour, minute: 0, second: 0)
}

private struct ChosenFiles {
    private(set) var urls: [URL] = []
    private(set) var answers: [URL: Result<PictureFile, PictureFileError>] = [:]

    init() {}

    init(readable names: [String]) throws {
        for name in names {
            try addReadable(name)
        }
    }

    mutating func addReadable(
        _ name: String,
        captureTime: CaptureTime? = nil,
        width: Int = PixelSize.sharpDesktopWidth,
        height: Int = PixelSize.sharpDesktopHeight,
        sameContentAs original: String? = nil,
    ) throws {
        let contentName = original ?? name
        let pictureFile = try PictureFile(
            content: content(of: contentName),
            fingerprint: fingerprint(of: contentName),
            captureTime: captureTime,
            pixelSize: PixelSize(width: width, height: height),
        )
        add(name, answer: .success(pictureFile))
    }

    mutating func addFailing(_ name: String, with error: PictureFileError) {
        add(name, answer: .failure(error))
    }

    private mutating func add(_ name: String, answer: Result<PictureFile, PictureFileError>) {
        urls.append(file(name))
        answers[file(name)] = answer
    }
}

private func create(
    _ chosen: ChosenFiles,
    stem: String = "Wallpaper",
    in library: any WallpaperLibrary = WallpaperLibraryStandIn(),
    previews: PicturePreviewsStandIn = PicturePreviewsStandIn(),
) async throws -> WallpaperCreation {
    try await CreateWallpaper(
        library: library,
        previews: previews,
        files: PictureFilesStandIn(answering: chosen.answers),
    )
    .execute(files: chosen.urls, defaultNameStem: stem)
}

private func create(
    _ chosen: ChosenFiles,
    in library: WallpaperLibraryStandIn,
    readBy files: PictureFilesStandIn,
    stoppedBeforeTheFirstFile: Bool = false,
) async throws -> WallpaperCreation {
    let createWallpaper = CreateWallpaper(library: library, previews: PicturePreviewsStandIn(), files: files)
    let chosenURLs = chosen.urls
    return try await Task {
        if stoppedBeforeTheFirstFile {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        return try await createWallpaper.execute(files: chosenURLs, defaultNameStem: "Wallpaper")
    }.value
}

private func names(_ count: Int) -> [String] {
    (1 ... count).map { "\($0).jpg" }
}

private func skipReasons(in summary: ImportSummary) -> [String: SkippedFile.Reason] {
    Dictionary(uniqueKeysWithValues: summary.skippedFiles.map { ($0.name, $0.reason) })
}

private actor LibraryThatRunsOutOfSpace: WallpaperLibrary {
    let storedLibrary = WallpaperLibraryStandIn()
    private var storesLeft: Int

    init(runningOutAfter storeCount: Int) {
        storesLeft = storeCount
    }

    func wallpapers() async throws(WallpaperLibraryError) -> [Wallpaper] {
        try await storedLibrary.wallpapers()
    }

    func wallpaper(_ id: WallpaperID) async throws(WallpaperLibraryError) -> Wallpaper {
        try await storedLibrary.wallpaper(id)
    }

    func picturePreviews(of wallpaper: WallpaperID) async throws(WallpaperLibraryError) -> [PictureID: Data] {
        try await storedLibrary.picturePreviews(of: wallpaper)
    }

    func add(
        _ wallpaper: Wallpaper,
        pictureContents: [PictureID: Data],
        picturePreviews: [PictureID: Data],
    ) async throws(WallpaperLibraryError) {
        try useUpOneStore()
        try await storedLibrary.add(wallpaper, pictureContents: pictureContents, picturePreviews: picturePreviews)
    }

    func keep(_ wallpaper: Wallpaper) async throws(WallpaperLibraryError) {
        try await storedLibrary.keep(wallpaper)
    }

    func keep(
        _ wallpaper: Wallpaper,
        addingPictureContents: [PictureID: Data],
        addingPicturePreviews: [PictureID: Data],
    ) async throws(WallpaperLibraryError) {
        try useUpOneStore()
        try await storedLibrary.keep(
            wallpaper,
            addingPictureContents: addingPictureContents,
            addingPicturePreviews: addingPicturePreviews,
        )
    }

    func remove(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try await storedLibrary.remove(wallpaper)
    }

    func wallpaperLastWorkedOn() async throws(WallpaperLibraryError) -> WallpaperID? {
        try await storedLibrary.wallpaperLastWorkedOn()
    }

    func rememberAsLastWorkedOn(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try await storedLibrary.rememberAsLastWorkedOn(wallpaper)
    }

    private func useUpOneStore() throws(WallpaperLibraryError) {
        guard storesLeft > 0 else { throw .noSpaceLeft }

        storesLeft -= 1
    }
}

struct CreateWallpaperTests {
    @Test(arguments: [2, 8])
    func readableFilesAllBecomePicturesOfTheWallpaperAndNoFileIsSkipped(fileCount: Int) async throws {
        let library = WallpaperLibraryStandIn()

        let creation = try await create(ChosenFiles(readable: names(fileCount)), in: library)

        #expect(creation.wallpaper?.filledSlotCount == fileCount)
        #expect(creation.summary.addedPictureCount == fileCount)
        #expect(creation.summary.skippedFiles.isEmpty)
        #expect(creation.summary.stoppedForLackOfSpace == false)
        #expect(await library.storedWallpapers == [creation.wallpaper].compactMap(\.self))
    }

    @Test(arguments: [
        (0, CreateWallpaperError.tooFewFiles(fewest: 2)),
        (1, CreateWallpaperError.tooFewFiles(fewest: 2)),
        (9, CreateWallpaperError.tooManyFiles(most: 8)),
    ])
    func aWrongNumberOfFilesIsRefusedWithoutReadingAnyFileOrAddingToTheLibrary(
        fileCount: Int,
        expectedError: CreateWallpaperError,
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let chosen = try ChosenFiles(readable: fileCount == 0 ? [] : names(fileCount))
        let files = PictureFilesStandIn(answering: chosen.answers)

        await #expect(throws: expectedError) {
            try await CreateWallpaper(library: library, previews: PicturePreviewsStandIn(), files: files)
                .execute(files: chosen.urls, defaultNameStem: "Wallpaper")
        }
        #expect(await library.receivedAnAdd == false)
        #expect(await files.askedFiles.isEmpty)
    }

    @Test func theLibraryHoldsExactlyTheBytesOfEachFileAsTheContentOfItsPicture() async throws {
        let library = WallpaperLibraryStandIn()
        let chosenNames = ["dawn.jpg", "noon.heic", "night.png"]

        let creation = try await create(ChosenFiles(readable: chosenNames), in: library)

        let contentByFingerprint = try Dictionary(uniqueKeysWithValues: chosenNames.map { name in
            try (fingerprint(of: name), content(of: name))
        })
        let pictures = try #require(creation.wallpaper).picturesInDayOrder
        #expect(pictures.count == 3)
        for picture in pictures {
            #expect(await library.storedPictureContents[picture.id] == contentByFingerprint[picture.fingerprint])
            #expect(
                await library.storedPicturePreviews[picture.id]
                    == contentByFingerprint[picture.fingerprint].map(PicturePreviewsStandIn.preview(of:)),
            )
        }
    }

    @Test func aPictureHasTheCaptureTimeItsFileReportedAndNoneWhenItsFileReportedNone() async throws {
        var chosen = ChosenFiles()
        let morning = try captureTime(hour: 9)
        try chosen.addReadable("1.jpg", captureTime: morning)
        try chosen.addReadable("2.jpg")

        let wallpaper = try #require(try await create(chosen).wallpaper)

        #expect(wallpaper.picture(in: .dawn)?.captureTime == morning)
        #expect(wallpaper.picture(in: .sunrise) != nil)
        #expect(wallpaper.picture(in: .sunrise)?.captureTime == nil)
    }

    @Test func everyPictureIsImportedRealAndInASlotInTheFinderOrderOfTheFileNames() async throws {
        let wallpaper = try #require(try await create(ChosenFiles(readable: ["10.jpg", "2.jpg", "1.jpg"])).wallpaper)

        #expect(wallpaper.picturesInDayOrder.allSatisfy { $0.origin == .imported && $0.isReal })
        #expect(try wallpaper.picture(in: .dawn)?.fingerprint == fingerprint(of: "1.jpg"))
        #expect(try wallpaper.picture(in: .sunrise)?.fingerprint == fingerprint(of: "2.jpg"))
        #expect(try wallpaper.picture(in: .morning)?.fingerprint == fingerprint(of: "10.jpg"))
        #expect(wallpaper.filledSlotCount == 3)
    }

    @Test func fiveReadableFilesAndOneDamagedFileGiveFivePicturesAndNameTheDamagedFile() async throws {
        var chosen = try ChosenFiles(readable: names(5))
        chosen.addFailing("broken.jpg", with: .damaged)

        let creation = try await create(chosen)

        #expect(creation.wallpaper?.filledSlotCount == 5)
        #expect(creation.summary.addedPictureCount == 5)
        #expect(creation.summary.skippedFiles.map(\.name) == ["broken.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.damaged])
    }

    @Test func oneReadableFileAndOneDamagedFileGiveAWallpaperWithOnePictureThatIsNotReadyToApply() async throws {
        let library = WallpaperLibraryStandIn()
        var chosen = try ChosenFiles(readable: ["1.jpg"])
        chosen.addFailing("2.jpg", with: .damaged)

        let creation = try await create(chosen, in: library)

        let wallpaper = try #require(creation.wallpaper)
        #expect(wallpaper.filledSlotCount == 1)
        #expect(wallpaper.isReadyToApply == false)
        #expect(creation.summary.addedPictureCount == 1)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func twoUnusableFilesGiveNoWallpaperLeaveTheLibraryEmptyAndAreBothNamed() async throws {
        let library = WallpaperLibraryStandIn()
        var chosen = ChosenFiles()
        chosen.addFailing("notes.txt", with: .notAPicture)
        chosen.addFailing("photo.jpg", with: .damaged)

        let creation = try await create(chosen, in: library)

        #expect(creation.wallpaper == nil)
        #expect(creation.summary.addedPictureCount == 0)
        #expect(creation.summary.stoppedForLackOfSpace == false)
        #expect(creation.summary.skippedFiles.map(\.name) == ["notes.txt", "photo.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.notAPicture, .damaged])
        #expect(await library.storedWallpapers.isEmpty)
        #expect(await library.storedPictureContents.isEmpty)
        #expect(await library.receivedAnAdd == false)
    }

    @Test func eachUnusableFileIsSkippedWithTheReasonForWhatWentWrongWithIt() async throws {
        var chosen = try ChosenFiles(readable: ["1.jpg", "2.jpg"])
        chosen.addFailing("3-text.txt", with: .notAPicture)
        chosen.addFailing("4-gone.jpg", with: .notFound)
        chosen.addFailing("5-locked.jpg", with: .notPermitted)
        chosen.addFailing("6-odd.jpg", with: .unexpected(description: "volume vanished"))
        try chosen.addReadable("7-no-preview.jpg")
        try chosen.addReadable("8-preview-crash.jpg")
        let previews = PicturePreviewsStandIn(failingFor: content(of: "7-no-preview.jpg"))

        let creation = try await create(chosen, previews: previews)

        #expect(creation.summary.addedPictureCount == 3)
        #expect(skipReasons(in: creation.summary) == [
            "3-text.txt": .notAPicture,
            "4-gone.jpg": .cannotBeRead,
            "5-locked.jpg": .cannotBeRead,
            "6-odd.jpg": .cannotBeRead,
            "7-no-preview.jpg": .damaged,
        ])
    }

    @Test func aFileWhosePreviewFailsUnexpectedlyCannotBeRead() async throws {
        var chosen = try ChosenFiles(readable: ["1.jpg", "2.jpg"])
        try chosen.addReadable("3.jpg")
        let previews = PicturePreviewsStandIn(
            failingFor: content(of: "3.jpg"),
            with: .unexpected(description: "decoder crashed"),
        )

        let creation = try await create(chosen, previews: previews)

        #expect(skipReasons(in: creation.summary) == ["3.jpg": .cannotBeRead])
        #expect(creation.wallpaper?.filledSlotCount == 2)
    }

    @Test func twoFilesWithTheSameFingerprintGiveOnePictureAndTheSecondIsSkipped() async throws {
        var chosen = try ChosenFiles(readable: ["1.jpg"])
        try chosen.addReadable("2.jpg", sameContentAs: "1.jpg")

        let creation = try await create(chosen)

        #expect(creation.wallpaper?.filledSlotCount == 1)
        #expect(creation.summary.addedPictureCount == 1)
        #expect(creation.summary.skippedFiles.map(\.name) == ["2.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.sameAsAnotherChosenFile])
    }

    @Test func aFileTooSmallForTheDesktopIsAddedAndNamedAsMayLookBlurry() async throws {
        var chosen = ChosenFiles()
        try chosen.addReadable("small.jpg", width: 1280, height: 720)
        try chosen.addReadable("sharp.jpg", width: 1920, height: 1080)

        let creation = try await create(chosen)

        #expect(creation.wallpaper?.filledSlotCount == 2)
        #expect(creation.summary.addedPictureCount == 2)
        #expect(creation.summary.filesThatMayLookBlurry == ["small.jpg"])
    }

    @Test func runningOutOfSpaceAtTheThirdOfFourPicturesKeepsTheFirstTwoAndSkipsTheRest() async throws {
        let library = LibraryThatRunsOutOfSpace(runningOutAfter: 2)

        let creation = try await create(ChosenFiles(readable: names(4)), in: library)

        let wallpaper = try #require(creation.wallpaper)
        #expect(wallpaper.filledSlotCount == 2)
        #expect(try wallpaper.picture(in: .dawn)?.fingerprint == fingerprint(of: "1.jpg"))
        #expect(try wallpaper.picture(in: .sunrise)?.fingerprint == fingerprint(of: "2.jpg"))
        #expect(await library.storedLibrary.storedWallpapers == [wallpaper])
        #expect(await library.storedLibrary.storedPictureContents.count == 2)
        #expect(creation.summary.addedPictureCount == 2)
        #expect(creation.summary.skippedFiles.map(\.name) == ["3.jpg", "4.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.noSpaceLeft, .noSpaceLeft])
        #expect(creation.summary.stoppedForLackOfSpace)
    }

    @Test func noSpaceForTheFirstPictureGivesNoWallpaperAndSaysTheImportStopped() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.add, with: .noSpaceLeft)

        let creation = try await create(ChosenFiles(readable: names(2)), in: library)

        #expect(creation.wallpaper == nil)
        #expect(creation.summary.addedPictureCount == 0)
        #expect(creation.summary.stoppedForLackOfSpace)
        #expect(creation.summary.skippedFiles.map(\.reason) == [.noSpaceLeft, .noSpaceLeft])
        #expect(await library.storedWallpapers.isEmpty)
    }

    @Test func anUnexpectedFailureToAddFailsAsUnavailableWithItsDescription() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.add, with: .unexpected(description: "disk vanished"))

        await #expect(throws: CreateWallpaperError.unavailable(description: "disk vanished")) {
            try await create(ChosenFiles(readable: names(2)), in: library)
        }
    }

    @Test func aLibraryThatCannotKeepAnAddedPictureFailsAsUnavailable() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.keepAdding, with: .notPermitted)

        let thrown = await #expect(throws: CreateWallpaperError.self) {
            try await create(ChosenFiles(readable: names(2)), in: library)
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }
    }

    @Test func aLibraryThatCannotListItsWallpapersFailsAsUnavailableAndAddsNothing() async throws {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpapers, with: .unavailable)

        let thrown = await #expect(throws: CreateWallpaperError.self) {
            try await create(ChosenFiles(readable: names(2)), in: library)
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }

        #expect(await library.receivedAnAdd == false)
    }

    @Test func wallpapersCreatedOneAfterTheOtherAreNumberedFromOneWithTheGivenStem() async throws {
        let library = WallpaperLibraryStandIn()

        let first = try await create(ChosenFiles(readable: ["a.jpg", "b.jpg"]), stem: "Tapeta", in: library)
        let second = try await create(ChosenFiles(readable: ["c.jpg", "d.jpg"]), stem: "Tapeta", in: library)

        #expect(first.wallpaper?.name.text == "Tapeta 1")
        #expect(second.wallpaper?.name.text == "Tapeta 2")
        #expect(first.wallpaper?.id != second.wallpaper?.id)
    }

    @Test func aStemOfFortyNineCharactersMakesTheDefaultNameTooLongAndAddsNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let stem = String(repeating: "a", count: 49)

        await #expect(throws: CreateWallpaperError.defaultNameTooLong(limit: 50)) {
            try await create(ChosenFiles(readable: names(2)), stem: stem, in: library)
        }
        #expect(await library.receivedAnAdd == false)
        #expect(await library.storedWallpapers.isEmpty)
    }

    @Test func creatingAWallpaperDoesNotMarkItAsLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        _ = try await create(ChosenFiles(readable: names(2)), in: library)
        #expect(await library.lastWorkedOn == nil)
    }

    @Test func stoppingWhileTheSecondOfFourFilesIsReadCreatesAWallpaperWithTheFirstPicture() async throws {
        let library = WallpaperLibraryStandIn()
        var chosen = try ChosenFiles(readable: ["1.jpg"])
        chosen.addFailing("2.jpg", with: .unexpected(description: "The read was interrupted."))
        try chosen.addReadable("3.jpg")
        try chosen.addReadable("4.jpg")
        let files = PictureFilesStandIn(answering: chosen.answers, cancellingTheAskingTaskWhenAskedFor: file("2.jpg"))

        let creation = try await create(chosen, in: library, readBy: files)

        let wallpaper = try #require(creation.wallpaper)
        #expect(wallpaper.filledSlotCount == 1)
        #expect(try wallpaper.holdsPicture(identicalTo: fingerprint(of: "1.jpg")))
        #expect(await library.storedWallpapers == [wallpaper])
        #expect(creation.summary.addedPictureCount == 1)
        #expect(creation.summary.wasStopped)
        #expect(creation.summary.skippedFiles.map(\.name) == ["2.jpg", "3.jpg", "4.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.importStopped, .importStopped, .importStopped])
        #expect(await files.askedFiles == [file("1.jpg"), file("2.jpg")])
    }

    @Test func anImportStoppedBeforeTheFirstFileCreatesNoWallpaperAndWritesNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let chosen = try ChosenFiles(readable: names(3))
        let files = PictureFilesStandIn(answering: chosen.answers)

        let creation = try await create(chosen, in: library, readBy: files, stoppedBeforeTheFirstFile: true)

        #expect(creation.wallpaper == nil)
        #expect(await library.receivedAnAdd == false)
        #expect(await library.storedWallpapers.isEmpty)
        #expect(creation.summary.addedPictureCount == 0)
        #expect(creation.summary.wasStopped)
        #expect(creation.summary.skippedFiles.map(\.name) == names(3))
        #expect(creation.summary.skippedFiles.map(\.reason) == [.importStopped, .importStopped, .importStopped])
        #expect(await files.askedFiles.isEmpty)
    }

    @Test func anImportThatIsNotStoppedSaysItWasNotStoppedAndNamesWhatItNamedBefore() async throws {
        var chosen = try ChosenFiles(readable: names(2))
        chosen.addFailing("broken.jpg", with: .damaged)
        try chosen.addReadable("small.jpg", width: 800, height: 600)

        let creation = try await create(chosen)

        #expect(creation.wallpaper?.filledSlotCount == 3)
        #expect(creation.summary.addedPictureCount == 3)
        #expect(creation.summary.wasStopped == false)
        #expect(creation.summary.stoppedForLackOfSpace == false)
        #expect(creation.summary.skippedFiles.map(\.name) == ["broken.jpg"])
        #expect(creation.summary.skippedFiles.map(\.reason) == [.damaged])
        #expect(creation.summary.filesThatMayLookBlurry == ["small.jpg"])
    }
}
