import Domain
import Foundation

public struct CreateWallpaper: Sendable {
    private let library: any WallpaperLibrary
    private let previews: any PicturePreviews

    public init(library: any WallpaperLibrary, previews: any PicturePreviews) {
        self.library = library
        self.previews = previews
    }

    public func execute(
        picturesBySlot: [Slot: Picture],
        pictureContents: [PictureID: Data],
        defaultNameStem: String,
    ) async throws(CreateWallpaperError) -> Wallpaper {
        let name = try await unusedDefaultName(startingWith: defaultNameStem)
        let wallpaper = try Self.newWallpaper(named: name, pictures: picturesBySlot)
        var contentsOfPictures: [PictureID: Data] = [:]
        var picturePreviews: [PictureID: Data] = [:]
        for slot in Slot.allCases {
            guard let picture = picturesBySlot[slot] else { continue }
            guard let content = pictureContents[picture.id] else {
                throw .unavailable(description: "The picture in \(slot) was given without its content.")
            }

            contentsOfPictures[picture.id] = content
            picturePreviews[picture.id] = try await preview(of: content, in: slot)
        }
        do throws(WallpaperLibraryError) {
            try await library.add(wallpaper, pictureContents: contentsOfPictures, picturePreviews: picturePreviews)
        } catch {
            throw Self.libraryError(for: error)
        }
        return wallpaper
    }

    private func unusedDefaultName(startingWith stem: String) async throws(CreateWallpaperError) -> WallpaperName {
        let wallpapersInLibrary: [Wallpaper]
        do throws(WallpaperLibraryError) {
            wallpapersInLibrary = try await library.wallpapers()
        } catch {
            throw Self.libraryError(for: error)
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

    private static func newWallpaper(
        named name: WallpaperName,
        pictures: [Slot: Picture],
    ) throws(CreateWallpaperError) -> Wallpaper {
        do throws(WallpaperError) {
            return try Wallpaper(id: WallpaperID(UUID()), name: name, pictures: pictures)
        } catch {
            switch error {
            case .noPictures: throw .noPictures
            case .pictureInTwoSlots: throw .unavailable(description: "A picture was given to two slots.")
            case .tooFewFilesToCreate:
                throw .unavailable(description: "A wallpaper was created from fewer files than it needs.")
            case .tooManyFilesToCreate:
                throw .unavailable(description: "A wallpaper was created from more files than it has slots.")
            case .noEmptySlot: throw .unavailable(description: "A picture was given to a wallpaper with no empty slot.")
            case .moreFilesThanEmptySlots:
                throw .unavailable(description: "More pictures were given than the wallpaper has empty slots.")
            case .slotHoldsRealPicture:
                throw .unavailable(description: "A picture was given to a slot that holds a real picture.")
            case .identicalPictureAlreadyInWallpaper:
                throw .unavailable(description: "Two identical pictures were given to one wallpaper.")
            }
        }
    }

    private func preview(of content: Data, in slot: Slot) async throws(CreateWallpaperError) -> Data {
        do throws(PicturePreviewError) {
            return try await previews.preview(ofPictureWith: content)
        } catch {
            switch error {
            case .unreadable: throw .unreadablePicture(in: slot)
            case let .unexpected(description): throw .unavailable(description: description)
            }
        }
    }

    private static func libraryError(for libraryError: WallpaperLibraryError) -> CreateWallpaperError {
        switch libraryError {
        case .noSpaceLeft: .noSpaceLeft
        case .notFound, .notPermitted, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }
}

public enum CreateWallpaperError: Error, Equatable, Sendable {
    case noPictures
    case defaultNameTooLong(limit: Int)
    case unreadablePicture(in: Slot)
    case noSpaceLeft
    case unavailable(description: String)
}
