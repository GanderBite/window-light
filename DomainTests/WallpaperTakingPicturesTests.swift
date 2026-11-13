@testable import Domain
import Foundation
import Testing

private func picture(
    origin: PictureOrigin = .imported,
    captureTime: CaptureTime? = nil,
    fingerprint text: String? = nil,
) throws -> Picture {
    let id = PictureID(UUID())
    return try Picture(
        id: id,
        origin: origin,
        captureTime: captureTime,
        fingerprint: ContentFingerprint(text ?? "fingerprint \(id.value.uuidString)"),
    )
}

private func wallpaper(pictures: [Slot: Picture]) throws -> Wallpaper {
    try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
}

private func wallpaper(filling slots: [Slot]) throws -> Wallpaper {
    try wallpaper(pictures: Dictionary(uniqueKeysWithValues: slots.map { try ($0, picture()) }))
}

private func pictures(_ count: Int) throws -> [Picture] {
    try (0 ..< count).map { _ in try picture() }
}

private func slotsHoldingPictures(of wallpaper: Wallpaper) -> [Slot: Picture] {
    Dictionary(uniqueKeysWithValues: Slot.allCases.compactMap { slot in
        wallpaper.picture(in: slot).map { (slot, $0) }
    })
}

struct WallpaperTakingPicturesTests {
    @Test(arguments: [2, 8])
    func aNewWallpaperCanBeCreatedFromTwoToEightFiles(count: Int) throws {
        try Wallpaper.checkCanBeCreated(fromFileCount: count)
    }

