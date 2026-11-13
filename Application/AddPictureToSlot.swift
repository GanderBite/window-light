import Domain
import Foundation

public struct AddPictureToSlot: Sendable {
    private let library: any WallpaperLibrary
    private let pictureImport: PictureImport

    public init(library: any WallpaperLibrary, previews: any PicturePreviews, files: any PictureFiles) {
        self.library = library
        pictureImport = PictureImport(files: files, previews: previews)
    }

    public func execute(
        file chosenFile: URL,
        to wallpaperID: WallpaperID,
        in slot: Slot,
    ) async throws(AddPictureToSlotError) -> PictureAddition {
        let storedWallpaper = try await wallpaper(wallpaperID)
        try Self.check(storedWallpaper, canTakeAFileInto: slot)
        let importedFiles = await pictureImport.read([chosenFile], besidesPicturesIn: storedWallpaper)
        guard importedFiles.holdsAPicture else {
            return PictureAddition(wallpaper: storedWallpaper, summary: importedFiles.summaryWithNothingStored)
        }

        var keptWallpaper = storedWallpaper
        let summary = try await importedFiles.storePictureByPicture(
            into: [slot],
        ) { imported, slot throws(AddPictureToSlotError) -> PictureStoringOutcome in
            let changedWallpaper = try Self.wallpaper(storedWallpaper, with: imported.picture, in: slot)
            let outcome = try await keep(changedWallpaper, adding: imported)
            if outcome == .stored {
                keptWallpaper = changedWallpaper
            }
            return outcome
        }
        return PictureAddition(wallpaper: keptWallpaper, summary: summary)
    }

    private func wallpaper(_ wallpaperID: WallpaperID) async throws(AddPictureToSlotError) -> Wallpaper {
        do throws(WallpaperLibraryError) {
            return try await library.wallpaper(wallpaperID)
        } catch {
            throw Self.addPictureToSlotError(for: error)
        }
    }

    private static func check(
        _ wallpaper: Wallpaper,
        canTakeAFileInto slot: Slot,
    ) throws(AddPictureToSlotError) {
        do throws(WallpaperError) {
            try wallpaper.checkCanTakeAFile(into: slot)
        } catch {
            throw addPictureToSlotError(for: error)
        }
    }

    private static func wallpaper(
        _ storedWallpaper: Wallpaper,
        with picture: Picture,
        in slot: Slot,
    ) throws(AddPictureToSlotError) -> Wallpaper {
        var changedWallpaper = storedWallpaper
        do throws(WallpaperError) {
            try changedWallpaper.place(picture, in: slot)
        } catch {
            throw addPictureToSlotError(for: error)
        }
        return changedWallpaper
    }

    private func keep(
        _ changedWallpaper: Wallpaper,
        adding imported: ImportedPicture,
    ) async throws(AddPictureToSlotError) -> PictureStoringOutcome {
        do throws(WallpaperLibraryError) {
            try await library.keep(
                changedWallpaper,
                addingPictureContents: imported.contentByPicture,
                addingPicturePreviews: imported.previewByPicture,
            )
            return .stored
        } catch .noSpaceLeft {
            return .noSpaceLeft
        } catch {
            throw Self.addPictureToSlotError(for: error)
        }
    }

    private static func addPictureToSlotError(for libraryError: WallpaperLibraryError) -> AddPictureToSlotError {
        switch libraryError {
        case .notFound: .wallpaperGone
        case .notPermitted, .noSpaceLeft, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }

    private static func addPictureToSlotError(for wallpaperError: WallpaperError) -> AddPictureToSlotError {
        switch wallpaperError {
        case let .slotHoldsRealPicture(slot): .slotHoldsRealPicture(slot)
        case .pictureInTwoSlots, .tooFewFilesToCreate, .tooManyFilesToCreate, .noEmptySlot,
             .moreFilesThanEmptySlots, .identicalPictureAlreadyInWallpaper, .noPictureToMove,
             .pictureMadeWithAICannotBeMoved:
            .unavailable(description: wallpaperError.descriptionOfTheBrokenRule)
        }
    }
}

public enum AddPictureToSlotError: Error, Equatable, Sendable {
    case wallpaperGone
    case slotHoldsRealPicture(Slot)
    case unavailable(description: String)
}
