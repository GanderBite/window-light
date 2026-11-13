@testable import Domain
import Foundation
import Testing

private func time(_ hour: Int) throws -> CaptureTime {
    try CaptureTime(year: 2026, month: 6, day: 21, hour: hour, minute: 0, second: 0)
}

private func picture(origin: PictureOrigin = .imported, hour: Int? = nil) throws -> Picture {
    let id = PictureID(UUID())
    return try Picture(
        id: id,
        origin: origin,
        captureTime: hour.map { try time($0) },
        fingerprint: ContentFingerprint("fingerprint \(id.value.uuidString)"),
    )
}

private func wallpaper(pictures: [Slot: Picture]) throws -> Wallpaper {
    try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
}

private func slotsHoldingPictures(of wallpaper: Wallpaper) -> [Slot: Picture] {
    Dictionary(uniqueKeysWithValues: Slot.allCases.compactMap { slot in
        wallpaper.picture(in: slot).map { (slot, $0) }
    })
}

private let setsOfCaptureHours: [[Int?]] = [
    [6, 12, 21],
    [nil, nil, nil],
    [7, nil, 15, nil, 22],
    [12, 12, 12],
    [5, 8, 11, 13, 16, 19, 20, 23],
]

struct WallpaperPlacingByTimeAgainTests {
    @Test(arguments: setsOfCaptureHours)
    func realPicturesMovedByHandAreArrangedAsOnImport(hours: [Int?]) throws {
        let pictures = try hours.map { try picture(hour: $0) }
        let imported = try Wallpaper.automaticPlacementInNewWallpaper(of: pictures)
        var wallpaper =
            try wallpaper(pictures: Dictionary(uniqueKeysWithValues: imported.map { ($0.slot, $0.picture) }))
        let importedSlots = imported.map(\.slot)
        try wallpaper.movePicture(from: importedSlots[0], to: wallpaper.emptySlots.first ?? importedSlots[1])
        let orderedPictures = wallpaper.picturesInDayOrder

        wallpaper.placeRealPicturesByTimeAgain()

        let expected = try Wallpaper.automaticPlacementInNewWallpaper(of: orderedPictures)
        #expect(slotsHoldingPictures(of: wallpaper) == Dictionary(uniqueKeysWithValues: expected.map { (
            $0.slot,
            $0.picture,
        ) }))
    }

    @Test func picturesInTheWrongSlotsReturnToTheSlotsOfTheirCaptureTimes() throws {
        let morning = try picture(hour: 9)
        let evening = try picture(hour: 20)
        var wallpaper = try wallpaper(pictures: [.dawn: evening, .night: morning])

        wallpaper.placeRealPicturesByTimeAgain()

        let expected = try Wallpaper.automaticPlacementInNewWallpaper(of: [evening, morning])
        for placed in expected {
            #expect(wallpaper.picture(in: placed.slot) == placed.picture)
        }
    }

    @Test func aPictureMadeWithAIKeepsItsSlotEvenWhenARealPictureMatchesThatSlot() throws {
        let madeWithAI = try picture(origin: .madeWithAI)
        let atDawn = try picture(hour: 5)
        let atNoon = try picture(hour: 12)
        var wallpaper = try wallpaper(pictures: [.dawn: madeWithAI, .night: atDawn, .sunrise: atNoon])

        wallpaper.placeRealPicturesByTimeAgain()

        #expect(wallpaper.picture(in: .dawn) == madeWithAI)
        let slotOfDawnPicture = Slot.allCases.first { wallpaper.picture(in: $0) == atDawn }
        let slotOfNoonPicture = Slot.allCases.first { wallpaper.picture(in: $0) == atNoon }
        #expect(slotOfDawnPicture != nil)
        #expect(slotOfDawnPicture != .dawn)
        #expect(slotOfNoonPicture != nil)
        #expect(slotOfNoonPicture != .dawn)
    }

    @Test func theWallpaperHoldsTheSamePicturesEachInOneSlot() throws {
        let madeWithAI = try picture(origin: .madeWithAI)
        let real = try [picture(hour: 7), picture(), picture(hour: 18)]
        var wallpaper = try wallpaper(pictures: [.dusk: madeWithAI, .dawn: real[0], .night: real[1], .midday: real[2]])
        let idsBefore = Set(wallpaper.picturesInDayOrder.map(\.id))

        wallpaper.placeRealPicturesByTimeAgain()

        #expect(wallpaper.filledSlotCount == 4)
        #expect(wallpaper.picturesInDayOrder.count == 4)
        #expect(Set(wallpaper.picturesInDayOrder.map(\.id)) == idsBefore)
    }

    @Test func picturesAlreadyWhereAutomaticPlacementPutsThemStayThere() throws {
        let pictures = try [picture(hour: 6), picture(hour: 12), picture(hour: 21)]
        let placed = try Wallpaper.automaticPlacementInNewWallpaper(of: pictures)
        var wallpaper = try wallpaper(pictures: Dictionary(uniqueKeysWithValues: placed.map { ($0.slot, $0.picture) }))
        let before = wallpaper

        wallpaper.placeRealPicturesByTimeAgain()

        #expect(wallpaper == before)
    }

    @Test func aWallpaperWithOnlyPicturesMadeWithAIIsUnchanged() throws {
        var wallpaper = try wallpaper(pictures: [
            .dawn: picture(origin: .madeWithAI),
            .dusk: picture(origin: .madeWithAI),
        ])
        let before = wallpaper

        wallpaper.placeRealPicturesByTimeAgain()

        #expect(wallpaper == before)
    }

    @Test func aWallpaperWithoutPicturesIsUnchanged() throws {
        var wallpaper = try wallpaper(pictures: [:])
        let before = wallpaper

        wallpaper.placeRealPicturesByTimeAgain()

        #expect(wallpaper == before)
    }

    @Test func standInsOfEmptySlotsFollowTheNewArrangement() throws {
        let morning = try picture(hour: 9)
        var wallpaper = try wallpaper(pictures: [.night: morning])
        #expect(wallpaper.standIn(for: .dawn)?.slot == .night)

        wallpaper.placeRealPicturesByTimeAgain()

        let newSlot = try #require(Slot.allCases.first { wallpaper.picture(in: $0) == morning })
        #expect(newSlot != .night)
        for slot in wallpaper.emptySlots {
            #expect(wallpaper.standIn(for: slot)?.slot == newSlot)
            #expect(wallpaper.standIn(for: slot)?.picture == morning)
        }
    }
}
