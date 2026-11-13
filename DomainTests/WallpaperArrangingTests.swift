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

private func slotsHoldingPictures(of wallpaper: Wallpaper) -> [Slot: Picture] {
    Dictionary(uniqueKeysWithValues: Slot.allCases.compactMap { slot in
        wallpaper.picture(in: slot).map { (slot, $0) }
    })
}

private func expectStandInsFollowTheRuleForTheArrangementOf(_ arranged: Wallpaper) throws {
    let freshlyBuilt = try wallpaper(pictures: slotsHoldingPictures(of: arranged))
    for slot in arranged.emptySlots {
        #expect(arranged.standIn(for: slot) == freshlyBuilt.standIn(for: slot))
    }
}

struct MoveSequence: CustomTestStringConvertible {
    let filledSlots: [Slot]
    let moves: [(from: Slot, to: Slot)]

    var testDescription: String {
        "\(filledSlots.count) pictures, \(moves.count) moves"
    }
}

private let moveSequences = [
    MoveSequence(filledSlots: [.morning], moves: [(.morning, .afternoon), (.afternoon, .night), (.night, .dawn)]),
    MoveSequence(
        filledSlots: [.dawn, .midday, .night],
        moves: [(.dawn, .midday), (.midday, .sunset), (.night, .dawn), (.sunset, .sunset), (.dawn, .midday)],
    ),
    MoveSequence(
        filledSlots: Slot.allCases,
        moves: [(.dawn, .night), (.morning, .dusk), (.sunrise, .sunset), (.night, .midday), (.afternoon, .dawn)],
    ),
    MoveSequence(
        filledSlots: [.sunrise, .afternoon],
        moves: [(.sunrise, .afternoon), (.afternoon, .dusk), (.dusk, .sunrise), (.sunrise, .afternoon)],
    ),
]

struct WallpaperArrangingTests {
    @Test func aPictureMovedToAnEmptySlotLeavesItsSlotEmpty() throws {
        let morning = try picture()
        var wallpaper = try wallpaper(pictures: [.morning: morning])

        let discarded = try wallpaper.movePicture(from: .morning, to: .afternoon)

        #expect(discarded == nil)
        #expect(wallpaper.picture(in: .afternoon) == morning)
        #expect(wallpaper.picture(in: .morning) == nil)
    }

    @Test func aPictureMovedToASlotWithARealPictureSwapsWithIt() throws {
        let morning = try picture()
        let sunset = try picture()
        var wallpaper = try wallpaper(pictures: [.morning: morning, .sunset: sunset])

        let discarded = try wallpaper.movePicture(from: .morning, to: .sunset)

        #expect(discarded == nil)
        #expect(wallpaper.picture(in: .sunset) == morning)
        #expect(wallpaper.picture(in: .morning) == sunset)
    }

    @Test(arguments: moveSequences)
    func anySequenceOfMovesKeepsEveryRealPictureInExactlyOneSlot(sequence: MoveSequence) throws {
        var wallpaper = try wallpaper(filling: sequence.filledSlots)
        let picturesBefore = Set(wallpaper.picturesInDayOrder)

        for move in sequence.moves {
            try wallpaper.movePicture(from: move.from, to: move.to)

            let slotsHolding = slotsHoldingPictures(of: wallpaper)
            #expect(Set(slotsHolding.values) == picturesBefore)
            #expect(slotsHolding.count == picturesBefore.count)
        }
    }

    @Test func aRealPictureMovedOverAPictureMadeWithAITakesTheSlotAndGivesTheAIPictureBack() throws {
        let real = try picture()
        let madeWithAI = try picture(origin: .madeWithAI)
        var wallpaper = try wallpaper(pictures: [.dawn: real, .dusk: madeWithAI])

        let discarded = try wallpaper.movePicture(from: .dawn, to: .dusk)

        #expect(discarded == madeWithAI)
        #expect(wallpaper.picture(in: .dusk) == real)
        #expect(wallpaper.picture(in: .dawn) == nil)
        #expect(wallpaper.picturesInDayOrder == [real])
    }

