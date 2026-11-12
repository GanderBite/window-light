import Application
import Domain
import Foundation
import Testing

private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/Users/someone/Pictures/\(name)")
}

private func content(of name: String) -> Data {
    Data("content of \(name)".utf8)
}

private func fingerprint(of name: String) throws -> ContentFingerprint {
    try ContentFingerprint("fingerprint of \(name)")
}

private func pictureFile(
    _ name: String,
    captureTime: CaptureTime? = nil,
    width: Int = PixelSize.sharpDesktopWidth,
    height: Int = PixelSize.sharpDesktopHeight,
) throws -> PictureFile {
    try PictureFile(
        content: content(of: name),
        fingerprint: fingerprint(of: name),
        captureTime: captureTime,
        pixelSize: PixelSize(width: width, height: height),
    )
}

private func nameOfPicture(heldIn slot: Slot) -> String {
    "held in \(slot).jpg"
}

private func storedWallpaper(
    in library: WallpaperLibraryStandIn,
    holding origins: [Slot: PictureOrigin],
) async throws -> Wallpaper {
    var pictures: [Slot: Domain.Picture] = [:]
    var contents: [PictureID: Data] = [:]
    for (slot, origin) in origins {
        let name = nameOfPicture(heldIn: slot)
        let picture = try Domain.Picture(
            id: PictureID(UUID()),
            origin: origin,
            captureTime: nil,
            fingerprint: fingerprint(of: name),
        )
        pictures[slot] = picture
        contents[picture.id] = content(of: name)
    }
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
    try await library.add(
        wallpaper,
        pictureContents: contents,
        picturePreviews: contents.mapValues(PicturePreviewsStandIn.preview(of:)),
    )
    return wallpaper
}

private func add(
    _ name: String,
    answer: Result<PictureFile, PictureFileError>,
    to wallpaper: WallpaperID,
    in slot: Slot,
    library: WallpaperLibraryStandIn,
) async throws -> PictureAddition {
    try await AddPictureToSlot(
        library: library,
        previews: PicturePreviewsStandIn(),
        files: PictureFilesStandIn(answering: [file(name): answer]),
    )
    .execute(file: file(name), to: wallpaper, in: slot)
}

private func receivedAKeep(_ library: WallpaperLibraryStandIn) async -> Bool {
    await library.receivedCalls.contains { call in
        switch call {
        case .keep, .keepAdding: true
        default: false
        }
    }
}

