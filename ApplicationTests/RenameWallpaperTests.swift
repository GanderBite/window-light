import Application
import Domain
import Foundation
import Testing

private func addWallpaper(to library: WallpaperLibraryStandIn, stem: String = "Wallpaper") async throws -> Wallpaper {
    try await CreateWallpaper(library: library, previews: PicturePreviewsStandIn())
        .execute(pictureContentsBySlot: [.dawn: Data("dawn \(stem)".utf8)], defaultNameStem: stem)
}

private func storedName(of wallpaper: Wallpaper, in library: WallpaperLibraryStandIn) async -> String? {
    await library.storedWallpapers.first { $0.id == wallpaper.id }?.name.text
}

struct RenameWallpaperTests {
    @Test func renamingToHolidayReturnsTheRenamedWallpaperAndTheLibraryHoldsTheNewName() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)

        let renamed = try await RenameWallpaper(library: library).execute(wallpaper.id, to: "Holiday")

        #expect(renamed.id == wallpaper.id)
        #expect(renamed.name.text == "Holiday")
        #expect(await storedName(of: wallpaper, in: library) == "Holiday")
    }

    @Test func renamingToANameOfFiftyCharactersSucceeds() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        let name = String(repeating: "a", count: 50)

        let renamed = try await RenameWallpaper(library: library).execute(wallpaper.id, to: name)

        #expect(renamed.name.text == name)
        #expect(await storedName(of: wallpaper, in: library) == name)
    }

    @Test(arguments: ["", "   "])
    func renamingToNoTextFailsAsNameEmptyAsksNothingOfTheLibraryAndKeepsTheOldName(
        proposed: String,
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        let callsBefore = await library.receivedCalls

        await #expect(throws: RenameWallpaperError.nameEmpty) {
            try await RenameWallpaper(library: library).execute(wallpaper.id, to: proposed)
        }
        #expect(await library.receivedCalls == callsBefore)
        #expect(await storedName(of: wallpaper, in: library) == wallpaper.name.text)
    }

    @Test func renamingToFiftyOneCharactersFailsAsNameTooLongAndKeepsTheOldName() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)

        await #expect(throws: RenameWallpaperError.nameTooLong(limit: 50)) {
            try await RenameWallpaper(library: library).execute(wallpaper.id, to: String(repeating: "a", count: 51))
        }
        #expect(await storedName(of: wallpaper, in: library) == wallpaper.name.text)
    }

    @Test func renamingToTheNameAnotherWallpaperHasSucceedsAndBothHaveIt() async throws {
        let library = WallpaperLibraryStandIn()
        let first = try await addWallpaper(to: library, stem: "First")
        let second = try await addWallpaper(to: library, stem: "Second")

        _ = try await RenameWallpaper(library: library).execute(second.id, to: first.name.text)

        #expect(await storedName(of: first, in: library) == first.name.text)
        #expect(await storedName(of: second, in: library) == first.name.text)
    }

    @Test func renamingAWallpaperThatIsNotInTheLibraryFailsAsGone() async {
        let library = WallpaperLibraryStandIn()

        await #expect(throws: RenameWallpaperError.wallpaperGone) {
            try await RenameWallpaper(library: library).execute(WallpaperID(UUID()), to: "Holiday")
        }
    }

    @Test func aLibraryWithNoSpaceLeftToKeepTheChangeFailsAsNoSpaceLeftAndKeepsTheOldName(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.keep, with: .noSpaceLeft)

        await #expect(throws: RenameWallpaperError.noSpaceLeft) {
            try await RenameWallpaper(library: library).execute(wallpaper.id, to: "Holiday")
        }
        #expect(await storedName(of: wallpaper, in: library) == wallpaper.name.text)
    }

    @Test func aLibraryThatCannotReadTheWallpaperFailsAsUnavailable() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.wallpaper, with: .notPermitted)

        await #expect(throws: RenameWallpaperError.unavailable(description: "The wallpaper library may not be used.")) {
            try await RenameWallpaper(library: library).execute(wallpaper.id, to: "Holiday")
        }
        #expect(await storedName(of: wallpaper, in: library) == wallpaper.name.text)
    }

    @Test func anUnexpectedFailureToKeepFailsAsUnavailableWithItsDescriptionAndKeepsTheOldName(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(to: library)
        await library.fail(.keep, with: .unexpected(description: "disk vanished"))

        await #expect(throws: RenameWallpaperError.unavailable(description: "disk vanished")) {
            try await RenameWallpaper(library: library).execute(wallpaper.id, to: "Holiday")
        }
        #expect(await storedName(of: wallpaper, in: library) == wallpaper.name.text)
    }

    @Test func renamingAsksTheLibraryOnlyToReadThatWallpaperAndToKeepIt() async throws {
        let library = WallpaperLibraryStandIn()
        _ = try await addWallpaper(to: library, stem: "Other")
        let wallpaper = try await addWallpaper(to: library)
        let callsBefore = await library.receivedCalls.count

        _ = try await RenameWallpaper(library: library).execute(wallpaper.id, to: "Holiday")

        let renamingCalls = await library.receivedCalls.dropFirst(callsBefore)
        #expect(Array(renamingCalls) == [.wallpaper(wallpaper.id), .keep(wallpaper.id)])
    }
}
