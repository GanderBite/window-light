import Domain
import Foundation

public struct AddPictures: Sendable {
    private let library: any WallpaperLibrary
    private let pictureImport: PictureImport

    public init(library: any WallpaperLibrary, previews: any PicturePreviews, files: any PictureFiles) {
        self.library = library
        pictureImport = PictureImport(files: files, previews: previews)
    }

    public func execute(
        files chosenFiles: [URL],
        to wallpaperID: WallpaperID,
    ) async throws(AddPicturesError) -> PictureAddition {
        let storedWallpaper = try await wallpaper(wallpaperID)
        try Self.check(storedWallpaper, canTake: chosenFiles.count)
        let importedFiles = await pictureImport.read(chosenFiles, besidesPicturesIn: storedWallpaper)
        guard importedFiles.holdsAPicture else {
            return PictureAddition(wallpaper: storedWallpaper, summary: importedFiles.summaryWithNothingStored)
        }

        let placements = try Self.placement(of: importedFiles.pictures, in: storedWallpaper)
        var keptWallpaper = storedWallpaper
        let summary = try await importedFiles.storePictureByPicture(
            placedAs: placements,
        ) { imported, slot throws(AddPicturesError) -> PictureStoringOutcome in
            let grownWallpaper = try Self.wallpaper(keptWallpaper, grownBy: imported.picture, in: slot)
            let outcome = try await keep(grownWallpaper, adding: imported)
            if outcome == .stored {
                keptWallpaper = grownWallpaper
            }
            return outcome
        }
        return PictureAddition(wallpaper: keptWallpaper, summary: summary)
    }

    private func wallpaper(_ wallpaperID: WallpaperID) async throws(AddPicturesError) -> Wallpaper {
        do throws(WallpaperLibraryError) {
            return try await library.wallpaper(wallpaperID)
        } catch {
            throw Self.addPicturesError(for: error)
        }
    }

    private static func check(_ wallpaper: Wallpaper, canTake fileCount: Int) throws(AddPicturesError) {
        do throws(WallpaperError) {
            try wallpaper.checkCanTake(fileCount: fileCount)
        } catch {
            throw addPicturesError(for: error)
        }
    }

    private static func placement(
        of pictures: [Picture],
        in wallpaper: Wallpaper,
    ) throws(AddPicturesError) -> [PlacedPicture] {
        do throws(WallpaperError) {
            return try wallpaper.automaticPlacement(of: pictures)
        } catch {
            throw addPicturesError(for: error)
        }
    }

    private static func wallpaper(
        _ keptWallpaper: Wallpaper,
        grownBy picture: Picture,
        in slot: Slot,
    ) throws(AddPicturesError) -> Wallpaper {
        var grownWallpaper = keptWallpaper
        do throws(WallpaperError) {
            try grownWallpaper.place(picture, in: slot)
        } catch {
            throw addPicturesError(for: error)
        }
        return grownWallpaper
    }

    private func keep(
        _ grownWallpaper: Wallpaper,
        adding imported: ImportedPicture,
    ) async throws(AddPicturesError) -> PictureStoringOutcome {
        do throws(WallpaperLibraryError) {
            try await library.keep(
                grownWallpaper,
                addingPictureContents: imported.contentByPicture,
                addingPicturePreviews: imported.previewByPicture,
            )
            return .stored
        } catch .noSpaceLeft {
            return .noSpaceLeft
        } catch {
            throw Self.addPicturesError(for: error)
        }
    }

    private static func addPicturesError(for libraryError: WallpaperLibraryError) -> AddPicturesError {
        switch libraryError {
        case .notFound: .wallpaperGone
        case .notPermitted, .noSpaceLeft, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }

    private static func addPicturesError(for wallpaperError: WallpaperError) -> AddPicturesError {
        switch wallpaperError {
        case .noEmptySlot: .noEmptySlot
        case let .moreFilesThanEmptySlots(emptySlots): .moreFilesThanEmptySlots(emptySlots: emptySlots)
        case .noPictures, .pictureInTwoSlots, .tooFewFilesToCreate, .tooManyFilesToCreate, .slotHoldsRealPicture,
             .identicalPictureAlreadyInWallpaper:
            .unavailable(description: wallpaperError.descriptionOfTheBrokenRule)
        }
    }
}

public struct PictureAddition: Equatable, Sendable {
    public let wallpaper: Wallpaper
    public let summary: ImportSummary
}

public enum AddPicturesError: Error, Equatable, Sendable {
    case wallpaperGone
    case noEmptySlot
    case moreFilesThanEmptySlots(emptySlots: Int)
    case unavailable(description: String)
}
