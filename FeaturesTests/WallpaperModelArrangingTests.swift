import Application
import CoreGraphics
import Domain
@testable import Features
import Foundation
import ImageIO
import Testing

private func previewBytes(width: Int) throws -> Data {
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: 18,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ))
    context.fill(CGRect(x: 0, y: 0, width: width, height: 18))
    let encoded = NSMutableData()
    let jpeg = "public.jpeg" as CFString
    let destination = try #require(CGImageDestinationCreateWithData(encoded as CFMutableData, jpeg, 1, nil))
    try CGImageDestinationAddImage(destination, #require(context.makeImage()), nil)
    try #require(CGImageDestinationFinalize(destination))
    return encoded as Data
}

@MainActor
private final class Arranging {
    let library = WallpaperLibraryStandIn()
    private(set) var changedWallpapers: [WallpaperID] = []
    private var previewWidths: [PictureID: Int] = [:]

    lazy var model = WallpaperModel(
        openWallpaper: OpenWallpaper(library: library),
        arrangePictures: ArrangePictures(library: library),
        finishArranging: FinishArranging(library: library),
        wallpaperChanged: { [weak self] wallpaper in self?.changedWallpapers.append(wallpaper) },
    )

    var shownPreviewWidths: [Slot: Int] {
        model.slots.reduce(into: [:]) { shown, state in
            if state.isFilled {
                shown[state.slot] = state.preview?.width
            }
        }
    }

    func picture(_ origin: PictureOrigin = .imported, capturedAt hour: Int? = nil) throws -> Picture {
        let captureTime = try hour.map { try CaptureTime(year: 2026, month: 6, day: 1, hour: $0, minute: 0, second: 0) }
        let made = try Picture(
            id: PictureID(UUID()),
            origin: origin,
            captureTime: captureTime,
            fingerprint: ContentFingerprint(UUID().uuidString),
        )
        previewWidths[made.id] = 16 + previewWidths.count
        return made
    }

    func width(of picture: Picture) -> Int? {
        previewWidths[picture.id]
    }

    func widths(_ picturesBySlot: [Slot: Picture]) -> [Slot: Int] {
        picturesBySlot.compactMapValues(width(of:))
    }

    @discardableResult
    func store(_ picturesBySlot: [Slot: Picture], named text: String = "Summer") async throws -> Wallpaper {
        let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(text), pictures: picturesBySlot)
        var contents: [PictureID: Data] = [:]
        var previews: [PictureID: Data] = [:]
        for held in wallpaper.picturesInDayOrder {
            contents[held.id] = Data("content \(held.id)".utf8)
            previews[held.id] = try previewBytes(width: width(of: held) ?? 8)
        }
        try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
        return wallpaper
    }

    @discardableResult
    func open(_ picturesBySlot: [Slot: Picture]) async throws -> Wallpaper {
        let wallpaper = try await store(picturesBySlot)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        return wallpaper
    }

    func importPicture(_ picture: Picture, into slot: Slot, of wallpaper: WallpaperID) async throws {
        try await store([slot: picture], named: "Import")
        var stored = try #require(await library.storedWallpaper(wallpaper))
        try stored.place(picture, in: slot)
        try await library.keep(stored)
    }

    func storedWidths(of wallpaper: WallpaperID) async -> [Slot: Int] {
        let stored = await library.storedWallpaper(wallpaper)
        return Slot.allCases.reduce(into: [:]) { widths, slot in
            widths[slot] = stored?.picture(in: slot).flatMap(width(of:))
        }
    }

    func standInsFollowTheRule(of wallpaper: WallpaperID) async -> Bool {
        guard let stored = await library.storedWallpaper(wallpaper) else { return false }

        return model.slots.allSatisfy { state in
            state.isFilled || state.standIn?.slot == stored.standIn(for: state.slot)?.slot
        }
    }
}

@MainActor
struct WallpaperModelArrangingTests {
    @Test func movingAPictureToAnEmptySlotFillsItEmptiesTheSourceAndStoresTheArrangement() async throws {
        let arranging = Arranging()
        let sunrise = try arranging.picture()
        let morning = try arranging.picture()
        let wallpaper = try await arranging.open([.sunrise: sunrise, .morning: morning])
        await arranging.model.movePicture(from: .morning, to: .afternoon)
        let expected = arranging.widths([.sunrise: sunrise, .afternoon: morning])
        #expect(arranging.shownPreviewWidths == expected)
        #expect(arranging.model.lastStep == .moved(from: .morning, to: .afternoon))
        #expect(await arranging.storedWidths(of: wallpaper.id) == expected)
    }

