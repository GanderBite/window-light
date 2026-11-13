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

private func takenAt(_ hour: Int, _ minute: Int, onDay day: Int = 21) throws -> Picture {
    try picture(captureTime: CaptureTime(year: 2026, month: 6, day: day, hour: hour, minute: minute, second: 0))
}

private func withoutCaptureTime(_ count: Int) throws -> [Picture] {
    try (0 ..< count).map { _ in try picture() }
}

private func slotsInANewWallpaper(of newPictures: [Picture]) throws -> [Slot] {
    try Wallpaper.automaticPlacementInNewWallpaper(of: newPictures).map(\.slot)
}

private func slots(of newPictures: [Picture], in wallpaper: Wallpaper) throws -> [Slot] {
    try wallpaper.automaticPlacement(of: newPictures).map(\.slot)
}

private func mixedPictures(count: Int, withCaptureTimeWhere hasCaptureTime: (Int) -> Bool) throws -> [Picture] {
    try (0 ..< count).map { index in
        try hasCaptureTime(index) ? takenAt((index * 7 + 5) % 24, (index * 13) % 60) : picture()
    }
}

private func expectEachPictureGetsOneDistinctEmptySlotInTheOrderGiven(
    _ placement: [PlacedPicture],
    for newPictures: [Picture],
    emptySlots: [Slot],
) {
    #expect(placement.map(\.picture) == newPictures)
    #expect(Set(placement.map(\.slot)).count == newPictures.count)
    #expect(Set(placement.map(\.slot)).isSubset(of: emptySlots))
}

private func combinations(of size: Int, from slots: ArraySlice<Slot> = ArraySlice(Slot.allCases)) -> [[Slot]] {
    guard size > 0 else { return [[]] }
    guard let first = slots.first else { return [] }

    let rest = slots.dropFirst()
    return combinations(of: size - 1, from: rest).map { [first] + $0 } + combinations(of: size, from: rest)
}

struct AutomaticPlacementTests {
    @Test func picturesTakenAtSixFiftyNineAndSevenThirtyGoToSunriseAndMorning() throws {
        let placed = try slotsInANewWallpaper(of: [takenAt(6, 59), takenAt(7, 30)])

        #expect(placed == [.sunrise, .morning])
    }

    @Test func picturesWithTheSameClockTimesOnDifferentDatesGetTheSameSlots() throws {
        let times = [(9, 0), (9, 20), (23, 30), (1, 30), (12, 0)]
        let firstSet = try times.map { try takenAt($0.0, $0.1, onDay: 1) }
        let secondSet = try times.map { try takenAt($0.0, $0.1, onDay: 28) }

        #expect(try slotsInANewWallpaper(of: firstSet) == slotsInANewWallpaper(of: secondSet))
    }

    @Test(arguments: 2 ... 8)
    func everyMixOfPicturesInANewWallpaperGetsOneSlotEachInTheOrderGiven(count: Int) throws {
        for mix in 0 ..< (1 << count) {
            let newPictures = try mixedPictures(count: count) { mix & (1 << $0) != 0 }

            let placement = try Wallpaper.automaticPlacementInNewWallpaper(of: newPictures)

            expectEachPictureGetsOneDistinctEmptySlotInTheOrderGiven(
                placement,
                for: newPictures,
                emptySlots: Slot.allCases,
            )
        }
    }

    @Test func placementNamesOnlyEmptySlotsAndPlacingItKeepsEveryFilledSlotsPicture() throws {
        var wallpaper = try wallpaper(filling: [.morning, .midday, .night])
        let picturesBefore = Slot.allCases.map { wallpaper.picture(in: $0) }
        let newPictures = try [takenAt(12, 0), takenAt(9, 0), picture(), takenAt(22, 0), picture()]

        let placement = try wallpaper.automaticPlacement(of: newPictures)

        #expect(Set(placement.map(\.slot)).isSubset(of: wallpaper.emptySlots))
        for placed in placement {
            try wallpaper.place(placed.picture, in: placed.slot)
        }
        for (slot, before) in zip(Slot.allCases, picturesBefore) where before != nil {
            #expect(wallpaper.picture(in: slot) == before)
        }
        #expect(wallpaper.filledSlotCount == 8)
    }

