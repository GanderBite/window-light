import Application
import Domain
@testable import Features
import Foundation
import Testing

private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/Users/someone/Pictures/\(name)")
}

private func files(_ count: Int, startingAt first: Int = 1) -> [URL] {
    (first ..< first + count).map { file("\($0).jpg") }
}

private func readablePicture(_ name: String) throws -> PictureFile {
    try PictureFile(
        content: Data("content of \(name)".utf8),
        fingerprint: ContentFingerprint("fingerprint of \(name)"),
        captureTime: nil,
        pixelSize: PixelSize(width: PixelSize.sharpDesktopWidth, height: PixelSize.sharpDesktopHeight),
    )
}

private func answersReading(
    _ readableFiles: [URL],
    failing failingFiles: [URL: PictureFileError] = [:],
) throws -> [URL: Result<PictureFile, PictureFileError>] {
    var answers: [URL: Result<PictureFile, PictureFileError>] = [:]
    for readableFile in readableFiles {
        answers[readableFile] = try .success(readablePicture(readableFile.lastPathComponent))
    }
    for (failingFile, failure) in failingFiles {
        answers[failingFile] = .failure(failure)
    }
    return answers
}

private func readableVideo(
    _ name: String,
    fingerprint: String? = nil,
    width: Int = PixelSize.sharpDesktopWidth,
    height: Int = PixelSize.sharpDesktopHeight,
) throws -> PictureFile {
    try PictureFile(
        content: Data("content of \(name)".utf8),
        fingerprint: ContentFingerprint(fingerprint ?? "fingerprint of \(name)"),
        captureTime: nil,
        pixelSize: PixelSize(width: width, height: height),
    )
}

private func videos(_ count: Int, startingAt first: Int = 1) -> [URL] {
    (first ..< first + count).map { file("\($0).mov") }
}

private let interruptedRead = PictureFileError.unexpected(description: "The read was interrupted.")

@discardableResult
private func addWallpaper(filling slots: [Slot], to library: WallpaperLibraryStandIn) async throws -> Wallpaper {
    var picturesBySlot: [Slot: Domain.Picture] = [:]
    for slot in slots {
        picturesBySlot[slot] = try Domain.Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: nil,
            fingerprint: ContentFingerprint("stored picture in \(slot)"),
        )
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Stored"), pictures: picturesBySlot)
    var contents: [PictureID: Data] = [:]
    for picture in picturesBySlot.values {
        contents[picture.id] = Data("content of \(picture.fingerprint)".utf8)
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: contents)
    return wallpaper
}

@MainActor
private final class ChangedWallpapers {
    weak var reportingModel: PictureImportModel?
    private(set) var reported: [WallpaperID] = []
    private(set) var outcomesSeenWhenReported: [PictureImportModel.Outcome?] = []
    private(set) var importingSeenWhenReported: [Bool?] = []

    func record(_ wallpaper: WallpaperID) {
        reported.append(wallpaper)
        outcomesSeenWhenReported.append(reportingModel?.outcome)
        importingSeenWhenReported.append(reportingModel?.isImporting)
    }
}

@MainActor
private final class SeenWhileImporting {
    var isImporting: Bool?
    var hasStartedASecondImport = false
}

@MainActor
private final class ImportScene {
    let library: WallpaperLibraryStandIn
    let pictureFiles: PictureFilesStandIn
    let changedWallpapers: ChangedWallpapers
    let model: PictureImportModel

    init(
        answering answers: [URL: Result<PictureFile, PictureFileError>] = [:],
        library: WallpaperLibraryStandIn = WallpaperLibraryStandIn(),
        defaultWallpaperNameStem: String = "Wallpaper",
        waitingWhenAskedFor fileWhoseReadWaits: URL? = nil,
    ) {
        self.library = library
        let pictureFiles = PictureFilesStandIn(answering: answers, waitingWhenAskedFor: fileWhoseReadWaits)
        self.pictureFiles = pictureFiles
        let previews = PicturePreviewsStandIn()
        let changedWallpapers = ChangedWallpapers()
        self.changedWallpapers = changedWallpapers
        model = PictureImportModel(
            createWallpaper: CreateWallpaper(library: library, previews: previews, files: pictureFiles),
            addPictures: AddPictures(library: library, previews: previews, files: pictureFiles),
            addPictureToSlot: AddPictureToSlot(library: library, previews: previews, files: pictureFiles),
            defaultWallpaperNameStem: defaultWallpaperNameStem,
            wallpaperChanged: { wallpaper in changedWallpapers.record(wallpaper) },
        )
        changedWallpapers.reportingModel = model
    }
}