    @Test func movingAPictureOntoARealPictureSwapsTheirPreviews() async throws {
        let arranging = Arranging()
        let dawn = try arranging.picture()
        let dusk = try arranging.picture()
        try await arranging.open([.dawn: dawn, .dusk: dusk])
        await arranging.model.movePicture(from: .dawn, to: .dusk)
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: dusk, .dusk: dawn]))
        #expect(arranging.model.lastStep == .swapped(.dawn, with: .dusk))
    }

    @Test func removingTheSecondLastPictureEmptiesTheSlotNeedsMorePicturesAndStaysOpen() async throws {
        let arranging = Arranging()
        let dawn = try arranging.picture()
        try await arranging.open([.dawn: dawn, .dusk: arranging.picture()])
        #expect(!arranging.model.needsMorePictures)
        await arranging.model.removePicture(from: .dusk)
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: dawn]))
        #expect(arranging.model.lastStep == .removed(from: .dusk))
        #expect(arranging.model.needsMorePictures)
        #expect(arranging.model.phase == .open)
    }

    @Test func everyEmptySlotBorrowsFromTheSlotTheStandInRuleGivesAfterEveryStep() async throws {
        let arranging = Arranging()
        let wallpaper = try await arranging.open([
            .dawn: arranging.picture(), .midday: arranging.picture(), .night: arranging.picture(capturedAt: 8),
        ])
        let model = arranging.model
        let steps: [() async -> Void] = [
            { await model.movePicture(from: .dawn, to: .sunset) },
            { await model.movePicture(from: .sunset, to: .midday) },
            { await model.removePicture(from: .sunset) },
            { model.askToPlaceByTimeAgain(); await model.confirmPlacingByTimeAgain() },
            { await model.undo() },
            { await model.redo() },
        ]
        var newStepCounts: [Int] = []
        for step in steps {
            await step()
            #expect(await arranging.standInsFollowTheRule(of: wallpaper.id))
            newStepCounts.append(model.newStepCount)
        }
        #expect(newStepCounts == [1, 2, 3, 4, 4, 4])
    }

    @Test func decliningToPlaceByTimeAgainChangesNothingAndConfirmingPlacesThePicturesByTime() async throws {
        let arranging = Arranging()
        let noon = try arranging.picture(capturedAt: 12)
        let evening = try arranging.picture(capturedAt: 22)
        try await arranging.open([.dawn: noon, .sunrise: evening])
        let model = arranging.model
        let slotsBefore = model.slots
        let callsBefore = await arranging.library.receivedCalls
        model.askToPlaceByTimeAgain()
        #expect(model.isAskingToPlaceByTimeAgain)
        model.declinePlacingByTimeAgain()
        #expect(!model.isAskingToPlaceByTimeAgain)
        #expect(model.slots == slotsBefore && model.lastStep == nil && !model.canUndo)
        #expect(await arranging.library.receivedCalls == callsBefore)
        model.askToPlaceByTimeAgain()
        await model.confirmPlacingByTimeAgain()
        #expect(!model.isAskingToPlaceByTimeAgain)
        #expect(arranging.shownPreviewWidths == arranging.widths([.midday: noon, .night: evening]))
        #expect(model.lastStep == .placedByTimeAgain)
    }

    @Test func placingByTimeAgainThatMovesNoPictureRecordsNoStep() async throws {
        let arranging = Arranging()
        try await arranging.open([
            .midday: arranging.picture(capturedAt: 12),
            .night: arranging.picture(capturedAt: 22),
        ])
        arranging.model.askToPlaceByTimeAgain()
        await arranging.model.confirmPlacingByTimeAgain()
        #expect(arranging.model.lastStep == nil)
        #expect(arranging.model.newStepCount == 0)
        #expect(!arranging.model.canUndo)
    }

    @Test func askingToPlaceByTimeAgainDoesNothingWithoutARealPicture() async throws {
        let arranging = Arranging()
        arranging.model.askToPlaceByTimeAgain()
        #expect(!arranging.model.isAskingToPlaceByTimeAgain)
        try await arranging.open([.dawn: arranging.picture(.madeWithAI), .dusk: arranging.picture(.madeWithAI)])
        #expect(!arranging.model.canPlaceByTimeAgain)
        arranging.model.askToPlaceByTimeAgain()
        #expect(!arranging.model.isAskingToPlaceByTimeAgain)
    }

    @Test func threeUndosAfterAMoveASwapAndARemovalBringTheSlotsBackAndThreeRedosBringTheStepsBack() async throws {
        let arranging = Arranging()
        try await arranging.open([.dawn: arranging.picture(), .midday: arranging.picture()])
        let model = arranging.model
        var shownAfterEachStep = [arranging.shownPreviewWidths]
        await model.movePicture(from: .dawn, to: .sunrise)
        shownAfterEachStep.append(arranging.shownPreviewWidths)
        await model.movePicture(from: .sunrise, to: .midday)
        shownAfterEachStep.append(arranging.shownPreviewWidths)
        await model.removePicture(from: .sunrise)
        shownAfterEachStep.append(arranging.shownPreviewWidths)
        for expected in shownAfterEachStep.reversed().dropFirst() {
            #expect(model.canUndo)
            await model.undo()
            #expect(arranging.shownPreviewWidths == expected)
            #expect(model.canRedo && model.lastStep == .undone)
        }
        #expect(!model.canUndo)
        for expected in shownAfterEachStep.dropFirst() {
            await model.redo()
            #expect(arranging.shownPreviewWidths == expected)
            #expect(model.canUndo && model.lastStep == .redone)
        }
        #expect(!model.canRedo)
    }

    @Test func placingByTimeAgainCanBeUndoneAndRedone() async throws {
        let arranging = Arranging()
        try await arranging.open([.dawn: arranging.picture(capturedAt: 12), .dusk: arranging.picture()])
        let before = arranging.shownPreviewWidths
        arranging.model.askToPlaceByTimeAgain()
        await arranging.model.confirmPlacingByTimeAgain()
        let placed = arranging.shownPreviewWidths
        try #require(placed != before)
        await arranging.model.undo()
        #expect(arranging.shownPreviewWidths == before)
        await arranging.model.redo()
        #expect(arranging.shownPreviewWidths == placed)
    }

    @Test func undoingAMoveOntoAPictureMadeWithAIShowsItAgainAndTheRealPictureWhereItWas() async throws {
        let arranging = Arranging()
        let real = try arranging.picture()
        let madeWithAI = try arranging.picture(.madeWithAI)
        try await arranging.open([.dawn: real, .dusk: madeWithAI])
        await arranging.model.movePicture(from: .dawn, to: .dusk)
        try #require(arranging.shownPreviewWidths == arranging.widths([.dusk: real]))
        await arranging.model.undo()
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: real, .dusk: madeWithAI]))
    }

    @Test func aSlotWithAPictureMadeWithAICannotBeMovedButASlotWithARealPictureCan() async throws {
        let arranging = Arranging()
        try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture(.madeWithAI)])
        let movable = arranging.model.slots.filter(\.canBeMoved).map(\.slot)
        #expect(movable == [.dawn])
    }
}

