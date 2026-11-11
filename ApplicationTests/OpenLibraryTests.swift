import Foundation
import Testing
import Application
import Domain

private func previewBytes(_ text: String) -> Data {
    Data("preview \(text)".utf8)
}

@discardableResult
private func addWallpaper(
    named text: String,
    previewTextsBySlot: [Slot: String],
    to library: WallpaperLibraryStandIn
) async throws -> Wallpaper {
    let picturesBySlot = previewTextsBySlot.mapValues { _ in Picture(id: PictureID(UUID())) }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(text), pictures: picturesBySlot)
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for (slot, picture) in picturesBySlot {
        contents[picture.id] = Data("content \(text) \(slot)".utf8)
        previews[picture.id] = previewBytes(previewTextsBySlot[slot] ?? "")
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return wallpaper
}

struct OpenLibraryTests {
    @Test func openingAnEmptyLibraryReturnsNoWallpapersAndNoneLastWorkedOn() async throws {
        let contents = try await OpenLibrary(library: WallpaperLibraryStandIn()).execute()
        #expect(contents.wallpapers.isEmpty)
        #expect(contents.wallpaperLastWorkedOn == nil)
    }

    @Test func openingALibraryOfThreeReturnsThemInTheOrderAddedWithTheOneLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await addWallpaper(named: "First", previewTextsBySlot: [.dawn: "a"], to: library)
        let second = try await addWallpaper(named: "Second", previewTextsBySlot: [.dusk: "b"], to: library)
        let third = try await addWallpaper(named: "Third", previewTextsBySlot: [.night: "c"], to: library)
        try await library.rememberAsLastWorkedOn(second.id)

        let contents = try await OpenLibrary(library: library).execute()

        #expect(contents.wallpapers.map(\.id) == [first.id, second.id, third.id])
        #expect(contents.wallpapers.map(\.wallpaper) == [first, second, third])
        #expect(contents.wallpaperLastWorkedOn == second.id)
    }

    @Test func previewsOfPicturesInNightAndDawnComeWithDawnFirst() async throws {
        let library = WallpaperLibraryStandIn()
        try await addWallpaper(named: "Sea", previewTextsBySlot: [.night: "night", .dawn: "dawn"], to: library)

        let contents = try await OpenLibrary(library: library).execute()

        #expect(contents.wallpapers.first?.picturePreviewsInDayOrder == [previewBytes("dawn"), previewBytes("night")])
    }

    @Test func openingALibraryOfAHundredFullWallpapersReturnsAHundredEntriesWithEightPreviewsEach() async throws {
        let library = WallpaperLibraryStandIn()
        let everySlot = Dictionary(uniqueKeysWithValues: Slot.allCases.map { ($0, "\($0)") })
        for number in 1...100 {
            try await addWallpaper(named: "Wallpaper \(number)", previewTextsBySlot: everySlot, to: library)
        }

        let contents = try await OpenLibrary(library: library).execute()

        #expect(contents.wallpapers.count == 100)
        #expect(contents.wallpapers.allSatisfy { $0.picturePreviewsInDayOrder.count == 8 })
    }

    @Test func anUnreadableLibraryMakesOpeningFailAsUnreadable() async {
        let library = WallpaperLibraryStandIn()
        await library.failEveryCall(with: .unreadable)

        await #expect(throws: OpenLibraryError.unreadable) {
            try await OpenLibrary(library: library).execute()
        }
    }

    @Test(arguments: [WallpaperLibraryError.notPermitted, .unavailable, .unexpected(description: "disk vanished")])
    func anyOtherLibraryFailureMakesOpeningFailAsUnavailable(failure: WallpaperLibraryError) async {
        let library = WallpaperLibraryStandIn()
        await library.failEveryCall(with: failure)

        let thrown = await #expect(throws: OpenLibraryError.self) {
            try await OpenLibrary(library: library).execute()
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }
    }

    @Test func anUnexpectedLibraryFailureKeepsItsDescription() async {
        let library = WallpaperLibraryStandIn()
        await library.failEveryCall(with: .unexpected(description: "disk vanished"))

        await #expect(throws: OpenLibraryError.unavailable(description: "disk vanished")) {
            try await OpenLibrary(library: library).execute()
        }
    }
}