    @Test func aPictureMadeWithAICannotBeMovedAndTheWallpaperStaysAsItWas() throws {
        var wallpaper = try wallpaper(pictures: [.dawn: picture(origin: .madeWithAI), .night: picture()])
        let before = wallpaper

        #expect(throws: WallpaperError.pictureMadeWithAICannotBeMoved(.dawn)) {
            try wallpaper.movePicture(from: .dawn, to: .midday)
        }
        #expect(throws: WallpaperError.pictureMadeWithAICannotBeMoved(.dawn)) {
            try wallpaper.movePicture(from: .dawn, to: .night)
        }
        #expect(wallpaper == before)
    }

    @Test func onlyASlotWithARealPictureCanHaveItsPictureMoved() throws {
        let wallpaper = try wallpaper(pictures: [.dawn: picture(origin: .madeWithAI), .night: picture()])

        #expect(!wallpaper.canMovePicture(from: .dawn))
        #expect(!wallpaper.canMovePicture(from: .midday))
        #expect(wallpaper.canMovePicture(from: .night))
    }

    @Test func movingFromAnEmptySlotIsRefusedAndTheWallpaperStaysAsItWas() throws {
        var wallpaper = try wallpaper(filling: [.dawn])
        let before = wallpaper

        #expect(throws: WallpaperError.noPictureToMove(.midday)) {
            try wallpaper.movePicture(from: .midday, to: .dawn)
        }
        #expect(wallpaper == before)
    }

    @Test func aPictureMovedToItsOwnSlotChangesNothing() throws {
        var wallpaper = try wallpaper(filling: [.dawn, .night])
        let before = wallpaper

        let discarded = try wallpaper.movePicture(from: .dawn, to: .dawn)

        #expect(discarded == nil)
        #expect(wallpaper == before)
    }

    @Test(arguments: [PictureOrigin.imported, .madeWithAI])
    func removingAPictureEmptiesItsSlotAndGivesThePictureBack(origin: PictureOrigin) throws {
        let removed = try picture(origin: origin)
        let kept = try picture()
        var wallpaper = try wallpaper(pictures: [.sunrise: removed, .dusk: kept])

        let given = wallpaper.removePicture(from: .sunrise)

        #expect(given == removed)
        #expect(wallpaper.picture(in: .sunrise) == nil)
        #expect(wallpaper.picturesInDayOrder == [kept])
    }

    @Test func removingFromAnEmptySlotGivesNothingAndChangesNothing() throws {
        var wallpaper = try wallpaper(filling: [.dawn, .night])
        let before = wallpaper

        let given = wallpaper.removePicture(from: .midday)

        #expect(given == nil)
        #expect(wallpaper == before)
    }

    @Test func removingPicturesDownToNoneLeavesAWallpaperThatIsNotReadyToApply() throws {
        var wallpaper = try wallpaper(filling: [.morning, .dusk])

        wallpaper.removePicture(from: .morning)

        #expect(wallpaper.filledSlotCount == 1)
        #expect(!wallpaper.isReadyToApply)

        wallpaper.removePicture(from: .dusk)

        #expect(wallpaper.filledSlotCount == 0)
        #expect(wallpaper.picturesInDayOrder.isEmpty)
        #expect(wallpaper.emptySlots == Slot.allCases)
        #expect(!wallpaper.isReadyToApply)
        for slot in Slot.allCases {
            #expect(wallpaper.standIn(for: slot) == nil)
        }
    }

    @Test func afterAMoveEachEmptySlotBorrowsWhatTheStandInRuleGivesForTheNewArrangement() throws {
        let morning = try picture()
        let night = try picture()
        var wallpaper = try wallpaper(pictures: [.morning: morning, .night: night])

        try wallpaper.movePicture(from: .morning, to: .afternoon)

        #expect(wallpaper.standIn(for: .morning) == PlacedPicture(picture: morning, slot: .afternoon))
        try expectStandInsFollowTheRuleForTheArrangementOf(wallpaper)
    }

    @Test func afterARemovalEachEmptySlotBorrowsWhatTheStandInRuleGivesForTheNewArrangement() throws {
        let sunrise = try picture()
        let sunset = try picture()
        let midday = try picture()
        var wallpaper = try wallpaper(pictures: [.sunrise: sunrise, .sunset: sunset, .midday: midday])

        wallpaper.removePicture(from: .sunset)

        #expect(wallpaper.standIn(for: .sunset) == PlacedPicture(picture: sunrise, slot: .sunrise))
        try expectStandInsFollowTheRuleForTheArrangementOf(wallpaper)
    }
}