extension WallpaperModelArrangingTests {
    @Test func undoingAnImportOverAPictureMadeWithAIShowsItAgainAndRedoShowsTheAddedPicture() async throws {
        let arranging = Arranging()
        let madeWithAI = try arranging.picture(.madeWithAI)
        let dawn = try arranging.picture()
        let wallpaper = try await arranging.open([.dawn: dawn, .dusk: madeWithAI])
        let added = try arranging.picture()
        try await arranging.importPicture(added, into: .dusk, of: wallpaper.id)
        await arranging.model.show(wallpaper.id)
        await arranging.model.undo()
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: dawn, .dusk: madeWithAI]))
        await arranging.model.redo()
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: dawn, .dusk: added]))
    }

    @Test func showingTheSameWallpaperAfterAnImportRecordsTheAddedPictureAsAStepThatCanBeUndone() async throws {
        let arranging = Arranging()
        let wallpaper = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        await arranging.model.movePicture(from: .dawn, to: .morning)
        let before = arranging.shownPreviewWidths
        let added = try arranging.picture()
        try await arranging.importPicture(added, into: .night, of: wallpaper.id)
        await arranging.model.show(wallpaper.id)
        var expected = before
        expected[.night] = arranging.width(of: added)
        #expect(arranging.model.lastStep == .picturesAdded)
        #expect(arranging.model.newStepCount == 2)
        #expect(arranging.shownPreviewWidths == expected)
        await arranging.model.undo()
        #expect(arranging.shownPreviewWidths == before)
        await arranging.model.redo()
        #expect(arranging.shownPreviewWidths == expected)
    }

    @Test func showingAnotherWallpaperAndTheFirstAgainForgetsTheStepsAndKeepsTheSlotsAsLeft() async throws {
        let arranging = Arranging()
        let first = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        await arranging.model.movePicture(from: .dawn, to: .midday)
        await arranging.model.removePicture(from: .dusk)
        let left = arranging.shownPreviewWidths
        let second = try await arranging.store([.night: arranging.picture()], named: "Winter")
        await arranging.model.show(second.id)
        #expect(arranging.model.newStepCount == 0 && arranging.model.lastStep == nil)
        await arranging.model.show(first.id)
        #expect(!arranging.model.canUndo && !arranging.model.canRedo)
        #expect(arranging.shownPreviewWidths == left)
    }

    @Test func picturesNoLongerHeldAreDiscardedOnlyWhenAnotherWallpaperIsShownOrBeforeOneOpens() async throws {
        let arranging = Arranging()
        let first = try await arranging.store([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let second = try await arranging.store([.night: arranging.picture()], named: "Winter")
        let library = arranging.library
        await arranging.model.show(first.id)
        let openingCalls = await library.receivedCalls.filter { $0 != .rememberAsLastWorkedOn(first.id) }
        #expect(openingCalls.suffix(3) == [
            .discardPicturesNoLongerHeld(first.id),
            .wallpaper(first.id),
            .picturePreviews(first.id),
        ])
        let callsBeforeArranging = await library.receivedCalls.count
        await arranging.model.movePicture(from: .dawn, to: .morning)
        await arranging.model.undo()
        await arranging.model.redo()
        await arranging.model.removePicture(from: .morning)
        let callsWhileArranging = await library.receivedCalls.dropFirst(callsBeforeArranging)
        #expect(!callsWhileArranging.contains(.discardPicturesNoLongerHeld(first.id)))
        await arranging.model.show(second.id)
        let calls = await library.receivedCalls
        let closing = Array(calls.suffix(5).prefix(2))
        #expect(closing == [.discardPicturesNoLongerHeld(first.id), .discardPicturesNoLongerHeld(second.id)])
    }

    @Test func aChangeTheLibraryCannotKeepLeavesSlotsAndHistoryForAStepAnUndoAndARedo() async throws {
        let arranging = Arranging()
        try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let model = arranging.model
        await model.movePicture(from: .dawn, to: .sunrise)
        await model.movePicture(from: .sunrise, to: .midday)
        await model.undo()
        try #require(model.canUndo && model.canRedo)
        await arranging.library.fail(.keep, with: .noSpaceLeft)
        let failingActions: [() async -> Void] = [
            { await model.movePicture(from: .dusk, to: .night) }, { await model.undo() }, { await model.redo() },
        ]
        let slotsBefore = model.slots
        for action in failingActions {
            await action()
            #expect(model.arrangingFailure == .couldNotSave)
            #expect(model.slots == slotsBefore && model.canUndo && model.canRedo)
            model.dismissArrangingFailure()
            #expect(model.arrangingFailure == nil)
        }
        #expect(arranging.changedWallpapers.count == 3)
    }

    @Test func aStepOnAWallpaperNoLongerInTheLibraryShowsItIsGoneWithNoSlots() async throws {
        let arranging = Arranging()
        let wallpaper = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        try await arranging.library.remove(wallpaper.id)
        await arranging.model.movePicture(from: .dawn, to: .midday)
        #expect(arranging.model.phase == .gone)
        #expect(arranging.model.slots.isEmpty && !arranging.model.canUndo)
    }

    @Test func theWallpaperIsReportedChangedAfterEverySuccessfulStepUndoAndRedoButNotAfterAFailure() async throws {
        let arranging = Arranging()
        let wallpaper = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        await arranging.model.movePicture(from: .dawn, to: .midday)
        await arranging.model.undo()
        await arranging.model.redo()
        await arranging.library.fail(.keep, with: .unavailable)
        await arranging.model.removePicture(from: .midday)
        await arranging.model.movePicture(from: .night, to: .dawn)
        #expect(arranging.changedWallpapers == [wallpaper.id, wallpaper.id, wallpaper.id])
    }

    @Test func actionsSentWhileAnotherIsStoredAreCarriedOutAfterItInTheOrderSent() async throws {
        let arranging = Arranging()
        let dawn = try arranging.picture()
        let dusk = try arranging.picture()
        let wallpaper = try await arranging.open([.dawn: dawn, .dusk: dusk])
        let model = arranging.model
        let sentLater = SentLater()
        await arranging.library.beforeAnswering(.keep) { @MainActor in
            await sentLater.send([{ await model.removePicture(from: .midday) }])
        }
        await model.movePicture(from: .dawn, to: .midday)
        await sentLater.waitUntilCarriedOut()
        #expect(arranging.shownPreviewWidths == arranging.widths([.dusk: dusk]))
        #expect(await arranging.storedWidths(of: wallpaper.id) == arranging.widths([.dusk: dusk]))
        #expect(model.newStepCount == 2)
    }
}

