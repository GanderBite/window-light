import Application
import Domain
@testable import Features
import Foundation
import Testing

@MainActor
private final class UndoingArrangement {
    let library = WallpaperLibraryStandIn()
    let undoManager = UndoManager()

    lazy var model = WallpaperModel(
        openWallpaper: OpenWallpaper(library: library),
        arrangePictures: ArrangePictures(library: library),
        finishArranging: FinishArranging(library: library),
    )

    lazy var arrangingUndo = ArrangingUndo(model: model)

    init() {
        undoManager.groupsByEvent = false
    }

    var filledSlots: [Slot] {
        model.slots.filter(\.isFilled).map(\.slot)
    }

    func open(_ slots: [Slot]) async throws {
        var picturesBySlot: [Slot: Picture] = [:]
        for slot in slots {
            picturesBySlot[slot] = try Picture(
                id: PictureID(UUID()),
                origin: .imported,
                captureTime: nil,
                fingerprint: ContentFingerprint(UUID().uuidString),
            )
        }
        let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Summer"), pictures: picturesBySlot)
        var contents: [PictureID: Data] = [:]
        for held in wallpaper.picturesInDayOrder {
            contents[held.id] = Data("content \(held.id)".utf8)
        }
        try await library.add(wallpaper, pictureContents: contents, picturePreviews: contents)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
    }

    func reportStepCount(from oldCount: Int) {
        undoManager.beginUndoGrouping()
        arrangingUndo.stepCountChanged(from: oldCount, to: model.newStepCount, in: undoManager)
        undoManager.endUndoGrouping()
    }

    func untilTheModelHasFinished(_ isFinished: () -> Bool) async throws {
        let yieldsTheModelNeedsAtMost = 10000
        for _ in 0 ..< yieldsTheModelNeedsAtMost where !isFinished() {
            await Task.yield()
        }
        try #require(isFinished())
    }
}

@MainActor
struct ArrangingUndoTests {
    @Test func aNewStepCanBeUndoneUnderTheNameOfThatStep() async throws {
        let arranging = UndoingArrangement()
        try await arranging.open([.dawn, .midday])
        await arranging.model.movePicture(from: .dawn, to: .sunrise)
        arranging.reportStepCount(from: 0)
        #expect(arranging.undoManager.canUndo)
        #expect(
            arranging.undoManager.undoActionName
                == ArrangingWording.undoActionName(of: .moved(from: .dawn, to: .sunrise), from: .module),
        )
    }

    @Test func undoBringsTheSlotsBackAndRedoBringsTheStepBack() async throws {
        let arranging = UndoingArrangement()
        try await arranging.open([.dawn, .midday])
        let slotsBefore = arranging.filledSlots
        await arranging.model.removePicture(from: .dawn)
        let slotsAfterTheStep = arranging.filledSlots
        arranging.reportStepCount(from: 0)
        let removalName = ArrangingWording.undoActionName(of: .removed(from: .dawn), from: .module)

        arranging.undoManager.undo()
        try await arranging.untilTheModelHasFinished { arranging.model.lastStep == .undone }
        #expect(arranging.filledSlots == slotsBefore)
        #expect(arranging.undoManager.canRedo)
        #expect(arranging.undoManager.redoActionName == removalName)

        arranging.undoManager.redo()
        try await arranging.untilTheModelHasFinished { arranging.model.lastStep == .redone }
        #expect(arranging.filledSlots == slotsAfterTheStep)
        #expect(arranging.undoManager.canUndo)
        #expect(arranging.undoManager.undoActionName == removalName)
    }

    @Test func aStepCountBackAtZeroLeavesNothingToUndoOrRedo() async throws {
        let arranging = UndoingArrangement()
        try await arranging.open([.dawn, .midday])
        await arranging.model.movePicture(from: .dawn, to: .sunrise)
        arranging.reportStepCount(from: 0)
        await arranging.model.removePicture(from: .midday)
        arranging.reportStepCount(from: 1)
        arranging.undoManager.undo()
        try await arranging.untilTheModelHasFinished { arranging.model.lastStep == .undone }
        #expect(arranging.undoManager.canUndo && arranging.undoManager.canRedo)

        arranging.arrangingUndo.stepCountChanged(from: 2, to: 0, in: arranging.undoManager)
        #expect(!arranging.undoManager.canUndo)
        #expect(!arranging.undoManager.canRedo)
    }

    @Test func aStepCountChangeWithoutAnUndoManagerLeavesTheArrangementAsItIs() async throws {
        let arranging = UndoingArrangement()
        try await arranging.open([.dawn, .midday])
        await arranging.model.movePicture(from: .dawn, to: .sunrise)
        let slotsAfterTheStep = arranging.filledSlots
        arranging.arrangingUndo.stepCountChanged(from: 0, to: 1, in: nil)
        arranging.arrangingUndo.stepCountChanged(from: 1, to: 0, in: nil)
        await Task.yield()
        #expect(arranging.filledSlots == slotsAfterTheStep)
        #expect(arranging.model.lastStep == .moved(from: .dawn, to: .sunrise))
    }
}
