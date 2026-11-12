import Domain
import Foundation

public struct OpenWallpaper: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute(_ wallpaper: WallpaperID) async throws(OpenWallpaperError) -> WallpaperInLibrary {
        do throws(WallpaperLibraryError) {
            let opened = try await library.wallpaper(wallpaper)
            let previews = try await library.picturePreviews(of: wallpaper)
            let entry = try WallpaperInLibrary(wallpaper: opened, previewsByPicture: previews)
            try await library.rememberAsLastWorkedOn(wallpaper)
            return entry
        } catch {
            throw Self.openWallpaperError(for: error)
        }
    }

    private static func openWallpaperError(for libraryError: WallpaperLibraryError) -> OpenWallpaperError {
        switch libraryError {
        case .notFound: .wallpaperGone
        case .notPermitted, .noSpaceLeft, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }
}

public enum OpenWallpaperError: Error, Equatable, Sendable {
    case wallpaperGone
    case unavailable(description: String)
}