    @Test(arguments: 1 ... 6)
    func newPicturesInAPartlyFilledWallpaperEachGetOneDistinctEmptySlot(filledCount: Int) throws {
        for filledSlots in combinations(of: filledCount) {
            let wallpaper = try wallpaper(filling: filledSlots)
            let emptySlots = wallpaper.emptySlots
            for count in 1 ... emptySlots.count {
                let mixes: [(Int) -> Bool] = [{ _ in true }, { _ in false }, { $0.isMultiple(of: 2) }]
                for hasCaptureTime in mixes {
                    let newPictures = try mixedPictures(count: count, withCaptureTimeWhere: hasCaptureTime)

                    let placement = try wallpaper.automaticPlacement(of: newPictures)

                    expectEachPictureGetsOneDistinctEmptySlotInTheOrderGiven(
                        placement,
                        for: newPictures,
                        emptySlots: emptySlots,
                    )
                }
            }
        }
    }

    @Test func ofPicturesMatchingMiddayTheOneClosestToItsMiddleGetsIt() throws {
        let placed = try slotsInANewWallpaper(of: [takenAt(12, 0), takenAt(12, 25), takenAt(14, 0)])

        #expect(placed[1] == .midday)
    }

    @Test func ofTwoPicturesEquallyCloseToNightsMiddleTheOneEarlierInItsRangeGetsIt() throws {
        let beforeMidnight = try takenAt(23, 30)
        let afterMidnight = try takenAt(1, 30)

        let lateFirst = try Wallpaper.automaticPlacementInNewWallpaper(of: [beforeMidnight, afterMidnight])
        let earlyFirst = try Wallpaper.automaticPlacementInNewWallpaper(of: [afterMidnight, beforeMidnight])

        #expect(lateFirst.first { $0.slot == .night }?.picture == beforeMidnight)
        #expect(earlyFirst.first { $0.slot == .night }?.picture == beforeMidnight)
    }

    @Test func ofTwoPicturesEquallyCloseToMiddaysMiddleTheEarlierOneGetsIt() throws {
        let before = try takenAt(11, 30)
        let after = try takenAt(13, 30)

        let placement = try Wallpaper.automaticPlacementInNewWallpaper(of: [after, before])

        #expect(placement.first { $0.slot == .midday }?.picture == before)
    }

    @Test func ofTwoPicturesWithTheSameClockTimeTheOneGivenFirstGetsTheSlot() throws {
        let givenFirst = try takenAt(12, 0, onDay: 28)
        let givenSecond = try takenAt(12, 0, onDay: 1)

        let placed = try slotsInANewWallpaper(of: [givenFirst, givenSecond])

        #expect(placed == [.midday, .afternoon])
    }

    @Test func aPictureWhoseMatchingSlotIsFilledGoesToTheLaterOfTheTwoNearestEmptySlots() throws {
        let wallpaper = try wallpaper(filling: [.midday])

        #expect(try slots(of: [takenAt(12, 0)], in: wallpaper) == [.afternoon])
    }

    @Test func aPictureWhoseMatchingSlotIsFilledGoesToTheOnlyNearestEmptySide() throws {
        let wallpaper = try wallpaper(filling: [.midday, .afternoon])

        #expect(try slots(of: [takenAt(12, 0)], in: wallpaper) == [.morning])
    }

    @Test func ofTwoPicturesThatMissMiddayTheEarlierClockTimeChoosesFirst() throws {
        let wallpaper = try wallpaper(filling: [.midday])
        let earlier = try takenAt(11, 0)
        let later = try takenAt(13, 0)

        #expect(try slots(of: [earlier, later], in: wallpaper) == [.afternoon, .morning])
        #expect(try slots(of: [later, earlier], in: wallpaper) == [.morning, .afternoon])
    }

