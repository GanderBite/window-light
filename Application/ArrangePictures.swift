import Domain
import Foundation

public struct ArrangePictures: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute(
        _ change: ArrangementChange,
        in wallpaper: WallpaperID,
    ) async throws(ArrangePicturesError) -> WallpaperInLibrary {
        let storedWallpaper = try await self.wallpaper(wallpaper)
        let arrangedWallpaper = try Self.wallpaper(storedWallpaper, arrangedBy: change)
        do throws(WallpaperLibraryError) {
            try await library.keep(arrangedWallpaper)
            let previews = try await library.picturePreviews(of: arrangedWallpaper.id)
            return try WallpaperInLibrary(wallpaper: arrangedWallpaper, previewsByPicture: previews)
        } catch {
            throw Self.arrangePicturesError(for: error)
        }
    }

    private func wallpaper(_ wallpaperID: WallpaperID) async throws(ArrangePicturesError) -> Wallpaper {
        do throws(WallpaperLibraryError) {
            return try await library.wallpaper(wallpaperID)
        } catch {
            throw Self.arrangePicturesError(for: error)
        }
    }

    private static func wallpaper(
        _ storedWallpaper: Wallpaper,
        arrangedBy change: ArrangementChange,
    ) throws(ArrangePicturesError) -> Wallpaper {
        var arrangedWallpaper = storedWallpaper
        do throws(WallpaperError) {
            switch change {
            case let .movePicture(source, destination):
                try arrangedWallpaper.movePicture(from: source, to: destination)
            case let .removePicture(slot):
                arrangedWallpaper.removePicture(from: slot)
            case .placeByTimeAgain:
                arrangedWallpaper.placeRealPicturesByTimeAgain()
            case let .goBack(arrangement):
                arrangedWallpaper.rearrange(as: arrangement)
            }
        } catch {
            throw arrangePicturesError(for: error)
        }
        return arrangedWallpaper
    }

    private static func arrangePicturesError(for libraryError: WallpaperLibraryError) -> ArrangePicturesError {
        switch libraryError {
        case .notFound: .wallpaperGone
        case .notPermitted, .noSpaceLeft, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }

    private static func arrangePicturesError(for wallpaperError: WallpaperError) -> ArrangePicturesError {
        switch wallpaperError {
        case let .noPictureToMove(slot): .noPictureToMove(slot)
        case let .pictureMadeWithAICannotBeMoved(slot): .pictureMadeWithAICannotBeMoved(slot)
        case .pictureInTwoSlots, .tooFewFilesToCreate, .tooManyFilesToCreate, .noEmptySlot,
             .moreFilesThanEmptySlots, .slotHoldsRealPicture, .identicalPictureAlreadyInWallpaper:
            .unavailable(description: wallpaperError.descriptionOfTheBrokenRule)
        }
    }
}

public enum ArrangementChange: Equatable, Sendable {
    case movePicture(from: Slot, to: Slot)
    case removePicture(from: Slot)
    case placeByTimeAgain
    case goBack(to: Arrangement)
}

public enum ArrangePicturesError: Error, Equatable, Sendable {
    case wallpaperGone
    case noPictureToMove(Slot)
    case pictureMadeWithAICannotBeMoved(Slot)
    case unavailable(description: String)
}
