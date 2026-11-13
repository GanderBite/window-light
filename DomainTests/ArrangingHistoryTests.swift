@testable import Domain
import Foundation
import Testing

private func picture(origin: PictureOrigin = .imported) throws -> Picture {
    let id = PictureID(UUID())
    return try Picture(
        id: id,
        origin: origin,
        captureTime: nil,
        fingerprint: ContentFingerprint("fingerprint \(id.value.uuidString)"),
    )
}

private func wallpaper(pictures: [Slot: Picture]) throws -> Wallpaper {
    try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
}

private func wallpaper(filling slots: [Slot]) throws -> Wallpaper {
    try wallpaper(pictures: Dictionary(uniqueKeysWithValues: slots.map { try ($0, picture()) }))
}

private struct ThreeSteps {
    let start: Arrangement
    let afterFirst: Arrangement
    let afterSecond: Arrangement
    let afterThird: Arrangement

    var history: ArrangingHistory {
        var history = ArrangingHistory(startingFrom: start)
        history.record(afterFirst)
        history.record(afterSecond)
        history.record(afterThird)
        return history
    }

    init() throws {
        var wallpaper = try wallpaper(filling: [.dawn, .midday, .dusk])
        start = wallpaper.arrangement
        try wallpaper.movePicture(from: .dawn, to: .sunrise)
        afterFirst = wallpaper.arrangement
        try wallpaper.movePicture(from: .midday, to: .dusk)
        afterSecond = wallpaper.arrangement
        wallpaper.removePicture(from: .sunrise)
        afterThird = wallpaper.arrangement
    }
}

struct ArrangingHistoryTests {
    @Test func theArrangementOfAWallpaperHoldsThePictureOfEachOfItsEightSlots() throws {
        let wallpaper = try wallpaper(pictures: [
            .dawn: picture(),
            .midday: picture(origin: .madeWithAI),
            .night: picture(),
        ])

        #expect(Slot.allCases.count == 8)
        for slot in Slot.allCases {
            #expect(wallpaper.arrangement.picture(in: slot) == wallpaper.picture(in: slot))
        }
    }

    @Test func rearrangingAsAnEarlierArrangementUndoesMovingSwappingAndRemoving() throws {
        var wallpaper = try wallpaper(filling: [.dawn, .morning, .midday, .dusk])
        let before = wallpaper
        let earlierArrangement = wallpaper.arrangement

        try wallpaper.movePicture(from: .dawn, to: .sunrise)
        try wallpaper.movePicture(from: .morning, to: .midday)
        let removed = wallpaper.removePicture(from: .dusk)
        #expect(removed != nil)
        #expect(wallpaper != before)

        wallpaper.rearrange(as: earlierArrangement)

        #expect(wallpaper == before)
        #expect(wallpaper.picture(in: .dusk) == removed)
    }

    @Test func rearrangingBringsBackAPictureMadeWithAIThatARealPictureReplaced() throws {
        let madeWithAI = try picture(origin: .madeWithAI)
        var wallpaper = try wallpaper(pictures: [.dawn: picture(), .sunset: madeWithAI])
        let earlierArrangement = wallpaper.arrangement

        let replaced = try wallpaper.place(picture(), in: .sunset)
        #expect(replaced == madeWithAI)

        wallpaper.rearrange(as: earlierArrangement)

        #expect(wallpaper.picture(in: .sunset) == madeWithAI)
    }

    @Test func rearrangingLeavesTheNameAndTheIDOfTheWallpaperUnchanged() throws {
        let other = try wallpaper(filling: [.morning, .night])
        var wallpaper = try Wallpaper(
            id: WallpaperID(UUID()),
            name: WallpaperName("Mountains"),
            pictures: [.dawn: picture(), .dusk: picture()],
        )
        let id = wallpaper.id
        let name = wallpaper.name

        wallpaper.rearrange(as: other.arrangement)

        #expect(wallpaper.id == id)
        #expect(wallpaper.name == name)
        #expect(wallpaper.arrangement == other.arrangement)
    }

    @Test func rearrangingAfterPlacingRealPicturesByTimeAgainPutsThemBack() throws {
        var wallpaper = try wallpaper(filling: [.night, .dawn])
        let before = wallpaper

        wallpaper.placeRealPicturesByTimeAgain()
        wallpaper.rearrange(as: before.arrangement)

        #expect(wallpaper == before)
    }

    @Test func aNewHistoryCannotUndoOrRedoAndStartsFromItsArrangement() throws {
        let start = try wallpaper(filling: [.dawn, .dusk]).arrangement

        let history = ArrangingHistory(startingFrom: start)

        #expect(!history.canUndo)
        #expect(!history.canRedo)
        #expect(history.current == start)
    }

    @Test func undoingThreeStepsWalksBackAndRedoingThemWalksForwardInOrder() throws {
        let steps = try ThreeSteps()
        var history = steps.history
        #expect(history.current == steps.afterThird)

        #expect(history.undo() == steps.afterSecond)
        #expect(history.undo() == steps.afterFirst)
        #expect(history.undo() == steps.start)
        #expect(history.current == steps.start)
        #expect(!history.canUndo)
        #expect(history.canRedo)

        #expect(history.redo() == steps.afterFirst)
        #expect(history.redo() == steps.afterSecond)
        #expect(history.redo() == steps.afterThird)
        #expect(history.current == steps.afterThird)
        #expect(!history.canRedo)
        #expect(history.canUndo)
    }

    @Test func undoingOrRedoingWithNothingToDoReturnsNothingAndChangesNothing() throws {
        let steps = try ThreeSteps()
        var fresh = ArrangingHistory(startingFrom: steps.start)
        let freshBefore = fresh

        #expect(fresh.undo() == nil)
        #expect(fresh.redo() == nil)
        #expect(fresh == freshBefore)

        var recorded = steps.history
        let recordedBefore = recorded
        #expect(recorded.redo() == nil)
        #expect(recorded == recordedBefore)

        recorded.undo()
        recorded.undo()
        recorded.undo()
        let fullyUndone = recorded
        #expect(recorded.undo() == nil)
        #expect(recorded == fullyUndone)
    }

    @Test func recordingAfterAnUndoForgetsTheUndoneStep() throws {
        let steps = try ThreeSteps()
        var history = steps.history
        history.undo()
        #expect(history.canRedo)

        var wallpaper = try wallpaper(filling: [.morning])
        wallpaper.rearrange(as: steps.afterSecond)
        try wallpaper.movePicture(from: .dusk, to: .night)
        let newStep = wallpaper.arrangement
        history.record(newStep)

        #expect(!history.canRedo)
        #expect(history.redo() == nil)
        #expect(history.current == newStep)
        #expect(history.undo() == steps.afterSecond)
    }

    @Test func recordingTheCurrentArrangementAgainAddsNoStep() throws {
        let steps = try ThreeSteps()
        var fresh = ArrangingHistory(startingFrom: steps.start)

        fresh.record(steps.start)

        #expect(!fresh.canUndo)
        #expect(fresh == ArrangingHistory(startingFrom: steps.start))

        var recorded = steps.history
        let before = recorded
        recorded.record(steps.afterThird)

        #expect(recorded.canUndo == before.canUndo)
        #expect(recorded == before)
        recorded.undo()
        recorded.undo()
        recorded.undo()
        #expect(!recorded.canUndo)
    }
}