extension WallpaperModelArrangingTests {
    @Test func aShowOfAnotherWallpaperWinsOverAnEarlierShowOfTheOpenOneThatStillWaitsForAStep() async throws {
        let arranging = Arranging()
        let first = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let winterNight = try arranging.picture()
        let second = try await arranging.store([.night: winterNight], named: "Winter")
        let model = arranging.model
        let sentLater = SentLater()
        await arranging.library.beforeAnswering(.keep) { @MainActor in
            await sentLater.send([{ await model.show(first.id) }, { await model.show(second.id) }])
        }
        await model.movePicture(from: .dawn, to: .midday)
        await sentLater.waitUntilCarriedOut()
        #expect(model.phase == .open && model.wallpaperID == second.id && model.name == "Winter")
        #expect(arranging.shownPreviewWidths == arranging.widths([.night: winterNight]))
        #expect(model.lastStep == nil && model.newStepCount == 0 && !model.canUndo)
        let calls = await arranging.library.receivedCalls
        #expect(calls.contains(.discardPicturesNoLongerHeld(second.id)))
        await model.movePicture(from: .night, to: .dawn)
        #expect(arranging.shownPreviewWidths == arranging.widths([.dawn: winterNight]))
    }

    @Test func aShowOfNoWallpaperWinsOverAnEarlierShowOfTheOpenOneThatStillWaitsForAStep() async throws {
        let arranging = Arranging()
        let first = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let model = arranging.model
        let sentLater = SentLater()
        await arranging.library.beforeAnswering(.keep) { @MainActor in
            await sentLater.send([{ await model.show(first.id) }, { await model.show(nil) }])
        }
        await model.movePicture(from: .dawn, to: .midday)
        await sentLater.waitUntilCarriedOut()
        #expect(model.phase == .nothingOpen && model.wallpaperID == nil && model.name.isEmpty)
        #expect(model.slots.isEmpty && !model.canUndo)
        #expect(await arranging.library.receivedCalls.last == .discardPicturesNoLongerHeld(first.id))
    }

