import Application
import Domain
import Foundation
import Testing

private func addWallpaper(to library: WallpaperLibraryStandIn, stem: String = "Wallpaper") async throws -> Wallpaper {
    var picturesBySlot: [Slot: Picture] = [:]
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for slot in [Slot.dawn, .dusk] {
        let picture = try Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: nil,
            fingerprint: ContentFingerprint("fingerprint \(slot) \(stem)"),
        )
        picturesBySlot[slot] = picture
        contents[picture.id] = Data("\(slot) \(stem)".utf8)
        previews[picture.id] = Data("preview \(slot) \(stem)".utf8)
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("\(stem) 1"), pictures: picturesBySlot)
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return wallpaper
}

struct DeleteWallpaperTests {
    @Test func deletingAWallpaperRemovesItWithItsPictureContentsAndPreviewsAndLeavesTheOthers(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let doomed = try await addWallpaper(to: library, stem: "Doomed")
        let other = try await addWallpaper(to: library, stem: "Other")
        let otherPictureIDs = Set(other.picturesInDayOrder.map(\.id))

        try await DeleteWallpaper(library: library).execute(doomed.id)

        #expect(await library.storedWallpapers == [other])
        #expect(await Set(library.storedPictureContents.keys) == otherPictureIDs)
        #expect(await Set(library.storedPicturePreviews.keys) == otherPictureIDs)
    }

    @Test func deletingAWallpaperThatIsNotInTheLibrarySucceedsAndChangesNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        let contentsBefore = await library.storedPictureContents
        let previewsBefore = await library.storedPicturePreviews

        try await DeleteWallpaper(library: library).execute(WallpaperID(UUID()))

        #expect(await library.storedWallpapers == [wallpaper])
        #expect(await library.storedPictureContents == contentsBefore)
        #expect(await library.storedPicturePreviews == previewsBefore)
    }

    @Test func aLibraryThatFailsToRemoveFailsAsUnavailableAndKeepsTheWallpaper() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.remove, with: .notPermitted)

        await #expect(throws: DeleteWallpaperError.unavailable(description: "The wallpaper library may not be used.")) {
            try await DeleteWallpaper(library: library).execute(wallpaper.id)
        }
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func anUnexpectedFailureToRemoveFailsAsUnavailableWithItsDescription() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.remove, with: .unexpected(description: "disk vanished"))

        await #expect(throws: DeleteWallpaperError.unavailable(description: "disk vanished")) {
            try await DeleteWallpaper(library: library).execute(wallpaper.id)
        }
        #expect(await library.storedWallpapers == [wallpaper])
    }
}
