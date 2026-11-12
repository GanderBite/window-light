import Domain
import Foundation

public struct CreateWallpaper: Sendable {
    private let library: any WallpaperLibrary
    private let pictureImport: PictureImport

    public init(library: any WallpaperLibrary, previews: any PicturePreviews, files: any PictureFiles) {
        self.library = library
        pictureImport = PictureImport(files: files, previews: previews)
    }

    public func execute(
        files chosenFiles: [URL],
        defaultNameStem: String,
    ) async throws(CreateWallpaperError) -> WallpaperCreation {
        try Self.checkCanBeCreated(fromFileCount: chosenFiles.count)
        let importedFiles = await pictureImport.read(chosenFiles, besidesPicturesIdenticalTo: [])
        guard importedFiles.holdsAPicture else {
            return WallpaperCreation(wallpaper: nil, summary: importedFiles.summaryWithNothingStored)
        }

        let placements = try Self.placementInNewWallpaper(of: importedFiles.pictures)
        let name = try await unusedDefaultName(startingWith: defaultNameStem)
        var storedWallpaper: Wallpaper?
        let summary = try await importedFiles.storePictureByPicture(
            placedAs: placements,
        ) { imported, slot throws(CreateWallpaperError) -> PictureStoringOutcome in
            let grownWallpaper = try Self.wallpaper(storedWallpaper, grownBy: imported.picture, in: slot, named: name)
            let outcome = try await store(grownWallpaper, adding: imported, toStored: storedWallpaper)
            if outcome == .stored {
                storedWallpaper = grownWallpaper
            }
            return outcome
        }
        return WallpaperCreation(wallpaper: storedWallpaper, summary: summary)
    }

    private static func checkCanBeCreated(fromFileCount count: Int) throws(CreateWallpaperError) {
        do throws(WallpaperError) {
            try Wallpaper.checkCanBeCreated(fromFileCount: count)
        } catch {
            throw createWallpaperError(for: error)
        }
    }

    private static func placementInNewWallpaper(
        of pictures: [Picture],
    ) throws(CreateWallpaperError) -> [PlacedPicture] {
        do throws(WallpaperError) {
            return try Wallpaper.automaticPlacementInNewWallpaper(of: pictures)
        } catch {
            throw createWallpaperError(for: error)
        }
    }

    private func unusedDefaultName(startingWith stem: String) async throws(CreateWallpaperError) -> WallpaperName {
        let wallpapersInLibrary: [Wallpaper]
        do throws(WallpaperLibraryError) {
            wallpapersInLibrary = try await library.wallpapers()
        } catch {
            throw .unavailable(description: error.causeDescription)
        }
        do throws(WallpaperNameError) {
            return try WallpaperName.defaultName(startingWith: stem, unusedAmong: wallpapersInLibrary.map(\.name))
        } catch {
            switch error {
            case let .tooLong(limit): throw .defaultNameTooLong(limit: limit)
            case .empty: throw .unavailable(description: "The default name of a wallpaper came out empty.")
            }
        }
    }

    private static func wallpaper(
        _ storedWallpaper: Wallpaper?,
        grownBy picture: Picture,
        in slot: Slot,
        named name: WallpaperName,
    ) throws(CreateWallpaperError) -> Wallpaper {
        do throws(WallpaperError) {
            guard var grownWallpaper = storedWallpaper else {
                return try Wallpaper(id: WallpaperID(UUID()), name: name, pictures: [slot: picture])
            }

            try grownWallpaper.place(picture, in: slot)
            return grownWallpaper
        } catch {
            throw createWallpaperError(for: error)
        }
    }

    private func store(
        _ grownWallpaper: Wallpaper,
        adding imported: ImportedPicture,
        toStored storedWallpaper: Wallpaper?,
    ) async throws(CreateWallpaperError) -> PictureStoringOutcome {
        do throws(WallpaperLibraryError) {
            if storedWallpaper == nil {
                try await library.add(
                    grownWallpaper,
                    pictureContents: imported.contentByPicture,
                    picturePreviews: imported.previewByPicture,
                )
            } else {
                try await library.keep(
                    grownWallpaper,
                    addingPictureContents: imported.contentByPicture,
                    addingPicturePreviews: imported.previewByPicture,
                )
            }
            return .stored
        } catch .noSpaceLeft {
            return .noSpaceLeft
        } catch {
            throw .unavailable(description: error.causeDescription)
        }
    }

    private static func createWallpaperError(for wallpaperError: WallpaperError) -> CreateWallpaperError {
        switch wallpaperError {
        case let .tooFewFilesToCreate(fewest): .tooFewFiles(fewest: fewest)
        case let .tooManyFilesToCreate(most): .tooManyFiles(most: most)
        case .noPictures: .unavailable(description: "A wallpaper was created without pictures.")
        case .pictureInTwoSlots: .unavailable(description: "A picture was given to two slots.")
        case .noEmptySlot: .unavailable(description: "A picture was given to a wallpaper with no empty slot.")
        case .moreFilesThanEmptySlots:
            .unavailable(description: "More pictures were given than the wallpaper has empty slots.")
        case .slotHoldsRealPicture:
            .unavailable(description: "A picture was given to a slot that holds a real picture.")
        case .identicalPictureAlreadyInWallpaper:
            .unavailable(description: "Two identical pictures were given to one wallpaper.")
        }
    }
}

public struct WallpaperCreation: Equatable, Sendable {
    public let wallpaper: Wallpaper?
    public let summary: ImportSummary
}

public enum CreateWallpaperError: Error, Equatable, Sendable {
    case tooFewFiles(fewest: Int)
    case tooManyFiles(most: Int)
    case defaultNameTooLong(limit: Int)
    case unavailable(description: String)
}