@MainActor
struct PictureImportModelTests {
    @Test func backingOutOfChoosingFilesCreatesNothing() async {
        let scene = ImportScene()
        scene.model.chooseFiles(for: .newWallpaper)
        #expect(scene.model.destinationAwaitingFiles == .newWallpaper)
        scene.model.cancelChoosingFiles()
        #expect(scene.model.destinationAwaitingFiles == nil)
        #expect(await scene.library.storedWallpapers.isEmpty)
        #expect(scene.model.outcome == nil)
        #expect(scene.model.refusal == nil)
        #expect(!scene.model.isImporting)
    }

    @Test func importingTwoGoodChosenFilesCreatesAWallpaperAndReportsItChangedBeforeTheOutcome() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        scene.model.chooseFiles(for: .newWallpaper)
        await scene.model.importChosenFiles(chosen)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(!outcome.wallpaperNeedsMorePictures)
        #expect(scene.model.destinationAwaitingFiles == nil)
        #expect(scene.model.refusal == nil)
        let stored = await scene.library.storedWallpapers
        #expect(stored.count == 1)
        #expect(scene.changedWallpapers.reported == stored.map(\.id))
        #expect(scene.changedWallpapers.outcomesSeenWhenReported == [nil])
    }

    @Test func importingNineFilesToANewWallpaperIsRefusedAsTooMany() async throws {
        let chosen = files(9)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == .tooManyFiles(most: 8))
        #expect(scene.model.outcome == nil)
        #expect(await scene.library.storedWallpapers.isEmpty)
        #expect(scene.changedWallpapers.reported.isEmpty)
    }

    @Test func importingOneFileToANewWallpaperIsRefusedAsTooFew() async throws {
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == .tooFewFiles(fewest: 2))
        #expect(scene.model.outcome == nil)
        #expect(await scene.library.storedWallpapers.isEmpty)
        #expect(scene.changedWallpapers.reported.isEmpty)
    }

    @Test func aDamagedFileIsNamedInTheOutcomeAndTheWallpaperNeedsMorePictures() async throws {
        let good = file("good.jpg")
        let damaged = file("damaged.jpg")
        let scene = try ImportScene(answering: answersReading([good], failing: [damaged: .damaged]))
        await scene.model.importFiles([good, damaged], to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 1)
        #expect(outcome.summary.skippedFiles.map(\.name) == ["damaged.jpg"])
        #expect(outcome.summary.skippedFiles.map(\.reason) == [.damaged])
        #expect(outcome.wallpaperNeedsMorePictures)
        #expect(await scene.changedWallpapers.reported == (scene.library.storedWallpapers).map(\.id))
    }

    @Test func twoUnusableFilesGiveAnOutcomeWithNothingAddedAndNoChangedWallpaper() async throws {
        let notAPicture = file("notes.txt")
        let damaged = file("damaged.jpg")
        let scene = try ImportScene(answering: answersReading(
            [],
            failing: [notAPicture: .notAPicture, damaged: .damaged],
        ))
        await scene.model.importFiles([notAPicture, damaged], to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 0)
        #expect(!outcome.wallpaperNeedsMorePictures)
        #expect(scene.changedWallpapers.reported.isEmpty)
        #expect(await scene.library.storedWallpapers.isEmpty)
    }

    @Test func importingThreeFilesToAWallpaperWithThreeEmptySlotsAddsThree() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            filling: [.dawn, .sunrise, .morning, .midday, .afternoon],
            to: library,
        )
        let chosen = files(3)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 3)
        #expect(!outcome.wallpaperNeedsMorePictures)
        #expect(scene.changedWallpapers.reported == [wallpaper.id])
        #expect(await library.storedWallpaper(wallpaper.id)?.filledSlotCount == 8)
    }

    @Test func importingFourFilesToAWallpaperWithThreeEmptySlotsIsRefused() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            filling: [.dawn, .sunrise, .morning, .midday, .afternoon],
            to: library,
        )
        let chosen = files(4)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        #expect(scene.model.refusal == .moreFilesThanEmptySlots(emptySlots: 3))
        #expect(scene.model.outcome == nil)
        #expect(scene.changedWallpapers.reported.isEmpty)
    }

    @Test func importingToAWallpaperWithNoEmptySlotIsRefused() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: Slot.allCases, to: library)
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        #expect(scene.model.refusal == .noEmptySlot)
        #expect(scene.model.outcome == nil)
    }

    @Test func importingOneFileToAnEmptySlotAddsIt() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .slot(.dusk, of: wallpaper.id))
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 1)
        #expect(!outcome.wallpaperNeedsMorePictures)
        #expect(scene.changedWallpapers.reported == [wallpaper.id])
        #expect(await library.storedWallpaper(wallpaper.id)?.picture(in: .dusk) != nil)
    }

    @Test(arguments: [false, true])
    func anUnusableFileAddsNothingToAnUnfinishedWallpaperAndReportsNoChange(intoASlot: Bool) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        #expect(!wallpaper.isReadyToApply)
        let damaged = file("damaged.jpg")
        let scene = try ImportScene(answering: answersReading([], failing: [damaged: .damaged]), library: library)
        let destination: PictureImportModel.Destination =
            intoASlot ? .slot(.dusk, of: wallpaper.id) : .wallpaper(wallpaper.id)
        await scene.model.importFiles([damaged], to: destination)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 0)
        #expect(outcome.summary.skippedFiles.map(\.name) == ["damaged.jpg"])
        #expect(!outcome.wallpaperNeedsMorePictures)
        #expect(scene.changedWallpapers.reported.isEmpty)
        #expect(scene.model.refusal == nil)
        #expect(await library.storedWallpaper(wallpaper.id)?.filledSlotCount == 1)
    }

    @Test func importingAFileToASlotWithARealPictureIsRefused() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .slot(.dawn, of: wallpaper.id))
        #expect(scene.model.refusal == .slotHoldsRealPicture(.dawn))
        #expect(scene.model.outcome == nil)
    }

    @Test func twoVideosCreateAWallpaperWithTwoPictures() async throws {
        let chosen = videos(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(await scene.library.storedWallpapers.first?.filledSlotCount == 2)
    }

    @Test func threeImagesAndTwoVideosCreateAWallpaperWithFivePictures() async throws {
        let chosen = files(3) + videos(2, startingAt: 4)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 5)
        #expect(await scene.library.storedWallpapers.first?.filledSlotCount == 5)
    }

    @Test func fiveImagesAndFourVideosAreRefusedAsTooManyWithoutReadingAnyFile() async throws {
        let chosen = files(5) + videos(4, startingAt: 6)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == .tooManyFiles(most: 8))
        #expect(scene.model.outcome == nil)
        #expect(await scene.pictureFiles.askedFiles.isEmpty)
        #expect(await scene.library.storedWallpapers.isEmpty)
    }

    @Test func threeVideosForAWallpaperWithTwoEmptySlotsAreRefused() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            filling: [.dawn, .sunrise, .morning, .midday, .afternoon, .dusk],
            to: library,
        )
        let chosen = videos(3)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        #expect(scene.model.refusal == .moreFilesThanEmptySlots(emptySlots: 2))
        #expect(scene.model.outcome == nil)
        #expect(await scene.pictureFiles.askedFiles.isEmpty)
    }

    @Test func twoVideosForAWallpaperWithTwoEmptySlotsBothBecomePictures() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            filling: [.dawn, .sunrise, .morning, .midday, .afternoon, .dusk],
            to: library,
        )
        let chosen = videos(2)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        #expect(scene.model.outcome?.summary.addedPictureCount == 2)
        #expect(await library.storedWallpaper(wallpaper.id)?.filledSlotCount == 8)
    }

    @Test func oneVideoForAnEmptySlotPutsItsPictureInThatSlot() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.sunrise], to: library)
        let chosen = videos(1)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .slot(.dawn, of: wallpaper.id))
        #expect(scene.model.outcome?.summary.addedPictureCount == 1)
        #expect(await library.storedWallpaper(wallpaper.id)?.picture(in: .dawn) != nil)
    }

    @Test func twoVideosWithTheSameFingerprintGiveOnePictureAndNameTheOtherAsTheSame() async throws {
        let first = file("1.mov")
        let twin = file("2.mov")
        let other = file("3.mov")
        let answers: [URL: Result<PictureFile, PictureFileError>] = try [
            first: .success(readableVideo("1.mov", fingerprint: "twin")),
            twin: .success(readableVideo("2.mov", fingerprint: "twin")),
            other: .success(readableVideo("3.mov")),
        ]
        let scene = ImportScene(answering: answers)
        await scene.model.importFiles([first, twin, other], to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(outcome.summary.skippedFiles.map(\.name) == ["2.mov"])
        #expect(outcome.summary.skippedFiles.map(\.reason) == [.sameAsAnotherChosenFile])
    }

    @Test func aVideoWithTheFingerprintOfAPictureInTheWallpaperIsSkippedAsAlreadyThere() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        let known = file("known.mov")
        let fresh = file("fresh.mov")
        let answers: [URL: Result<PictureFile, PictureFileError>] = try [
            known: .success(readableVideo("known.mov", fingerprint: "stored picture in dawn")),
            fresh: .success(readableVideo("fresh.mov")),
        ]
        let scene = ImportScene(answering: answers, library: library)
        await scene.model.importFiles([known, fresh], to: .wallpaper(wallpaper.id))
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 1)
        #expect(outcome.summary.skippedFiles.map(\.name) == ["known.mov"])
        #expect(outcome.summary.skippedFiles.map(\.reason) == [.alreadyInWallpaper])
    }

    @Test func aVideoSmallerThanASharpDesktopIsAddedAndNamedAsMaybeBlurry() async throws {
        let sharp = file("sharp.mov")
        let clip = file("clip.mov")
        let answers: [URL: Result<PictureFile, PictureFileError>] = try [
            sharp: .success(readableVideo("sharp.mov")),
            clip: .success(readableVideo("clip.mov", width: 1280, height: 720)),
        ]
        let scene = ImportScene(answering: answers)
        await scene.model.importFiles([sharp, clip], to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(outcome.summary.filesThatMayLookBlurry == ["clip.mov"])
    }

    @Test func importingTwoFilesToOneSlotIsRefusedWithoutCallingAJob() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await scene.model.importFiles(chosen, to: .slot(.dusk, of: wallpaper.id))
        #expect(scene.model.refusal == .oneFileForASlot)
        #expect(scene.model.outcome == nil)
        #expect(await !library.hasReceived(.wallpaper))
        #expect(await scene.pictureFiles.askedFiles.isEmpty)
    }

    @Test(arguments: [false, true])
    func importingToAWallpaperThatIsGoneIsRefused(intoASlot: Bool) async throws {
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen))
        let goneWallpaper = WallpaperID(UUID())
        let destination: PictureImportModel.Destination =
            intoASlot ? .slot(.dusk, of: goneWallpaper) : .wallpaper(goneWallpaper)
        await scene.model.importFiles(chosen, to: destination)
        #expect(scene.model.refusal == .wallpaperGone)
        #expect(scene.model.outcome == nil)
    }

    @Test func aLibraryThatFailsWhileCreatingMeansTheFilesCouldNotBeImported() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.library.failEveryCall(with: .unavailable)
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == .couldNotImport)
        #expect(scene.model.outcome == nil)
        #expect(scene.changedWallpapers.reported.isEmpty)
    }

    @Test(arguments: [false, true])
    func aLibraryThatFailsWhileAddingMeansTheFilesCouldNotBeImported(intoASlot: Bool) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn], to: library)
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        await library.fail(.keepAdding, with: .unavailable)
        let destination: PictureImportModel.Destination =
            intoASlot ? .slot(.dusk, of: wallpaper.id) : .wallpaper(wallpaper.id)
        await scene.model.importFiles(chosen, to: destination)
        #expect(scene.model.refusal == .couldNotImport)
        #expect(scene.model.outcome == nil)
    }

    @Test func aDefaultNameThatIsTooLongMeansTheFilesCouldNotBeImported() async throws {
        let chosen = files(2)
        let scene = try ImportScene(
            answering: answersReading(chosen),
            defaultWallpaperNameStem: String(repeating: "a", count: 60),
        )
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == .couldNotImport)
        #expect(scene.model.outcome == nil)
    }

    @Test func theModelIsImportingWhileAJobRunsAndNotAfterItReturned() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        let seen = SeenWhileImporting()
        let model = scene.model
        await scene.library.beforeAnswering(.wallpapers) { @MainActor in
            seen.isImporting = model.isImporting
        }
        await model.importFiles(chosen, to: .newWallpaper)
        #expect(seen.isImporting == true)
        #expect(!model.isImporting)
        #expect(model.outcome != nil)
    }

    @Test func theModelIsImportingWhileAJobRunsAndNotAfterItThrew() async throws {
        let chosen = files(1)
        let scene = try ImportScene(answering: answersReading(chosen))
        let seen = SeenWhileImporting()
        let model = scene.model
        await scene.library.beforeAnswering(.wallpaper) { @MainActor in
            seen.isImporting = model.isImporting
        }
        await model.importFiles(chosen, to: .wallpaper(WallpaperID(UUID())))
        #expect(seen.isImporting == true)
        #expect(!model.isImporting)
        #expect(model.refusal == .wallpaperGone)
    }

    @Test func aSecondImportStartedWhileOneRunsChangesNothing() async throws {
        let chosen = files(2)
        let alsoChosen = files(3, startingAt: 3)
        let scene = try ImportScene(answering: answersReading(chosen + alsoChosen))
        let seen = SeenWhileImporting()
        let model = scene.model
        model.chooseFiles(for: .newWallpaper)
        await scene.library.beforeAnswering(.wallpapers) { @MainActor in
            guard !seen.hasStartedASecondImport else { return }

            seen.hasStartedASecondImport = true
            await model.importFiles(alsoChosen, to: .newWallpaper)
            await model.importChosenFiles(alsoChosen)
        }
        await model.importChosenFiles(chosen)
        #expect(seen.hasStartedASecondImport)
        #expect(model.outcome?.summary.addedPictureCount == 2)
        #expect(await scene.library.storedWallpapers.count == 1)
        #expect(await scene.pictureFiles.askedFiles.count == 2)
        #expect(scene.changedWallpapers.reported.count == 1)
    }

    @Test func importingChosenFilesWithoutADestinationDoesNothing() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importChosenFiles(chosen)
        #expect(scene.model.outcome == nil)
        #expect(scene.model.refusal == nil)
        #expect(await !scene.library.hasReceived(.wallpapers))
    }

    @Test func importingNoFilesDoesNothing() async {
        let scene = ImportScene()
        scene.model.chooseFiles(for: .newWallpaper)
        await scene.model.importChosenFiles([])
        await scene.model.importFiles([], to: .newWallpaper)
        #expect(scene.model.destinationAwaitingFiles == .newWallpaper)
        #expect(scene.model.outcome == nil)
        #expect(scene.model.refusal == nil)
        #expect(await !scene.library.hasReceived(.wallpapers))
    }

    @Test func anOutcomeClearsAnEarlierRefusal() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles([chosen[0]], to: .newWallpaper)
        #expect(scene.model.refusal != nil)
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.refusal == nil)
        #expect(scene.model.outcome != nil)
    }

    @Test func dismissingClearsTheOutcomeAndTheRefusal() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        await scene.model.importFiles(chosen, to: .newWallpaper)
        #expect(scene.model.outcome != nil)
        scene.model.dismissOutcome()
        #expect(scene.model.outcome == nil)
        await scene.model.importFiles([chosen[0]], to: .newWallpaper)
        #expect(scene.model.refusal != nil)
        scene.model.dismissRefusal()
        #expect(scene.model.refusal == nil)
    }

    @Test func stoppingAfterTwoOfFourFilesWereReadKeepsTheTwoAndReportsTheWallpaperChanged() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .sunrise, .morning, .midday], to: library)
        let chosen = files(4)
        let fileBeingReadWhenStopped = chosen[2]
        let scene = try ImportScene(
            answering: answersReading(
                [chosen[0], chosen[1], chosen[3]],
                failing: [fileBeingReadWhenStopped: interruptedRead],
            ),
            library: library,
            waitingWhenAskedFor: fileBeingReadWhenStopped,
        )
        let model = scene.model
        let runningImport = Task { await model.importFiles(chosen, to: .wallpaper(wallpaper.id)) }
        await scene.pictureFiles.untilTheWaitingReadHasStarted()
        #expect(await scene.pictureFiles.askedFiles == Array(chosen.prefix(3)))
        model.stopImporting()
        model.stopImporting()
        #expect(model.isImporting)
        await scene.pictureFiles.letTheWaitingReadGoOn()
        await runningImport.value
        #expect(!model.isImporting)
        let outcome = try #require(model.outcome)
        #expect(outcome.summary.wasStopped)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(model.refusal == nil)
        #expect(scene.changedWallpapers.reported == [wallpaper.id])
        #expect(await library.storedWallpaper(wallpaper.id)?.filledSlotCount == 6)
        #expect(await scene.pictureFiles.askedFiles == Array(chosen.prefix(3)))
    }

    @Test func aStoppedImportIsStillImportingUntilItsOutcomeIsSet() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .sunrise, .morning, .midday], to: library)
        let chosen = files(2)
        let scene = try ImportScene(
            answering: answersReading([chosen[0]], failing: [chosen[1]: interruptedRead]),
            library: library,
            waitingWhenAskedFor: chosen[1],
        )
        let model = scene.model
        let runningImport = Task { await model.importFiles(chosen, to: .wallpaper(wallpaper.id)) }
        await scene.pictureFiles.untilTheWaitingReadHasStarted()
        #expect(model.isImporting)
        model.stopImporting()
        #expect(model.isImporting)
        await scene.pictureFiles.letTheWaitingReadGoOn()
        await runningImport.value
        #expect(scene.changedWallpapers.importingSeenWhenReported == [true])
        #expect(scene.changedWallpapers.outcomesSeenWhenReported == [nil])
        #expect(model.outcome?.summary.wasStopped == true)
        #expect(!model.isImporting)
    }

    @Test func stoppingBeforeAnyFileWasReadAddsNothingAndReportsNoChange() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .sunrise, .morning, .midday], to: library)
        let chosen = files(4)
        let scene = try ImportScene(answering: answersReading(chosen), library: library)
        let model = scene.model
        await library.beforeAnswering(.wallpaper) { @MainActor in
            model.stopImporting()
        }
        await model.importFiles(chosen, to: .wallpaper(wallpaper.id))
        #expect(!model.isImporting)
        let outcome = try #require(model.outcome)
        #expect(outcome.summary.wasStopped)
        #expect(outcome.summary.addedPictureCount == 0)
        #expect(model.refusal == nil)
        #expect(scene.changedWallpapers.reported.isEmpty)
        #expect(await scene.pictureFiles.askedFiles.isEmpty)
        #expect(await library.storedWallpaper(wallpaper.id)?.filledSlotCount == 4)
    }

    @Test func stoppingWhenNoImportRunsChangesNothing() async throws {
        let chosen = files(2)
        let scene = try ImportScene(answering: answersReading(chosen))
        scene.model.stopImporting()
        #expect(!scene.model.isImporting)
        #expect(scene.model.outcome == nil)
        #expect(scene.model.refusal == nil)
        await scene.model.importFiles(chosen, to: .newWallpaper)
        let outcome = try #require(scene.model.outcome)
        #expect(!outcome.summary.wasStopped)
        #expect(outcome.summary.addedPictureCount == 2)
        scene.model.stopImporting()
        #expect(scene.model.outcome == outcome)
        #expect(scene.model.refusal == nil)
    }

    @Test func aNewImportStartedAfterAStoppedOneRunsToItsEnd() async throws {
        let stoppedFiles = files(2)
        let laterFiles = files(2, startingAt: 3)
        let scene = try ImportScene(
            answering: answersReading([stoppedFiles[1]] + laterFiles, failing: [stoppedFiles[0]: interruptedRead]),
            waitingWhenAskedFor: stoppedFiles[0],
        )
        let model = scene.model
        let stoppedImport = Task { await model.importFiles(stoppedFiles, to: .newWallpaper) }
        await scene.pictureFiles.untilTheWaitingReadHasStarted()
        model.stopImporting()
        await scene.pictureFiles.letTheWaitingReadGoOn()
        await stoppedImport.value
        #expect(model.outcome?.summary.wasStopped == true)
        #expect(model.outcome?.summary.addedPictureCount == 0)
        model.dismissOutcome()
        await model.importFiles(laterFiles, to: .newWallpaper)
        let outcome = try #require(model.outcome)
        #expect(!outcome.summary.wasStopped)
        #expect(outcome.summary.addedPictureCount == 2)
        #expect(!model.isImporting)
        let stored = await scene.library.storedWallpapers
        #expect(stored.count == 1)
        #expect(scene.changedWallpapers.reported == stored.map(\.id))
    }
}
