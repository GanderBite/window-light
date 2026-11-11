import Application
import CoreGraphics
import Domain
@testable import Features
import Foundation
import ImageIO
import Testing

private enum PreviewMakingFailure: Error {
    case noDrawingContext, noImage, noEncoder, notEncoded
}

private func previewBytes(width: Int, height: Int) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ) else { throw PreviewMakingFailure.noDrawingContext }

    context.setFillColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
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

private let bytesThatAreNoPicture = Data("these bytes are not a picture".utf8)

@discardableResult
private func addWallpaper(
    named text: String,
    previewsBySlot: [Slot: Data],
    to library: WallpaperLibraryStandIn,
) async throws -> Wallpaper {
    let picturesBySlot = previewsBySlot.mapValues { _ in Picture(id: PictureID(UUID())) }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(text), pictures: picturesBySlot)
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for (slot, picture) in picturesBySlot {
        contents[picture.id] = Data("content \(text) \(slot)".utf8)
        previews[picture.id] = previewsBySlot[slot]
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return wallpaper
}

@discardableResult
private func addWallpaper(named text: String, to library: WallpaperLibraryStandIn) async throws -> Wallpaper {
    try await addWallpaper(named: text, previewsBySlot: [.dawn: previewBytes(width: 32, height: 18)], to: library)
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
private func openedLibraryModel(over library: WallpaperLibraryStandIn) async -> LibraryModel {
    let model = libraryModel(over: library)
    await model.open()
    return model
}

@MainActor
private final class SeenWhileWaiting<Value> {
    var value: Value?
}

@MainActor
struct LibraryModelTests {
    @Test func aNewModelIsOpeningWithNothingElseSet() {
        let model = libraryModel(over: WallpaperLibraryStandIn())
        #expect(model.phase == .opening)
        #expect(model.wallpapers.isEmpty)
        #expect(model.openWallpaperID == nil)
        #expect(model.wallpaperBeingRenamed == nil)
        #expect(model.nameProblem == nil)
        #expect(model.wallpaperAwaitingDeletion == nil)
        #expect(model.problem == nil)
        #expect(!model.isEmpty)
    }

    @Test func openingAnEmptyLibraryIsOpenAndEmpty() async {
        let model = await openedLibraryModel(over: WallpaperLibraryStandIn())
        #expect(model.phase == .open)
        #expect(model.isEmpty)
    }

    @Test func theModelIsOpeningWhileTheLibraryIsBeingRead() async {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpapers, with: .unreadable)
        let model = await openedLibraryModel(over: library)
        await library.workAgain()
        let phaseWhileReading = SeenWhileWaiting<LibraryModel.Phase>()
        await library.beforeAnswering(.wallpapers) { @MainActor in
            phaseWhileReading.value = model.phase
        }
        await model.open()
        #expect(phaseWhileReading.value == .opening)
        #expect(model.phase == .open)
    }

    @Test func openingALibraryOfThreeListsThemInTheLibrarysOrderWithNamesCountsAndPreviews(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let preview = try previewBytes(width: 32, height: 18)
        let zebra = try await addWallpaper(named: "Zebra", previewsBySlot: [.dawn: preview], to: library)
        let apple = try await addWallpaper(
            named: "Apple",
            previewsBySlot: [.dawn: preview, .night: preview],
            to: library,
        )
        let mango = try await addWallpaper(
            named: "Mango",
            previewsBySlot: [.dawn: preview, .midday: preview, .dusk: preview],
            to: library,
        )
        let model = await openedLibraryModel(over: library)
        #expect(model.wallpapers.map(\.id) == [zebra.id, apple.id, mango.id])
        #expect(model.wallpapers.map(\.name) == ["Zebra", "Apple", "Mango"])
        #expect(model.wallpapers.map(\.pictureCount) == [1, 2, 3])
        #expect(model.wallpapers.map(\.previews.count) == [1, 2, 3])
        #expect(!model.isEmpty)
    }

    @Test func previewsAreDecodedInTheOrderOfTheDay() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(
            named: "Day",
            previewsBySlot: [
                .night: previewBytes(width: 20, height: 10),
                .dawn: previewBytes(width: 30, height: 10),
                .midday: previewBytes(width: 40, height: 10),
                .sunrise: previewBytes(width: 10, height: 10),
            ],
            to: library,
        )
        let model = await openedLibraryModel(over: library)
        let previews = try #require(model.wallpapers.first?.previews)
        #expect(previews.map(\.width) == [30, 10, 40, 20])
        #expect(previews.map(\.height) == [10, 10, 10, 10])
    }

    @Test func aPreviewThatCannotBeDecodedIsLeftOutButStillCountsAsAPicture() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(
            named: "Partly broken",
            previewsBySlot: [.dawn: previewBytes(width: 12, height: 8), .dusk: bytesThatAreNoPicture],
            to: library,
        )
        let model = await openedLibraryModel(over: library)
        let entry = try #require(model.wallpapers.first)
        #expect(entry.pictureCount == 2)
        #expect(entry.previews.map(\.width) == [12])
    }

    @Test func openingReopensTheWallpaperLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "First", to: library)
        try await addWallpaper(named: "Second", to: library)
        let third = try await addWallpaper(named: "Third", to: library)
        try await library.rememberAsLastWorkedOn(third.id)
        let model = await openedLibraryModel(over: library)
        #expect(model.openWallpaperID == third.id)
    }

    @Test func openingWithNoWallpaperRememberedOpensNone() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "First", to: library)
        let model = await openedLibraryModel(over: library)
        #expect(model.openWallpaperID == nil)
    }

    @Test func openingAgainWhenTheRememberedWallpaperIsNoLongerRememberedOpensNone() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "First", to: library)
        let remembered = try await addWallpaper(named: "Remembered", to: library)
        try await library.rememberAsLastWorkedOn(remembered.id)
        let model = await openedLibraryModel(over: library)
        #expect(model.openWallpaperID == remembered.id)
        try await library.remove(remembered.id)
        await model.open()
        #expect(model.openWallpaperID == nil)
    }

    @Test func openingAHundredWallpapersOfEightPicturesFinishesInUnderOneSecond() async throws {
        let library = WallpaperLibraryStandIn()
        let preview = try previewBytes(width: 320, height: 180)
        let eightPreviews = Dictionary(uniqueKeysWithValues: Slot.allCases.map { ($0, preview) })
        for number in 1 ... 100 {
            try await addWallpaper(named: "Wallpaper \(number)", previewsBySlot: eightPreviews, to: library)
        }
        let model = libraryModel(over: library)
        let openingTime = await ContinuousClock().measure {
            await model.open()
        }
        #expect(openingTime < .seconds(1))
        #expect(model.wallpapers.count == 100)
        #expect(model.wallpapers.allSatisfy { $0.previews.count == 8 })
        let firstPreview = try #require(model.wallpapers.first?.previews.first)
        #expect(firstPreview.width == 320)
        #expect(firstPreview.height == 180)
    }

    @Test func anUnreadableLibraryGivesThePhaseUnreadableWithNoWallpapers() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Kept", to: library)
        let model = await openedLibraryModel(over: library)
        await library.fail(.wallpapers, with: .unreadable)
        await model.open()
        #expect(model.phase == .unreadable)
        #expect(model.wallpapers.isEmpty)
        #expect(!model.isEmpty)
    }

    @Test func anUnavailableLibraryGivesThePhaseUnavailableWithNoWallpapers() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Kept", to: library)
        let model = await openedLibraryModel(over: library)
        await library.failEveryCall(with: .unavailable)
        await model.open()
        #expect(model.phase == .unavailable)
        #expect(model.wallpapers.isEmpty)
        #expect(!model.isEmpty)
    }

    @Test(arguments: [WallpaperLibraryError.unreadable, .unavailable])
    func openingAgainAfterTheLibraryWorksAgainGivesThePhaseOpen(
        failure: WallpaperLibraryError,
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let kept = try await addWallpaper(named: "Kept", to: library)
        await library.fail(.wallpapers, with: failure)
        let model = await openedLibraryModel(over: library)
        await library.workAgain()
        await model.open()
        #expect(model.phase == .open)
        #expect(model.wallpapers.map(\.id) == [kept.id])
    }

    @Test func openingAgainShowsAWallpaperCreatedElsewhere() async throws {
        let library = WallpaperLibraryStandIn()
        let model = await openedLibraryModel(over: library)
        let created = try await addWallpaper(named: "Created elsewhere", to: library)
        await model.open()
        #expect(model.wallpapers.map(\.id) == [created.id])
        #expect(!model.isEmpty)
    }

    @Test func selectingAWallpaperOpensItAndTheLibraryRemembersIt() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "First", to: library)
        let second = try await addWallpaper(named: "Second", to: library)
        let model = await openedLibraryModel(over: library)
        await model.select(second.id)
        #expect(model.openWallpaperID == second.id)
        #expect(await library.lastWorkedOn == second.id)
        #expect(model.problem == nil)
    }

    @Test func selectingOpensTheWallpaperBeforeTheLibraryAnswers() async throws {
        let library = WallpaperLibraryStandIn()
        let chosen = try await addWallpaper(named: "Chosen", to: library)
        let model = await openedLibraryModel(over: library)
        let openWhileWaiting = SeenWhileWaiting<WallpaperID>()
        await library.beforeAnswering(.wallpaper) { @MainActor in
            openWhileWaiting.value = model.openWallpaperID
        }
        await model.select(chosen.id)
        #expect(openWhileWaiting.value == chosen.id)
    }

    @Test func selectingAWallpaperThatIsGoneRemovesItsEntryAndSaysItIsGone() async throws {
        let library = WallpaperLibraryStandIn()
        let staying = try await addWallpaper(named: "Staying", to: library)
        let gone = try await addWallpaper(named: "Gone", to: library)
        let model = await openedLibraryModel(over: library)
        try await library.remove(gone.id)
        await model.select(gone.id)
        #expect(model.wallpapers.map(\.id) == [staying.id])
        #expect(model.openWallpaperID == nil)
        #expect(model.problem == .wallpaperGone)
    }

    @Test func selectingWhenTheLibraryIsUnavailableKeepsTheSelectionAndSaysTheChangeWasNotKept(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let chosen = try await addWallpaper(named: "Chosen", to: library)
        let model = await openedLibraryModel(over: library)
        await library.fail(.rememberAsLastWorkedOn, with: .unavailable)
        await model.select(chosen.id)
        #expect(model.openWallpaperID == chosen.id)
        #expect(model.wallpapers.map(\.id) == [chosen.id])
        #expect(model.problem == .changeNotKept)
    }

    @Test func startingToRenameMarksTheWallpaperAndClearsAnEarlierNameProblem() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await addWallpaper(named: "First", to: library)
        let second = try await addWallpaper(named: "Second", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(first.id)
        await model.rename(to: "")
        #expect(model.nameProblem == .empty)
        model.startRenaming(second.id)
        #expect(model.wallpaperBeingRenamed == second.id)
        #expect(model.nameProblem == nil)
    }

    @Test func renamingGivesTheEntryAndTheLibraryTheNewNameAndEndsRenaming() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let other = try await addWallpaper(named: "Other", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "Holiday")
        #expect(model.wallpapers.map(\.name) == ["Holiday", "Other"])
        #expect(model.wallpapers.map(\.id) == [wallpaper.id, other.id])
        #expect(await library.storedWallpaper(wallpaper.id)?.name.text == "Holiday")
        #expect(await library.storedWallpaper(other.id)?.name.text == "Other")
        #expect(model.wallpaperBeingRenamed == nil)
    }

    @Test func theEntryShowsTheNameTheLibraryKept() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "  Holiday  ")
        #expect(model.wallpapers.map(\.name) == ["Holiday"])
    }

    @Test func renamingKeepsTheCountAndPreviewsOfTheEntry() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            named: "Summer",
            previewsBySlot: [.dawn: previewBytes(width: 14, height: 9), .night: previewBytes(width: 16, height: 9)],
            to: library,
        )
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "Holiday")
        let entry = try #require(model.wallpapers.first)
        #expect(entry.pictureCount == 2)
        #expect(entry.previews.map(\.width) == [14, 16])
    }

    @Test func aSuccessfulRenameClearsAnEarlierNameProblem() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "   ")
        await model.rename(to: "Holiday")
        #expect(model.nameProblem == nil)
        #expect(model.wallpaperBeingRenamed == nil)
    }

    @Test func anEmptyNameIsRefusedAndRenamingStaysOpen() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "   ")
        #expect(model.nameProblem == .empty)
        #expect(model.wallpaperBeingRenamed == wallpaper.id)
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(await library.storedWallpaper(wallpaper.id)?.name.text == "Summer")
        #expect(model.problem == nil)
    }

    @Test func aNameOfFiftyOneCharactersIsRefusedAsTooLongAndRenamingStaysOpen() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: String(repeating: "a", count: 51))
        #expect(model.nameProblem == .tooLong(limit: 50))
        #expect(model.wallpaperBeingRenamed == wallpaper.id)
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(await library.storedWallpaper(wallpaper.id)?.name.text == "Summer")
    }

    @Test func renamingToTheNameOfAnotherWallpaperSucceeds() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Summer", to: library)
        let winter = try await addWallpaper(named: "Winter", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(winter.id)
        await model.rename(to: "Summer")
        #expect(model.wallpapers.map(\.name) == ["Summer", "Summer"])
        #expect(model.nameProblem == nil)
        #expect(model.problem == nil)
    }

    @Test func cancellingRenamingClearsItAndChangesNoName() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "")
        model.cancelRenaming()
        #expect(model.wallpaperBeingRenamed == nil)
        #expect(model.nameProblem == nil)
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(await library.storedWallpaper(wallpaper.id)?.name.text == "Summer")
        #expect(await !library.hasReceived(.keep))
    }

    @Test func renamingWithoutStartingDoesNothing() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        await model.rename(to: "Holiday")
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(model.nameProblem == nil)
        #expect(await !library.hasReceived(.wallpaper))
        #expect(await !library.hasReceived(.keep))
    }

    @Test func renamingAWallpaperThatIsGoneRemovesItsEntryAndEndsRenaming() async throws {
        let library = WallpaperLibraryStandIn()
        let staying = try await addWallpaper(named: "Staying", to: library)
        let gone = try await addWallpaper(named: "Gone", to: library)
        let model = await openedLibraryModel(over: library)
        try await library.remove(gone.id)
        model.startRenaming(gone.id)
        await model.rename(to: "")
        await model.rename(to: "Holiday")
        #expect(model.wallpapers.map(\.id) == [staying.id])
        #expect(model.wallpaperBeingRenamed == nil)
        #expect(model.nameProblem == nil)
        #expect(model.problem == .wallpaperGone)
    }

    @Test func renamingWithNoSpaceLeftKeepsTheOldNameAndEndsRenaming() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        await library.fail(.keep, with: .noSpaceLeft)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "")
        await model.rename(to: "Holiday")
        #expect(model.problem == .noSpaceLeft)
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(model.wallpaperBeingRenamed == nil)
        #expect(model.nameProblem == nil)
    }

    @Test func renamingWhenTheLibraryIsUnavailableKeepsTheOldNameAndSaysTheChangeWasNotKept(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(named: "Summer", to: library)
        let model = await openedLibraryModel(over: library)
        await library.fail(.keep, with: .unavailable)
        model.startRenaming(wallpaper.id)
        await model.rename(to: "")
        await model.rename(to: "Holiday")
        #expect(model.problem == .changeNotKept)
        #expect(model.wallpapers.map(\.name) == ["Summer"])
        #expect(model.wallpaperBeingRenamed == nil)
        #expect(model.nameProblem == nil)
    }

    @Test func askingToDeleteDeletesNothingAndDecliningLeavesEverythingAsBefore() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await addWallpaper(named: "First", to: library)
        let second = try await addWallpaper(named: "Second", to: library)
        let model = await openedLibraryModel(over: library)
        await model.select(first.id)
        let entriesBefore = model.wallpapers
        let storedBefore = await library.storedWallpapers
        model.askToDelete(second.id)
        #expect(model.wallpaperAwaitingDeletion == entriesBefore.last)
        #expect(entriesBefore.last?.id == second.id)
        #expect(await library.storedWallpaper(second.id) != nil)
        model.declineDeletion()
        #expect(model.wallpaperAwaitingDeletion == nil)
        #expect(model.wallpapers == entriesBefore)
        #expect(model.openWallpaperID == first.id)
        #expect(await library.storedWallpapers == storedBefore)
        #expect(await !library.hasReceived(.remove))
    }

    @Test func confirmingDeletionRemovesTheEntryAndTheWallpaperAndClosesIt() async throws {
        let library = WallpaperLibraryStandIn()
        let staying = try await addWallpaper(named: "Staying", to: library)
        let deleted = try await addWallpaper(named: "Deleted", to: library)
        let model = await openedLibraryModel(over: library)
        await model.select(deleted.id)
        model.askToDelete(deleted.id)
        await model.confirmDeletion()
        #expect(model.wallpapers.map(\.id) == [staying.id])
        #expect(await library.storedWallpaper(deleted.id) == nil)
        #expect(model.openWallpaperID == nil)
        #expect(model.wallpaperAwaitingDeletion == nil)
        #expect(model.problem == nil)
    }

    @Test func deletingAnotherWallpaperKeepsTheOpenOne() async throws {
        let library = WallpaperLibraryStandIn()
        let open = try await addWallpaper(named: "Open", to: library)
        let deleted = try await addWallpaper(named: "Deleted", to: library)
        let model = await openedLibraryModel(over: library)
        await model.select(open.id)
        model.askToDelete(deleted.id)
        await model.confirmDeletion()
        #expect(model.openWallpaperID == open.id)
        #expect(model.wallpapers.map(\.id) == [open.id])
    }

    @Test func afterTheOnlyWallpaperIsDeletedTheLibraryIsEmpty() async throws {
        let library = WallpaperLibraryStandIn()
        let only = try await addWallpaper(named: "Only", to: library)
        let model = await openedLibraryModel(over: library)
        model.askToDelete(only.id)
        await model.confirmDeletion()
        #expect(model.isEmpty)
    }

    @Test func confirmingWithoutAskingDeletesNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let kept = try await addWallpaper(named: "Kept", to: library)
        let model = await openedLibraryModel(over: library)
        await model.confirmDeletion()
        #expect(model.wallpapers.map(\.id) == [kept.id])
        #expect(await !library.hasReceived(.remove))
    }

    @Test func aFailedDeletionKeepsTheEntryAndSaysTheChangeWasNotKeptUntilDismissed() async throws {
        let library = WallpaperLibraryStandIn()
        let kept = try await addWallpaper(named: "Kept", to: library)
        let model = await openedLibraryModel(over: library)
        await library.fail(.remove, with: .unavailable)
        model.askToDelete(kept.id)
        await model.confirmDeletion()
        #expect(model.wallpapers.map(\.id) == [kept.id])
        #expect(model.wallpaperAwaitingDeletion == nil)
        #expect(model.problem == .changeNotKept)
        model.dismissProblem()
        #expect(model.problem == nil)
        #expect(model.wallpapers.map(\.id) == [kept.id])
    }
}
