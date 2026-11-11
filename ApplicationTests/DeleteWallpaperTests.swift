import Foundation
import Testing
import Application
import Domain

private func addWallpaper(to library: WallpaperLibraryStandIn, stem: String = "Wallpaper") async throws -> Wallpaper {
    try await CreateWallpaper(library: library, previews: PicturePreviewsStandIn())
        .execute(
            pictureContentsBySlot: [.dawn: Data("dawn \(stem)".utf8), .dusk: Data("dusk \(stem)".utf8)],
            defaultNameStem: stem
        )
}

struct DeleteWallpaperTests {
    @Test func deletingAWallpaperRemovesItWithItsPictureContentsAndPreviewsAndLeavesTheOthers() async throws {
        let library = WallpaperLibraryStandIn()
        let doomed = try await addWallpaper(to: library, stem: "Doomed")
        let other = try await addWallpaper(to: library, stem: "Other")
        let otherPictureIDs = Set(other.picturesInDayOrder.map(\.id))

        try await DeleteWallpaper(library: library).execute(doomed.id)

        #expect(await library.storedWallpapers == [other])
        #expect(Set(await library.storedPictureContents.keys) == otherPictureIDs)
        #expect(Set(await library.storedPicturePreviews.keys) == otherPictureIDs)
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
