import Application
import Domain
import Foundation
import Testing

private func content(of picture: Domain.Picture) -> Data {
    Data("content of \(picture.fingerprint)".utf8)
}

private func picture(
    _ name: String,
    origin: PictureOrigin = .imported,
    captureTime: CaptureTime? = nil,
) throws -> Domain.Picture {
    try Domain.Picture(
        id: PictureID(UUID()),
        origin: origin,
        captureTime: captureTime,
        fingerprint: ContentFingerprint("fingerprint of \(name)"),
    )
}

private func storedWallpaper(
    in library: WallpaperLibraryStandIn,
    holding pictures: [Slot: Domain.Picture],
) async throws -> Wallpaper {
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
    let contents = Dictionary(uniqueKeysWithValues: pictures.values.map { ($0.id, content(of: $0)) })
    try await library.add(
        wallpaper,
        pictureContents: contents,
        picturePreviews: contents.mapValues(PicturePreviewsStandIn.preview(of:)),
    )
    return wallpaper
}

private func storedWallpaper(
    in library: WallpaperLibraryStandIn,
    holding origins: [Slot: PictureOrigin],
) async throws -> Wallpaper {
    var pictures: [Slot: Domain.Picture] = [:]
    for (slot, origin) in origins {
        pictures[slot] = try picture("held in \(slot)", origin: origin)
    }
    return try await storedWallpaper(in: library, holding: pictures)
}

private func arrange(
    _ change: ArrangementChange,
    in wallpaper: WallpaperID,
    library: WallpaperLibraryStandIn,
) async throws(ArrangePicturesError) -> WallpaperInLibrary {
    try await ArrangePictures(library: library).execute(change, in: wallpaper)
}

private func receivedAKeep(_ library: WallpaperLibraryStandIn) async -> Bool {
    await library.receivedCalls.contains { call in
        switch call {
        case .keep, .keepAdding: true
        default: false
        }
    }
}

private func receivedADiscard(_ library: WallpaperLibraryStandIn) async -> Bool {
    await library.receivedCalls.contains { call in
        if case .discardPicturesNoLongerHeld = call {
            return true
        }
        return false
    }
}