    @Test func ofTwoPicturesThatMissMiddayAtTheSameClockTimeTheOneGivenFirstChoosesFirst() throws {
        let wallpaper = try wallpaper(filling: [.midday])

        #expect(try slots(of: [takenAt(12, 0, onDay: 28), takenAt(12, 0, onDay: 1)], in: wallpaper)
            == [.afternoon, .morning])
    }

    @Test func picturesThatMissNightChooseInTheOrderOfTheDayFromFiveOverMidnight() throws {
        let wallpaper = try wallpaper(filling: [.night])
        let lateEvening = try takenAt(23, 0)
        let afterMidnight = try takenAt(1, 0)

        #expect(try slots(of: [lateEvening, afterMidnight], in: wallpaper) == [.dusk, .dawn])
        #expect(try slots(of: [afterMidnight, lateEvening], in: wallpaper) == [.dawn, .dusk])
    }

    @Test func onePictureWithoutACaptureTimeInANewWallpaperGoesToMidday() throws {
        #expect(try slotsInANewWallpaper(of: withoutCaptureTime(1)) == [.midday])
    }

    @Test func threePicturesWithoutACaptureTimePickMiddayNightAndSunriseAndFillThemInTheOrderOfTheDay() throws {
        #expect(try slotsInANewWallpaper(of: withoutCaptureTime(3)) == [.sunrise, .midday, .night])
    }

    @Test func aPictureWithoutACaptureTimeGoesFarthestFromASlotFilledBeforeTheImport() throws {
        let wallpaper = try wallpaper(filling: [.morning])

        #expect(try slots(of: withoutCaptureTime(1), in: wallpaper) == [.dusk])
    }

    @Test func aPictureWithoutACaptureTimeGoesFarthestFromASlotTakenByAPictureWithACaptureTime() throws {
        let placed = try slotsInANewWallpaper(of: [picture(), takenAt(9, 0)])

        #expect(placed == [.dusk, .morning])
    }

    @Test func fourPicturesThroughTheAfternoonAndEveningFillMiddaySunsetDuskAndNight() throws {
        let placed = try slotsInANewWallpaper(of: [takenAt(12, 10), takenAt(17, 50), takenAt(19, 20), takenAt(23, 40)])

        #expect(placed == [.midday, .sunset, .dusk, .night])
    }

    @Test func picturesAtNineAndNineTwentyFillMorningAndThenTheLaterNearestSlotMidday() throws {
        let placed = try slotsInANewWallpaper(of: [takenAt(9, 0), takenAt(9, 20)])

        #expect(placed == [.morning, .midday])
    }

    @Test func eightPicturesTakenAroundNoonSpreadFromMiddayOutwards() throws {
        let newPictures = try (0 ... 7).map { try takenAt(12, $0) }

        let placed = try slotsInANewWallpaper(of: newPictures)

        #expect(placed == [.afternoon, .morning, .sunset, .sunrise, .dusk, .dawn, .night, .midday])
    }

    @Test func eightPicturesWithoutACaptureTimeFillDawnToNightInTheOrderGiven() throws {
        #expect(try slotsInANewWallpaper(of: withoutCaptureTime(8)) == Slot.allCases)
    }

    @Test func twoPicturesWithoutACaptureTimeFillMiddayAndNight() throws {
        #expect(try slotsInANewWallpaper(of: withoutCaptureTime(2)) == [.midday, .night])
    }

    @Test func placingTheSamePicturesTwiceInTwoEmptyWallpapersGivesTheSameResult() throws {
        let newPictures = try [takenAt(12, 0), picture(), takenAt(12, 5), takenAt(23, 30), picture(), takenAt(1, 30)]

        let first = try Wallpaper.automaticPlacementInNewWallpaper(of: newPictures)
        let second = try Wallpaper.automaticPlacementInNewWallpaper(of: newPictures)

        #expect(first == second)
    }

    @Test func automaticPlacementWithCaptureTimesChangesNothing() throws {
        let wallpaper = try wallpaper(filling: [.midday])
        let before = wallpaper

        _ = try wallpaper.automaticPlacement(of: [takenAt(12, 0), picture()])

        #expect(wallpaper == before)
    }

    @Test func aPictureTakenAtNoonPlacedInDawnByNameStaysInDawn() throws {
        var wallpaper = try wallpaper(filling: [.night])
        let noon = try takenAt(12, 0)

        try wallpaper.place(noon, in: .dawn)

        #expect(wallpaper.picture(in: .dawn) == noon)
    }
}
