import Domain
import Foundation

public struct OpenLibrary: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute() async throws(OpenLibraryError) -> LibraryContents {
        do throws(WallpaperLibraryError) {
            var wallpapersInLibrary: [WallpaperInLibrary] = []
            for wallpaper in try await library.wallpapers() {
                let previews = try await library.picturePreviews(of: wallpaper.id)
                wallpapersInLibrary.append(try Self.entry(for: wallpaper, withPreviews: previews))
            }
            let wallpaperLastWorkedOn = try await library.wallpaperLastWorkedOn()
            return LibraryContents(wallpapers: wallpapersInLibrary, wallpaperLastWorkedOn: wallpaperLastWorkedOn)
        } catch {
            throw Self.openLibraryError(for: error)
        }
    }

    private static func entry(
        for wallpaper: Wallpaper,
        withPreviews previewsByPicture: [PictureID: Data]
    ) throws(WallpaperLibraryError) -> WallpaperInLibrary {
        var previewsInDayOrder: [Data] = []
        for picture in wallpaper.picturesInDayOrder {
            guard let preview = previewsByPicture[picture.id] else {
                throw .unexpected(description: "The wallpaper library has no preview of a picture of a wallpaper.")
            }
            previewsInDayOrder.append(preview)
        }
        return WallpaperInLibrary(wallpaper: wallpaper, picturePreviewsInDayOrder: previewsInDayOrder)
    }

    private static func openLibraryError(for libraryError: WallpaperLibraryError) -> OpenLibraryError {
        switch libraryError {
        case .unreadable: .unreadable
        case .notFound, .notPermitted, .noSpaceLeft, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }
}

public struct LibraryContents: Sendable {
    public let wallpapers: [WallpaperInLibrary]
    public let wallpaperLastWorkedOn: WallpaperID?
}

public struct WallpaperInLibrary: Identifiable, Sendable {
    public let wallpaper: Wallpaper
    public let picturePreviewsInDayOrder: [Data]

    public var id: WallpaperID {
        wallpaper.id
    }
}

public enum OpenLibraryError: Error, Equatable, Sendable {
    case unreadable
    case unavailable(description: String)
}