    @Test(arguments: [0, 1])
    func aNewWallpaperFromFewerThanTwoFilesIsRefused(count: Int) {
        #expect(throws: WallpaperError.tooFewFilesToCreate(fewest: 2)) {
            try Wallpaper.checkCanBeCreated(fromFileCount: count)
        }
    }

    @Test func aNewWallpaperFromNineFilesIsRefused() {
        #expect(throws: WallpaperError.tooManyFilesToCreate(most: 8)) {
            try Wallpaper.checkCanBeCreated(fromFileCount: 9)
        }
    }

    @Test func aWallpaperWithThreeEmptySlotsTakesThreeFilesAndRefusesFour() throws {
        let wallpaper = try wallpaper(filling: [.dawn, .sunrise, .morning, .midday, .afternoon])
        try wallpaper.checkCanTake(fileCount: 3)
        #expect(throws: WallpaperError.moreFilesThanEmptySlots(emptySlots: 3)) {
            try wallpaper.checkCanTake(fileCount: 4)
        }
    }

    @Test func aWallpaperWithEightPicturesHasNoEmptySlotForOneFile() throws {
        let wallpaper = try wallpaper(filling: Slot.allCases)
        #expect(throws: WallpaperError.noEmptySlot) {
            try wallpaper.checkCanTake(fileCount: 1)
        }
    }

    @Test func theEmptySlotsComeInTheOrderOfTheDay() throws {
        let wallpaper = try wallpaper(filling: [.dusk, .dawn])
        #expect(wallpaper.emptySlots == [.sunrise, .morning, .midday, .afternoon, .sunset, .night])
    }

    @Test func aWallpaperIsReadyToApplyFromTwoPictures() throws {
        #expect(try !wallpaper(filling: [.dawn]).isReadyToApply)
        #expect(try wallpaper(filling: [.dawn, .night]).isReadyToApply)
    }

    @Test func aPicturePlacedInAnEmptySlotStaysThereWhateverItsCaptureTime() throws {
        var wallpaper = try wallpaper(filling: [.night])
        let lateEvening = try CaptureTime(year: 2026, month: 6, day: 21, hour: 23, minute: 0, second: 0)
        let newPicture = try picture(captureTime: lateEvening)

        let discarded = try wallpaper.place(newPicture, in: .dawn)

        #expect(discarded == nil)
        #expect(wallpaper.picture(in: .dawn) == newPicture)
    }

    @Test func aRealPicturePlacedOverAPictureMadeWithAITakesTheSlotAndGivesTheAIPictureBack() throws {
        let madeWithAI = try picture(origin: .madeWithAI)
        var wallpaper = try wallpaper(pictures: [.dawn: madeWithAI])
        let real = try picture()

        #expect(wallpaper.canTakeAFile(into: .dawn))
        let discarded = try wallpaper.place(real, in: .dawn)

        #expect(discarded == madeWithAI)
        #expect(wallpaper.picture(in: .dawn) == real)
    }

    @Test func aSlotWithARealPictureRefusesANewPictureAndTheWallpaperStaysAsItWas() throws {
        var wallpaper = try wallpaper(filling: [.dawn])
        let before = wallpaper

        #expect(throws: WallpaperError.slotHoldsRealPicture(.dawn)) {
            try wallpaper.place(picture(), in: .dawn)
        }
        #expect(!wallpaper.canTakeAFile(into: .dawn))
        #expect(throws: WallpaperError.slotHoldsRealPicture(.dawn)) {
            try wallpaper.checkCanTakeAFile(into: .dawn)
        }
        #expect(wallpaper == before)
    }

    @Test func anEmptySlotCanTakeAFile() throws {
        let wallpaper = try wallpaper(filling: [.dawn])
        #expect(wallpaper.canTakeAFile(into: .night))
        try wallpaper.checkCanTakeAFile(into: .night)
    }

    @Test func aPictureIdenticalToOneInAnotherSlotIsRefusedAndTheWallpaperStaysAsItWas() throws {
        let held = try picture(fingerprint: "same content")
        var wallpaper = try wallpaper(pictures: [.dawn: held])
        let before = wallpaper

        #expect(throws: WallpaperError.identicalPictureAlreadyInWallpaper(held.fingerprint)) {
            try wallpaper.place(picture(fingerprint: "same content"), in: .night)
        }
        #expect(wallpaper == before)
    }

    @Test func aWallpaperKnowsWhetherItHoldsAPictureWithAFingerprint() throws {
        let held = try picture()
        let wallpaper = try wallpaper(pictures: [.dawn: held])
        #expect(wallpaper.holdsPicture(identicalTo: held.fingerprint))
        #expect(try !wallpaper.holdsPicture(identicalTo: ContentFingerprint("other content")))
    }

    @Test func aPictureAlreadyInTheWallpaperIsRefusedInAnotherSlot() throws {
        let held = try picture()
        var wallpaper = try wallpaper(pictures: [.dawn: held])
        let before = wallpaper

        #expect(throws: WallpaperError.pictureInTwoSlots(held.id)) {
            try wallpaper.place(held, in: .night)
        }
        #expect(wallpaper == before)
    }

    @Test func threePicturesWithoutACaptureTimeInANewWallpaperGoToSunriseMiddayAndNightInTheOrderGiven() throws {
        let newPictures = try pictures(3)

        let placement = try Wallpaper.automaticPlacementInNewWallpaper(of: newPictures)

        #expect(placement.map(\.picture) == newPictures)
        #expect(placement.map(\.slot) == [.sunrise, .midday, .night])
    }

    @Test func threePicturesWithoutACaptureTimeGoFarthestFromTheFilledSlotsInTheOrderOfTheDay() throws {
        let wallpaper = try wallpaper(filling: [.dawn, .morning])
        let newPictures = try pictures(3)

        let placement = try wallpaper.automaticPlacement(of: newPictures)

        #expect(placement.map(\.picture) == newPictures)
        #expect(placement.map(\.slot) == [.midday, .sunset, .night])
    }

    @Test func automaticPlacementNeverNamesAFilledSlotAndKeepsEveryPictureInItsSlot() throws {
        var wallpaper = try wallpaper(filling: [.sunrise, .midday, .dusk])
        let picturesBefore = slotsHoldingPictures(of: wallpaper)

        let placement = try wallpaper.automaticPlacement(of: pictures(5))

        #expect(Set(placement.map(\.slot)).isDisjoint(with: picturesBefore.keys))
        for placed in placement {
            try wallpaper.place(placed.picture, in: placed.slot)
        }
        for (slot, picture) in picturesBefore {
            #expect(wallpaper.picture(in: slot) == picture)
        }
        #expect(wallpaper.filledSlotCount == 8)
    }

    @Test func automaticPlacementChangesNothing() throws {
        let wallpaper = try wallpaper(filling: [.dawn])
        let before = wallpaper

        _ = try wallpaper.automaticPlacement(of: pictures(2))

        #expect(wallpaper == before)
    }

    @Test func automaticPlacementOfMorePicturesThanEmptySlotsIsRefused() throws {
        let wallpaper = try wallpaper(filling: [.dawn, .sunrise, .morning, .midday, .afternoon])
        let fourPictures = try pictures(4)
        let ninePictures = try pictures(9)

        #expect(throws: WallpaperError.moreFilesThanEmptySlots(emptySlots: 3)) {
            try wallpaper.automaticPlacement(of: fourPictures)
        }
        #expect(throws: WallpaperError.moreFilesThanEmptySlots(emptySlots: 8)) {
            try Wallpaper.automaticPlacementInNewWallpaper(of: ninePictures)
        }
    }

    @Test func automaticPlacementIntoAFullWallpaperFindsNoEmptySlot() throws {
        let wallpaper = try wallpaper(filling: Slot.allCases)
        let onePicture = try pictures(1)
        #expect(throws: WallpaperError.noEmptySlot) {
            try wallpaper.automaticPlacement(of: onePicture)
        }
    }

    @Test func anySequenceOfPlacingKeepsAtMostEightPicturesAndCountsThemRight() throws {
        var wallpaper = try wallpaper(pictures: [.midday: picture(origin: .madeWithAI)])
        let candidates = try (0 ..< 24).map { index in
            try picture(
                origin: index.isMultiple(of: 3) ? .madeWithAI : .imported,
                fingerprint: "content \(index % 10)",
            )
        }
        var placedCount = 0
        var refusedCount = 0
        for (index, candidate) in candidates.enumerated() {
            for slot in [Slot.allCases[index % 8], Slot.allCases[(index * 5) % 8]] {
                do throws(WallpaperError) {
                    try wallpaper.place(candidate, in: slot)
                    placedCount += 1
                } catch {
                    refusedCount += 1
                }
                let filledSlots = Slot.allCases.count { wallpaper.picture(in: $0) != nil }
                #expect(wallpaper.filledSlotCount <= Wallpaper.mostPictures)
                #expect(wallpaper.filledSlotCount == filledSlots)
            }
        }
        #expect(placedCount > 0)
        #expect(refusedCount > 0)
    }

    @Test func aWallpaperHoldsAtMostAsManyPicturesAsThereAreSlots() {
        #expect(Wallpaper.mostPictures == 8)
        #expect(Wallpaper.fewestPicturesToApply == 2)
        #expect(Wallpaper.fewestFilesToCreate == 2)
    }
}
