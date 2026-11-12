import Application
import Domain
import Foundation
import Testing

private func addWallpaper(to library: WallpaperLibraryStandIn, stem: String = "Wallpaper") async throws -> Wallpaper {
    let picture = try Picture(
        id: PictureID(UUID()),
        origin: .imported,
        captureTime: nil,
        fingerprint: ContentFingerprint("fingerprint dawn \(stem)"),
    )
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("\(stem) 1"), pictures: [.dawn: picture])
    try await library.add(
        wallpaper,
        pictureContents: [picture.id: Data("dawn \(stem)".utf8)],
        picturePreviews: [picture.id: Data("preview dawn \(stem)".utf8)],
    )
    return wallpaper
}

struct OpenWallpaperTests {
    @Test func openingAWallpaperReturnsItAndTheLibraryRemembersItAsLastWorkedOn() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)

        let opened = try await OpenWallpaper(library: library).execute(wallpaper.id)

        #expect(opened.wallpaper == wallpaper)
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

    @Test func openingAWallpaperThatIsNotInTheLibraryFailsAsGoneAndKeepsTheLastWorkedOn(
    ) async throws {
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

    @Test func openingAWallpaperWithPicturesInDawnAndDuskGivesTheirPreviewsAndNoneForTheEmptySlots() async throws {
        let library = WallpaperLibraryStandIn()
        let dawn = try Domain.Picture(
            id: PictureID(UUID()), origin: .imported, captureTime: nil, fingerprint: ContentFingerprint("dawn"),
        )
        let dusk = try Domain.Picture(
            id: PictureID(UUID()), origin: .imported, captureTime: nil, fingerprint: ContentFingerprint("dusk"),
        )
        let wallpaper = try Wallpaper(
            id: WallpaperID(UUID()),
            name: WallpaperName("Sea"),
            pictures: [.dawn: dawn, .dusk: dusk],
        )
        try await library.add(
            wallpaper,
            pictureContents: [dawn.id: Data("c1".utf8), dusk.id: Data("c2".utf8)],
            picturePreviews: [dawn.id: Data("preview dawn".utf8), dusk.id: Data("preview dusk".utf8)],
        )

        let opened = try await OpenWallpaper(library: library).execute(wallpaper.id)

        #expect(opened.wallpaper == wallpaper)
        #expect(opened.picturePreview(in: .dawn) == Data("preview dawn".utf8))
        #expect(opened.picturePreview(in: .dusk) == Data("preview dusk".utf8))
        #expect(opened.picturePreviewsInDayOrder == [Data("preview dawn".utf8), Data("preview dusk".utf8)])
        for slot in Slot.allCases where slot != .dawn && slot != .dusk {
            #expect(opened.picturePreview(in: slot) == nil)
        }
    }

    @Test func aPictureWithoutAPreviewFailsOpeningAsUnavailableAndRemembersNothing() async throws {
        let library = WallpaperLibraryStandIn()
        var wallpaper = try await addWallpaper(to: library)
        let unpreviewed = try Domain.Picture(
            id: PictureID(UUID()), origin: .imported, captureTime: nil, fingerprint: ContentFingerprint("no preview"),
        )
        _ = try wallpaper.place(unpreviewed, in: .dusk)
        try await library.keep(wallpaper)

        let thrown = await #expect(throws: OpenWallpaperError.self) {
            try await OpenWallpaper(library: library).execute(wallpaper.id)
        }
        guard case .unavailable = thrown else {
            Issue.record("Expected unavailable, got \(String(describing: thrown))")
            return
        }

        #expect(await library.lastWorkedOn == nil)
    }
}
