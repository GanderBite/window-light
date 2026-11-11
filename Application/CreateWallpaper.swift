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
        pictureContentsBySlot: [Slot: Data],
        defaultNameStem: String,
    ) async throws(CreateWallpaperError) -> Wallpaper {
        let name = try await unusedDefaultName(startingWith: defaultNameStem)
        let picturesBySlot = pictureContentsBySlot.mapValues { _ in Picture(id: PictureID(UUID())) }
        let wallpaper = try Self.newWallpaper(named: name, pictures: picturesBySlot)
        var pictureContents: [PictureID: Data] = [:]
        var picturePreviews: [PictureID: Data] = [:]
        for slot in Slot.allCases {
            guard let picture = picturesBySlot[slot], let content = pictureContentsBySlot[slot] else { continue }

            pictureContents[picture.id] = content
            picturePreviews[picture.id] = try await preview(of: content, in: slot)
        }
        do throws(WallpaperLibraryError) {
            try await library.add(wallpaper, pictureContents: pictureContents, picturePreviews: picturePreviews)
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
            case .pictureInTwoSlots: throw .unavailable(description: "A new picture was given to two slots.")
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
