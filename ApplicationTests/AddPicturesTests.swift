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
        width: Int = PixelSize.sharpDesktopWidth,
        height: Int = PixelSize.sharpDesktopHeight,
        sameContentAs original: String? = nil,
    ) throws {
        let contentName = original ?? name
        let pictureFile = try PictureFile(
            content: content(of: contentName),
            fingerprint: fingerprint(of: contentName),
            captureTime: nil,
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

private func nameOfPicture(heldIn slot: Slot) -> String {
    "held in \(slot).jpg"
}

private func storedWallpaper(
    in library: any WallpaperLibrary,
    holdingPicturesIn filledSlots: [Slot],
) async throws -> Wallpaper {
    var pictures: [Slot: Domain.Picture] = [:]
    var contents: [PictureID: Data] = [:]
    for slot in filledSlots {
        let name = nameOfPicture(heldIn: slot)
        let picture = try Domain.Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: nil,
            fingerprint: fingerprint(of: name),
        )
        pictures[slot] = picture
        contents[picture.id] = content(of: name)
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
    try await library.add(
        wallpaper,
        pictureContents: contents,
        picturePreviews: contents.mapValues(PicturePreviewsStandIn.preview(of:)),
    )
    return wallpaper
}

private func slots(_ count: Int) -> [Slot] {
    Array(Slot.allCases.prefix(count))
}

private func names(_ count: Int) -> [String] {
    (1 ... count).map { "\($0).jpg" }
}

private func add(
    _ chosen: ChosenFiles,
    to wallpaper: WallpaperID,
    in library: any WallpaperLibrary,
) async throws -> PictureAddition {
    try await AddPictures(
        library: library,
        previews: PicturePreviewsStandIn(),
        files: PictureFilesStandIn(answering: chosen.answers),
    )
    .execute(files: chosen.urls, to: wallpaper)
}

private func receivedAKeep(_ library: WallpaperLibraryStandIn) async -> Bool {
    await library.receivedCalls.contains { call in
        switch call {
        case .keep, .keepAdding: true
        default: false
        }
    }
}

private actor LibraryThatRunsOutOfSpace: WallpaperLibrary {
    let storedLibrary = WallpaperLibraryStandIn()
    private var keepsLeft: Int

    init(runningOutAfter keepCount: Int) {
        keepsLeft = keepCount
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
        guard keepsLeft > 0 else { throw .noSpaceLeft }

        keepsLeft -= 1
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
}

struct AddPicturesTests {
    @Test func threeFilesAddedToAWallpaperWithThreeEmptySlotsFillExactlyThoseSlots() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: slots(5))

        let addition = try await add(ChosenFiles(readable: names(3)), to: wallpaper.id, in: library)

        let addedFingerprints = try Set(names(3).map(fingerprint(of:)))
        let fingerprintsInFormerlyEmptySlots = Set(wallpaper.emptySlots.compactMap { slot in
            addition.wallpaper.picture(in: slot)?.fingerprint
        })
        #expect(fingerprintsInFormerlyEmptySlots == addedFingerprints)
        #expect(addition.wallpaper.filledSlotCount == 8)
        #expect(addition.summary.addedPictureCount == 3)
        #expect(addition.summary.skippedFiles.isEmpty)
        #expect(addition.summary.stoppedForLackOfSpace == false)
        #expect(await library.storedWallpapers == [addition.wallpaper])
    }

    @Test func fourFilesForThreeEmptySlotsAreRefusedWithoutReadingAnyFileOrWritingTheLibrary() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: slots(5))
        let chosen = try ChosenFiles(readable: names(4))
        let files = PictureFilesStandIn(answering: chosen.answers)

        await #expect(throws: AddPicturesError.moreFilesThanEmptySlots(emptySlots: 3)) {
            try await AddPictures(library: library, previews: PicturePreviewsStandIn(), files: files)
                .execute(files: chosen.urls, to: wallpaper.id)
        }
        #expect(await files.askedFiles.isEmpty)
        #expect(await receivedAKeep(library) == false)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func aFileForAWallpaperWithNoEmptySlotIsRefused() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: Slot.allCases)

        await #expect(throws: AddPicturesError.noEmptySlot) {
            try await add(ChosenFiles(readable: names(1)), to: wallpaper.id, in: library)
        }
        #expect(await receivedAKeep(library) == false)
    }

    @Test func everyPictureAlreadyInTheWallpaperStaysInItsSlotWithItsID() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn, .midday, .night])

        let addition = try await add(ChosenFiles(readable: names(4)), to: wallpaper.id, in: library)

        for slot in [Slot.dawn, .midday, .night] {
            #expect(addition.wallpaper.picture(in: slot) == wallpaper.picture(in: slot))
        }
        #expect(addition.wallpaper.filledSlotCount == 7)
    }

    @Test func aFileIdenticalToAPictureInTheWallpaperIsSkippedAndTheOthersAreAdded() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        var chosen = try ChosenFiles(readable: ["1.jpg", "2.jpg"])
        try chosen.addReadable("3-copy.jpg", sameContentAs: nameOfPicture(heldIn: .dawn))

        let addition = try await add(chosen, to: wallpaper.id, in: library)

        #expect(addition.wallpaper.filledSlotCount == 3)
        #expect(addition.summary.addedPictureCount == 2)
        #expect(addition.summary.skippedFiles.map(\.name) == ["3-copy.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.alreadyInWallpaper])
    }

    @Test func twoFilesWithTheSameFingerprintGiveOnePictureAndTheSecondIsSkipped() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        var chosen = try ChosenFiles(readable: ["1.jpg"])
        try chosen.addReadable("2.jpg", sameContentAs: "1.jpg")

        let addition = try await add(chosen, to: wallpaper.id, in: library)

        #expect(addition.wallpaper.filledSlotCount == 2)
        #expect(addition.summary.addedPictureCount == 1)
        #expect(addition.summary.skippedFiles.map(\.name) == ["2.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.sameAsAnotherChosenFile])
    }

    @Test func aDamagedFileAmongGoodOnesIsSkippedAndTheGoodOnesAreAdded() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        var chosen = try ChosenFiles(readable: ["1.jpg", "3.jpg"])
        chosen.addFailing("2-broken.jpg", with: .damaged)

        let addition = try await add(chosen, to: wallpaper.id, in: library)

        #expect(addition.wallpaper.filledSlotCount == 3)
        #expect(addition.summary.addedPictureCount == 2)
        #expect(addition.summary.skippedFiles.map(\.name) == ["2-broken.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.damaged])
        #expect(await library.storedWallpapers == [addition.wallpaper])
    }

    @Test func runningOutOfSpaceAtTheSecondOfThreePicturesKeepsTheFirstAndSkipsTheRest() async throws {
        let library = LibraryThatRunsOutOfSpace(runningOutAfter: 1)
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])

        let addition = try await add(ChosenFiles(readable: names(3)), to: wallpaper.id, in: library)

        #expect(addition.wallpaper.filledSlotCount == 2)
        #expect(addition.wallpaper.picture(in: .dawn) == wallpaper.picture(in: .dawn))
        #expect(try addition.wallpaper.holdsPicture(identicalTo: fingerprint(of: "1.jpg")))
        #expect(await library.storedLibrary.storedWallpapers == [addition.wallpaper])
        #expect(await library.storedLibrary.storedPictureContents.count == 2)
        #expect(addition.summary.addedPictureCount == 1)
        #expect(addition.summary.skippedFiles.map(\.name) == ["2.jpg", "3.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.noSpaceLeft, .noSpaceLeft])
        #expect(addition.summary.stoppedForLackOfSpace)
    }

    @Test func aWallpaperWithSevenPicturesTakesOneMoreAndNeverMoreThanEight() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: slots(7))

        await #expect(throws: AddPicturesError.moreFilesThanEmptySlots(emptySlots: 1)) {
            try await add(ChosenFiles(readable: names(2)), to: wallpaper.id, in: library)
        }
        let addition = try await add(ChosenFiles(readable: names(1)), to: wallpaper.id, in: library)

        #expect(addition.wallpaper.filledSlotCount == Wallpaper.mostPictures)
        #expect(await library.storedWallpapers.allSatisfy { $0.filledSlotCount <= Wallpaper.mostPictures })
        #expect(await library.storedWallpapers == [addition.wallpaper])
    }

    @Test func aFileTooSmallForTheDesktopIsAddedAndNamedAsMayLookBlurry() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        var chosen = ChosenFiles()
        try chosen.addReadable("small.jpg", width: 1280, height: 720)
        try chosen.addReadable("sharp.jpg")

        let addition = try await add(chosen, to: wallpaper.id, in: library)

        #expect(addition.summary.addedPictureCount == 2)
        #expect(addition.summary.filesThatMayLookBlurry == ["small.jpg"])
    }

    @Test func addingToAWallpaperThatIsNotInTheLibraryFailsAsGone() async throws {
        let library = WallpaperLibraryStandIn()

        await #expect(throws: AddPicturesError.wallpaperGone) {
            try await add(ChosenFiles(readable: names(1)), to: WallpaperID(UUID()), in: library)
        }
    }

    @Test func whenEveryFileIsSkippedTheWallpaperIsReturnedUnchangedAndTheLibraryIsNotWritten() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        var chosen = ChosenFiles()
        chosen.addFailing("notes.txt", with: .notAPicture)
        chosen.addFailing("photo.jpg", with: .damaged)

        let addition = try await add(chosen, to: wallpaper.id, in: library)

        #expect(addition.wallpaper == wallpaper)
        #expect(addition.summary.addedPictureCount == 0)
        #expect(addition.summary.skippedFiles.map(\.reason) == [.notAPicture, .damaged])
        #expect(await receivedAKeep(library) == false)
    }

    @Test func aLibraryThatCannotKeepTheAddedPictureFailsAsUnavailable() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        await library.fail(.keepAdding, with: .unexpected(description: "disk vanished"))

        await #expect(throws: AddPicturesError.unavailable(description: "disk vanished")) {
            try await add(ChosenFiles(readable: names(1)), to: wallpaper.id, in: library)
        }
    }

    @Test func aLibraryThatCannotReadTheWallpaperFailsAsUnavailableWithoutReadingAnyFile() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holdingPicturesIn: [.dawn])
        await library.fail(.wallpaper, with: .unreadable)
        let chosen = try ChosenFiles(readable: names(1))
        let files = PictureFilesStandIn(answering: chosen.answers)

        let thrown = await #expect(throws: AddPicturesError.self) {
            try await AddPictures(library: library, previews: PicturePreviewsStandIn(), files: files)
                .execute(files: chosen.urls, to: wallpaper.id)
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }

        #expect(await files.askedFiles.isEmpty)
    }
}
