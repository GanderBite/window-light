import Application
import Domain
import Foundation
import Testing

private struct StoredWallpaper {
    var wallpaper: Wallpaper
    let dawn: Picture
    let dusk: Picture
}

private func addWallpaper(to library: WallpaperLibraryStandIn) async throws -> StoredWallpaper {
    var picturesBySlot: [Slot: Picture] = [:]
    var dawn: Picture?
    var dusk: Picture?
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for slot in [Slot.dawn, .dusk] {
        let picture = try Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: nil,
            fingerprint: ContentFingerprint("fingerprint \(slot)"),
        )
        picturesBySlot[slot] = picture
        if slot == .dawn {
            dawn = picture
        } else {
            dusk = picture
        }
        contents[picture.id] = Data("\(slot)".utf8)
        previews[picture.id] = Data("preview \(slot)".utf8)
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Wallpaper 1"), pictures: picturesBySlot)
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
    return try StoredWallpaper(
        wallpaper: wallpaper,
        dawn: #require(dawn),
        dusk: #require(dusk),
    )
}

private func removeDawnPicture(from stored: inout StoredWallpaper, in library: WallpaperLibraryStandIn) async throws {
    _ = stored.wallpaper.removePicture(from: .dawn)
    try await library.keep(stored.wallpaper)
}

struct FinishArrangingTests {
    @Test func aPictureRemovedFromTheWallpaperIsDiscardedAndTheOutcomeSaysSo() async throws {
        let library = WallpaperLibraryStandIn()
        var stored = try await addWallpaper(to: library)
        try await removeDawnPicture(from: &stored, in: library)

        let outcome = await FinishArranging(library: library).execute(stored.wallpaper.id)

        #expect(outcome == .picturesDiscarded)
        #expect(await library.storedPictureContents[stored.dawn.id] == nil)
        #expect(await library.storedPicturePreviews[stored.dawn.id] == nil)
    }

    @Test func thePicturesTheWallpaperHoldsAndTheWallpaperItselfAreUntouched() async throws {
        let library = WallpaperLibraryStandIn()
        var stored = try await addWallpaper(to: library)
        try await removeDawnPicture(from: &stored, in: library)
        let duskContent = await library.storedPictureContents[stored.dusk.id]
        let duskPreview = await library.storedPicturePreviews[stored.dusk.id]

        await FinishArranging(library: library).execute(stored.wallpaper.id)

        #expect(await library.storedWallpapers == [stored.wallpaper])
        #expect(await library.storedPictureContents[stored.dusk.id] == duskContent)
        #expect(await library.storedPicturePreviews[stored.dusk.id] == duskPreview)
        #expect(duskContent != nil)
    }

    @Test func aWallpaperThatIsNotInTheLibraryHasNoPicturesLeftToDiscard() async {
        let library = WallpaperLibraryStandIn()

        let outcome = await FinishArranging(library: library).execute(WallpaperID(UUID()))

        #expect(outcome == .picturesDiscarded)
    }

    @Test(arguments: [
        (WallpaperLibraryError.notPermitted, "The wallpaper library may not be used."),
        (.noSpaceLeft, "There is no space left for the wallpaper library."),
        (.unreadable, "The wallpaper library cannot be read."),
        (.unavailable, "The wallpaper library is unavailable."),
        (.unexpected(description: "disk vanished"), "disk vanished"),
    ])
    func aLibraryFailureIsReportedAsAnOutcomeWithTheDescriptionOfItsCause(
        error: WallpaperLibraryError,
        description: String,
    ) async throws {
        let library = WallpaperLibraryStandIn()
        var stored = try await addWallpaper(to: library)
        try await removeDawnPicture(from: &stored, in: library)
        await library.fail(.discardPicturesNoLongerHeld, with: error)

        let outcome = await FinishArranging(library: library).execute(stored.wallpaper.id)

        #expect(outcome == .picturesLeftForLater(description: description))
        #expect(await library.storedPictureContents[stored.dawn.id] != nil)
    }

    @Test func theOnlyCallTheLibraryReceivesIsTheDiscardForTheGivenWallpaper() async {
        let library = WallpaperLibraryStandIn()
        let wallpaper = WallpaperID(UUID())

        await FinishArranging(library: library).execute(wallpaper)

        #expect(await library.receivedCalls == [.discardPicturesNoLongerHeld(wallpaper)])
    }
}