    @Test func aWallpaperShownAgainBeforeItOpenedStillHasItsLeftoverPicturesDiscardedBeforeItOpens() async throws {
        let arranging = Arranging()
        let first = try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let second = try await arranging.store([.night: arranging.picture()], named: "Winter")
        let model = arranging.model
        let sentLater = SentLater()
        await arranging.library.beforeAnswering(.discardPicturesNoLongerHeld) { @MainActor in
            await sentLater.send([{ await model.show(second.id) }])
        }
        await model.show(second.id)
        await sentLater.waitUntilCarriedOut()
        #expect(model.phase == .open && model.wallpaperID == second.id && !model.canUndo)
        let calls = await arranging.library.receivedCalls
        let discarded = try #require(calls.firstIndex(of: .discardPicturesNoLongerHeld(second.id)))
        let opened = try #require(calls.firstIndex(of: .wallpaper(second.id)))
        #expect(discarded < opened)
        #expect(calls.contains(.discardPicturesNoLongerHeld(first.id)))
    }

    @Test func showingAnotherWallpaperClearsTheQuestionAndTheFailureAndShowingNoneFinishesArranging() async throws {
        let arranging = Arranging()
        try await arranging.open([.dawn: arranging.picture(), .dusk: arranging.picture()])
        let second = try await arranging.store([.night: arranging.picture()], named: "Winter")
        let model = arranging.model
        await arranging.library.fail(.keep, with: .noSpaceLeft)
        await model.movePicture(from: .dawn, to: .midday)
        model.askToPlaceByTimeAgain()
        try #require(model.arrangingFailure == .couldNotSave && model.isAskingToPlaceByTimeAgain)
        await model.show(second.id)
        #expect(model.arrangingFailure == nil && !model.isAskingToPlaceByTimeAgain)
        await model.show(nil)
        #expect(model.phase == .nothingOpen)
        #expect(await arranging.library.receivedCalls.last == .discardPicturesNoLongerHeld(second.id))
    }
}

@MainActor
private final class SentLater {
    private var actions: [Task<Void, Never>]?

    func send(_ laterActions: [@MainActor () async -> Void]) async {
        guard actions == nil else { return }

        actions = laterActions.map { laterAction in Task { @MainActor in await laterAction() } }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    func waitUntilCarriedOut() async {
        for action in actions ?? [] {
            await action.value
        }
    }
}
