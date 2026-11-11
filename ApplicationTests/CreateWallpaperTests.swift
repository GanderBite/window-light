import Foundation
import Testing
import Application
import Domain

private func content(_ text: String) -> Data {
    Data("content \(text)".utf8)
}

private let contentForEverySlot = Dictionary(uniqueKeysWithValues: Slot.allCases.map { ($0, content("\($0)")) })

private func create(
    _ pictureContentsBySlot: [Slot: Data],
    stem: String = "Wallpaper",
    in library: WallpaperLibraryStandIn,
    previews: PicturePreviewsStandIn = PicturePreviewsStandIn()
) async throws(CreateWallpaperError) -> Wallpaper {
    try await CreateWallpaper(library: library, previews: previews)
        .execute(pictureContentsBySlot: pictureContentsBySlot, defaultNameStem: stem)
}

struct CreateWallpaperTests {
    @Test func aWallpaperCreatedFromTwoPicturesIsInTheLibraryWithTheirExactBytesAndPreviews() async throws {
        let library = WallpaperLibraryStandIn()
        let dawnContent = content("dawn")
        let duskContent = content("dusk")

        let wallpaper = try await create([.dawn: dawnContent, .dusk: duskContent], in: library)

        let dawnPicture = try #require(wallpaper.picture(in: .dawn))
        let duskPicture = try #require(wallpaper.picture(in: .dusk))
        #expect(wallpaper.filledSlotCount == 2)
        #expect(await library.storedWallpapers == [wallpaper])
        #expect(await library.storedPictureContents == [dawnPicture.id: dawnContent, duskPicture.id: duskContent])
        #expect(await library.storedPicturePreviews == [
            dawnPicture.id: PicturePreviewsStandIn.preview(of: dawnContent),
            duskPicture.id: PicturePreviewsStandIn.preview(of: duskContent)
        ])
    }

    @Test func aWallpaperCreatedWithAPictureInEverySlotHasEightFilledSlots() async throws {
        let wallpaper = try await create(contentForEverySlot, in: WallpaperLibraryStandIn())
        #expect(wallpaper.filledSlotCount == 8)
    }

    @Test func aWallpaperCreatedWithOnePictureHasOneFilledSlot() async throws {
        let wallpaper = try await create([.morning: content("morning")], in: WallpaperLibraryStandIn())
        #expect(wallpaper.filledSlotCount == 1)
        #expect(wallpaper.picture(in: .morning) != nil)
    }

    @Test func wallpapersCreatedInAnEmptyLibraryAreNumberedFromOne() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await create([.dawn: content("first")], in: library)
        let second = try await create([.dawn: content("second")], in: library)
        #expect(first.name.text == "Wallpaper 1")
        #expect(second.name.text == "Wallpaper 2")
    }

    @Test func theStemOfTheDefaultNameComesFromTheCaller() async throws {
        let wallpaper = try await create([.dawn: content("first")], stem: "Tapeta", in: WallpaperLibraryStandIn())
        #expect(wallpaper.name.text == "Tapeta 1")
    }

    @Test func twoCreatedWallpapersAndAllTheirPicturesHaveDifferentIDs() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await create(contentForEverySlot, in: library)
        let second = try await create(contentForEverySlot, in: library)
        let pictureIDs = (first.picturesInDayOrder + second.picturesInDayOrder).map(\.id)
        #expect(first.id != second.id)
        #expect(Set(pictureIDs).count == 16)
    }

    @Test func creatingWithNoPicturesFailsAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()

        await #expect(throws: CreateWallpaperError.noPictures) {
            try await create([:], in: library)
        }
        #expect(await library.receivedAnAdd == false)
        #expect(await library.storedWallpapers.isEmpty)
    }

    @Test func anUnreadableMiddayPictureFailsWithItsSlotAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        let middayContent = content("midday")
        let previews = PicturePreviewsStandIn(failingFor: middayContent)

        await #expect(throws: CreateWallpaperError.unreadablePicture(in: .midday)) {
            try await create(
                [.dawn: content("dawn"), .midday: middayContent, .night: content("night")],
                in: library,
                previews: previews
            )
        }
        #expect(await library.storedWallpapers.isEmpty)
        #expect(await library.storedPictureContents.isEmpty)
    }

    @Test func noSpaceLeftInTheLibraryFailsAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        await library.fail(.add, with: .noSpaceLeft)

        await #expect(throws: CreateWallpaperError.noSpaceLeft) {
            try await create([.dawn: content("dawn")], in: library)
        }
        #expect(await library.storedWallpapers.isEmpty)
        #expect(await library.storedPictureContents.isEmpty)
    }

    @Test func aStemOfFortyNineCharactersMakesTheDefaultNameTooLongAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        let stem = String(repeating: "a", count: 49)

        await #expect(throws: CreateWallpaperError.defaultNameTooLong(limit: 50)) {
            try await create([.dawn: content("dawn")], stem: stem, in: library)
        }
        #expect(await library.receivedAnAdd == false)
        #expect(await library.storedWallpapers.isEmpty)
    }

    @Test func anUnexpectedPreviewFailureFailsAsUnavailableWithItsDescriptionAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        let middayContent = content("midday")
        let previews = PicturePreviewsStandIn(
            failingFor: middayContent,
            with: .unexpected(description: "decoder crashed")
        )

        await #expect(throws: CreateWallpaperError.unavailable(description: "decoder crashed")) {
            try await create([.dawn: content("dawn"), .midday: middayContent], in: library, previews: previews)
        }
        #expect(await library.storedWallpapers.isEmpty)
        #expect(await library.storedPictureContents.isEmpty)
    }

    @Test func anUnexpectedFailureToAddFailsAsUnavailableWithItsDescriptionAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        await library.fail(.add, with: .unexpected(description: "disk vanished"))

        await #expect(throws: CreateWallpaperError.unavailable(description: "disk vanished")) {
            try await create([.dawn: content("dawn")], in: library)
        }
        #expect(await library.storedWallpapers.isEmpty)
        #expect(await library.storedPictureContents.isEmpty)
    }

    @Test func aLibraryThatCannotListItsWallpapersFailsAsUnavailableAndAddsNothing() async {
        let library = WallpaperLibraryStandIn()
        await library.fail(.wallpapers, with: .unavailable)

        let thrown = await #expect(throws: CreateWallpaperError.self) {
            try await create([.dawn: content("dawn")], in: library)
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }
        #expect(await library.receivedAnAdd == false)
    }

    @Test func creatingAWallpaperDoesNotMarkItAsLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        _ = try await create([.dawn: content("dawn")], in: library)
        #expect(await library.lastWorkedOn == nil)
    }
}
