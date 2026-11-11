import Foundation
import Testing
import Application
import Domain

private func addWallpaper(to library: WallpaperLibraryStandIn, stem: String = "Wallpaper") async throws -> Wallpaper {
    try await CreateWallpaper(library: library, previews: PicturePreviewsStandIn())
        .execute(pictureContentsBySlot: [.dawn: Data("dawn \(stem)".utf8)], defaultNameStem: stem)
}

struct OpenWallpaperTests {
    @Test func openingAWallpaperReturnsItAndTheLibraryRemembersItAsLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)

        let opened = try await OpenWallpaper(library: library).execute(wallpaper.id)

        #expect(opened == wallpaper)
        #expect(await library.lastWorkedOn == wallpaper.id)
    }

    @Test func openingAnotherWallpaperReplacesTheLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await addWallpaper(to: library, stem: "First")
        let second = try await addWallpaper(to: library, stem: "Second")
        let open = OpenWallpaper(library: library)

        _ = try await open.execute(first.id)
        _ = try await open.execute(second.id)

        #expect(await library.lastWorkedOn == second.id)
    }

    @Test func openingAWallpaperThatIsNotInTheLibraryFailsAsGoneAndKeepsTheLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        let kept = try await addWallpaper(to: library)
        _ = try await OpenWallpaper(library: library).execute(kept.id)

        await #expect(throws: OpenWallpaperError.wallpaperGone) {
            try await OpenWallpaper(library: library).execute(WallpaperID(UUID()))
        }
        #expect(await library.lastWorkedOn == kept.id)
    }

    @Test func aLibraryThatCannotReadTheWallpaperFailsAsUnavailableAndRemembersNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.wallpaper, with: .unreadable)

        await #expect(throws: OpenWallpaperError.unavailable(description: "The wallpaper library cannot be read.")) {
            try await OpenWallpaper(library: library).execute(wallpaper.id)
        }
        #expect(await library.lastWorkedOn == nil)
    }

    @Test func anUnexpectedFailureToRememberFailsAsUnavailableWithItsDescription() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.rememberAsLastWorkedOn, with: .unexpected(description: "disk vanished"))

        await #expect(throws: OpenWallpaperError.unavailable(description: "disk vanished")) {
            try await OpenWallpaper(library: library).execute(wallpaper.id)
        }
    }
}