struct ArrangePicturesTests {
    @Test func movingAPictureFromMorningToAnEmptyAfternoonPutsItThereAndStoresThatWallpaper() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])
        let moving = try #require(wallpaper.picture(in: .morning))

        let arranged = try await arrange(
            .movePicture(from: .morning, to: .afternoon),
            in: wallpaper.id,
            library: library,
        )

        #expect(arranged.wallpaper.picture(in: .afternoon) == moving)
        #expect(arranged.wallpaper.picture(in: .morning) == nil)
        #expect(arranged.wallpaper.picture(in: .night) == wallpaper.picture(in: .night))
        #expect(await library.storedWallpapers == [arranged.wallpaper])
    }

    @Test func movingAPictureOntoASlotWithARealPictureSwapsTheTwoAndStoresThatWallpaper() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])
        let morningPicture = try #require(wallpaper.picture(in: .morning))
        let nightPicture = try #require(wallpaper.picture(in: .night))

        let arranged = try await arrange(.movePicture(from: .morning, to: .night), in: wallpaper.id, library: library)

        #expect(arranged.wallpaper.picture(in: .night) == morningPicture)
        #expect(arranged.wallpaper.picture(in: .morning) == nightPicture)
        #expect(await library.storedWallpapers == [arranged.wallpaper])
    }

    @Test func removingAPictureStoresTheWallpaperWithoutItAndKeepsItsStoredContent() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(
            in: library,
            holding: [.morning: .imported, .midday: .imported, .night: .imported],
        )
        let removed = try #require(wallpaper.picture(in: .midday))
        let removedContent = try #require(await library.storedPictureContents[removed.id])
        let removedPreview = try #require(await library.storedPicturePreviews[removed.id])

        let arranged = try await arrange(.removePicture(from: .midday), in: wallpaper.id, library: library)

        #expect(arranged.wallpaper.picture(in: .midday) == nil)
        #expect(arranged.wallpaper.picturesInDayOrder.contains(removed) == false)
        #expect(arranged.wallpaper.filledSlotCount == 2)
        #expect(arranged.picturePreviewsInDayOrder.contains(removedPreview) == false)
        #expect(await library.storedWallpapers == [arranged.wallpaper])
        #expect(await library.storedPictureContents[removed.id] == removedContent)
    }

    @Test func removingAPictureFromAWallpaperWithTwoLeavesOneThatIsNotReadyToApplyAndStillInTheLibrary() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])

        let arranged = try await arrange(.removePicture(from: .night), in: wallpaper.id, library: library)

        #expect(arranged.wallpaper.filledSlotCount == 1)
        #expect(arranged.wallpaper.isReadyToApply == false)
        #expect(await library.storedWallpapers == [arranged.wallpaper])
    }

    @Test func placingByTimeAgainStoresTheArrangementTheWallpaperGivesByTime() async throws {
        let library = WallpaperLibraryStandIn()
        let earlyMorning = try CaptureTime(year: 2026, month: 6, day: 21, hour: 9, minute: 0, second: 0)
        let lateEvening = try CaptureTime(year: 2026, month: 6, day: 21, hour: 23, minute: 0, second: 0)
        let wallpaper = try await storedWallpaper(
            in: library,
            holding: [
                .dawn: picture("evening", captureTime: lateEvening),
                .night: picture("morning", captureTime: earlyMorning),
            ],
        )
        var placedByTime = wallpaper
        placedByTime.placeRealPicturesByTimeAgain()

        let arranged = try await arrange(.placeByTimeAgain, in: wallpaper.id, library: library)

        #expect(placedByTime.arrangement != wallpaper.arrangement)
        #expect(arranged.wallpaper == placedByTime)
        #expect(await library.storedWallpapers == [placedByTime])
    }

    @Test func goingBackToAnArrangementTakenBeforeARemovalBringsThePictureBackWithItsPreview() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(
            in: library,
            holding: [.morning: .imported, .midday: .imported, .night: .imported],
        )
        let removed = try #require(wallpaper.picture(in: .midday))
        let removedPreview = try #require(await library.storedPicturePreviews[removed.id])
        let arrangementBeforeRemoval = wallpaper.arrangement
        _ = try await arrange(.removePicture(from: .midday), in: wallpaper.id, library: library)

        let arranged = try await arrange(.goBack(to: arrangementBeforeRemoval), in: wallpaper.id, library: library)

        #expect(arranged.wallpaper.picture(in: .midday) == removed)
        #expect(arranged.picturePreview(in: .midday) == removedPreview)
        #expect(arranged.wallpaper == wallpaper)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func goingBackKeepsTheNameTheWallpaperWasRenamedToAfterTheArrangementWasTaken() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])
        let arrangementBeforeMove = wallpaper.arrangement
        _ = try await arrange(.movePicture(from: .morning, to: .afternoon), in: wallpaper.id, library: library)
        var renamed = try await library.wallpaper(wallpaper.id)
        let newName = try WallpaperName("Summer")
        renamed.rename(to: newName)
        try await library.keep(renamed)

        let arranged = try await arrange(.goBack(to: arrangementBeforeMove), in: wallpaper.id, library: library)

        #expect(arranged.wallpaper.name == newName)
        #expect(arranged.wallpaper.arrangement == arrangementBeforeMove)
        #expect(await library.storedWallpapers.map(\.name) == [newName])
        #expect(await library.storedWallpapers.map(\.arrangement) == [arrangementBeforeMove])
    }

    @Test func theArrangedWallpaperComesWithAPreviewForEveryPictureInDayOrder() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(
            in: library,
            holding: [.dawn: .imported, .morning: .imported, .night: .madeWithAI],
        )

        let arranged = try await arrange(.movePicture(from: .dawn, to: .sunset), in: wallpaper.id, library: library)

        let storedPreviews = await library.storedPicturePreviews
        let expectedPreviews = arranged.wallpaper.picturesInDayOrder.map { storedPreviews[$0.id] }
        #expect(arranged.picturePreviewsInDayOrder.count == 3)
        #expect(arranged.picturePreviewsInDayOrder.map(Optional.some) == expectedPreviews)
    }

    @Test func movingFromAnEmptySlotFailsAsNoPictureToMoveWithoutStoringAnything() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])

        await #expect(throws: ArrangePicturesError.noPictureToMove(.dawn)) {
            try await arrange(.movePicture(from: .dawn, to: .midday), in: wallpaper.id, library: library)
        }
        #expect(await receivedAKeep(library) == false)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func movingAPictureMadeWithAIFailsAsCannotBeMovedWithoutStoringAnything() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .madeWithAI])

        await #expect(throws: ArrangePicturesError.pictureMadeWithAICannotBeMoved(.night)) {
            try await arrange(.movePicture(from: .night, to: .midday), in: wallpaper.id, library: library)
        }
        #expect(await receivedAKeep(library) == false)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func arrangingAWallpaperThatIsNotInTheLibraryFailsAsGone() async throws {
        let library = WallpaperLibraryStandIn()

        await #expect(throws: ArrangePicturesError.wallpaperGone) {
            try await arrange(.placeByTimeAgain, in: WallpaperID(UUID()), library: library)
        }
        #expect(await receivedAKeep(library) == false)
    }

    @Test func aLibraryThatCannotReadTheWallpaperFailsAsUnavailableAndStoresNothing() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])
        await library.fail(.wallpaper, with: .unexpected(description: "disk vanished"))

        await #expect(throws: ArrangePicturesError.unavailable(description: "disk vanished")) {
            try await arrange(.removePicture(from: .morning), in: wallpaper.id, library: library)
        }
        #expect(await receivedAKeep(library) == false)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func aLibraryThatCannotKeepTheWallpaperFailsAsUnavailableAndTheStoredWallpaperIsUnchanged() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.morning: .imported, .night: .imported])
        await library.fail(.keep, with: .unexpected(description: "disk full of surprises"))

        await #expect(throws: ArrangePicturesError.unavailable(description: "disk full of surprises")) {
            try await arrange(.movePicture(from: .morning, to: .afternoon), in: wallpaper.id, library: library)
        }
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func noChangeAsksTheLibraryToDiscardPictures() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(
            in: library,
            holding: [.morning: .imported, .midday: .imported, .night: .imported],
        )
        let firstArrangement = wallpaper.arrangement

        _ = try await arrange(.movePicture(from: .morning, to: .afternoon), in: wallpaper.id, library: library)
        _ = try await arrange(.removePicture(from: .midday), in: wallpaper.id, library: library)
        _ = try await arrange(.placeByTimeAgain, in: wallpaper.id, library: library)
        _ = try await arrange(.goBack(to: firstArrangement), in: wallpaper.id, library: library)

        #expect(await receivedADiscard(library) == false)
    }
}
