import Foundation
import Testing
@testable import Domain

private func picture() -> Picture {
    Picture(id: PictureID(UUID()))
}

private func name(_ text: String) throws -> WallpaperName {
    try WallpaperName(text)
}

private func wallpaper(named text: String = "Holiday", pictures: [Slot: Picture]) throws -> Wallpaper {
    try Wallpaper(id: WallpaperID(UUID()), name: name(text), pictures: pictures)
}

struct WallpaperTests {
    @Test func aWallpaperWithPicturesInThreeSlotsAnswersForEachSlot() throws {
        let night = picture()
        let dawn = picture()
        let midday = picture()
        let wallpaper = try wallpaper(pictures: [.night: night, .dawn: dawn, .midday: midday])
        #expect(wallpaper.filledSlotCount == 3)
        #expect(wallpaper.picture(in: .night) == night)
        #expect(wallpaper.picture(in: .dawn) == dawn)
        #expect(wallpaper.picture(in: .midday) == midday)
        #expect(wallpaper.picture(in: .sunset) == nil)
        #expect(wallpaper.picturesInDayOrder == [dawn, midday, night])
    }

    @Test func aWallpaperWithAPictureInEverySlotHasEightFilledSlots() throws {
        let everySlot = Dictionary(uniqueKeysWithValues: Slot.allCases.map { ($0, picture()) })
        #expect(try wallpaper(pictures: everySlot).filledSlotCount == 8)
    }

    @Test func aWallpaperWithOnePictureExists() throws {
        #expect(try wallpaper(pictures: [.morning: picture()]).filledSlotCount == 1)
    }

    @Test func aWallpaperWithoutPicturesIsRefused() {
        #expect(throws: WallpaperError.noPictures) {
            try wallpaper(pictures: [:])
        }
    }

    @Test func theSamePictureInTwoSlotsIsRefused() {
        let repeated = picture()
        #expect(throws: WallpaperError.pictureInTwoSlots(repeated.id)) {
            try wallpaper(pictures: [.dawn: repeated, .dusk: repeated])
        }
    }

    @Test func renamingChangesTheNameAndNothingElse() throws {
        let dawn = picture()
        var wallpaper = try wallpaper(named: "Holiday", pictures: [.dawn: dawn])
        let idBefore = wallpaper.id
        let newName = try name("Sea view")
        wallpaper.rename(to: newName)
        #expect(wallpaper.name == newName)
        #expect(wallpaper.id == idBefore)
        #expect(wallpaper.picturesInDayOrder == [dawn])
    }

    @Test func twoWallpapersWithDifferentIdsCanHoldEqualNames() throws {
        let first = try wallpaper(named: "Holiday", pictures: [.dawn: picture()])
        let second = try wallpaper(named: "Holiday", pictures: [.dawn: picture()])
        #expect(first.name == second.name)
        #expect(first.id != second.id)
    }
}