struct AddPictureToSlotTests {
    @Test func aFileTakenAtElevenAtNightAddedIntoAnEmptyDawnIsInDawn() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])
        let lateEvening = try CaptureTime(year: 2026, month: 6, day: 21, hour: 23, minute: 0, second: 0)

        let addition = try await add(
            "late.jpg",
            answer: .success(pictureFile("late.jpg", captureTime: lateEvening)),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        let added = try #require(addition.wallpaper.picture(in: .dawn))
        #expect(try added.fingerprint == fingerprint(of: "late.jpg"))
        #expect(added.captureTime == lateEvening)
        #expect(addition.wallpaper.picture(in: .night) == wallpaper.picture(in: .night))
        #expect(addition.summary.addedPictureCount == 1)
        #expect(await library.storedWallpapers == [addition.wallpaper])
        #expect(await library.storedPictureContents[added.id] == content(of: "late.jpg"))
    }

    @Test func aFileAddedIntoDawnHoldingAnAIPictureReplacesItAndTheLibraryForgetsItsFiles() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.dawn: .madeWithAI, .night: .imported])
        let aiPicture = try #require(wallpaper.picture(in: .dawn))

        let addition = try await add(
            "real.jpg",
            answer: .success(pictureFile("real.jpg")),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        #expect(try addition.wallpaper.picture(in: .dawn)?.fingerprint == fingerprint(of: "real.jpg"))
        #expect(addition.wallpaper.picturesInDayOrder.contains(aiPicture) == false)
        #expect(addition.wallpaper.filledSlotCount == 2)
        #expect(await library.storedWallpapers == [addition.wallpaper])
        #expect(await library.storedPictureContents[aiPicture.id] == nil)
        #expect(await library.storedPicturePreviews[aiPicture.id] == nil)
    }

    @Test func aFileForDawnHoldingARealPictureIsRefusedWithoutReadingItOrWritingTheLibrary() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.dawn: .imported])
        let files = try PictureFilesStandIn(answering: [file("new.jpg"): .success(pictureFile("new.jpg"))])

        await #expect(throws: AddPictureToSlotError.slotHoldsRealPicture(.dawn)) {
            try await AddPictureToSlot(library: library, previews: PicturePreviewsStandIn(), files: files)
                .execute(file: file("new.jpg"), to: wallpaper.id, in: .dawn)
        }
        #expect(await files.askedFiles.isEmpty)
        #expect(await receivedAKeep(library) == false)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func aDamagedFileAddedIntoAnEmptySlotLeavesTheWallpaperUnchangedAndIsNamed() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])

        let addition = try await add(
            "broken.jpg",
            answer: .failure(.damaged),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        #expect(addition.wallpaper == wallpaper)
        #expect(addition.summary.addedPictureCount == 0)
        #expect(addition.summary.skippedFiles.map(\.name) == ["broken.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.damaged])
        #expect(await receivedAKeep(library) == false)
    }

    @Test func aFileIdenticalToAPictureInTheWallpaperIsSkippedAndTheWallpaperIsUnchanged() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])
        let copyName = nameOfPicture(heldIn: .night)

        let addition = try await add(
            copyName,
            answer: .success(pictureFile(copyName)),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        #expect(addition.wallpaper == wallpaper)
        #expect(addition.summary.skippedFiles.map(\.reason) == [.alreadyInWallpaper])
        #expect(await receivedAKeep(library) == false)
    }

    @Test func addingToAWallpaperThatIsNotInTheLibraryFailsAsGone() async throws {
        let library = WallpaperLibraryStandIn()

        await #expect(throws: AddPictureToSlotError.wallpaperGone) {
            try await add(
                "new.jpg",
                answer: .success(pictureFile("new.jpg")),
                to: WallpaperID(UUID()),
                in: .dawn,
                library: library,
            )
        }
    }

    @Test func noSpaceLeftSkipsTheFileSaysTheImportStoppedAndLeavesTheWallpaperUnchanged() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])
        await library.fail(.keepAdding, with: .noSpaceLeft)

        let addition = try await add(
            "new.jpg",
            answer: .success(pictureFile("new.jpg")),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        #expect(addition.wallpaper == wallpaper)
        #expect(addition.summary.addedPictureCount == 0)
        #expect(addition.summary.skippedFiles.map(\.name) == ["new.jpg"])
        #expect(addition.summary.skippedFiles.map(\.reason) == [.noSpaceLeft])
        #expect(addition.summary.stoppedForLackOfSpace)
        #expect(await library.storedWallpapers == [wallpaper])
    }

    @Test func aFileTooSmallForTheDesktopIsAddedAndNamedAsMayLookBlurry() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])

        let addition = try await add(
            "small.jpg",
            answer: .success(pictureFile("small.jpg", width: 1280, height: 720)),
            to: wallpaper.id,
            in: .dawn,
            library: library,
        )

        #expect(addition.summary.addedPictureCount == 1)
        #expect(addition.summary.filesThatMayLookBlurry == ["small.jpg"])
    }

    @Test func aLibraryThatCannotKeepThePictureFailsAsUnavailable() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await storedWallpaper(in: library, holding: [.night: .imported])
        await library.fail(.keepAdding, with: .unexpected(description: "disk vanished"))

        await #expect(throws: AddPictureToSlotError.unavailable(description: "disk vanished")) {
            try await add(
                "new.jpg",
                answer: .success(pictureFile("new.jpg")),
                to: wallpaper.id,
                in: .dawn,
                library: library,
            )
        }
    }
}
