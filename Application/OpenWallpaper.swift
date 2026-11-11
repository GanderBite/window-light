import Domain
import Foundation

public struct OpenWallpaper: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute(_ wallpaper: WallpaperID) async throws(OpenWallpaperError) -> Wallpaper {
        do throws(WallpaperLibraryError) {
            let opened = try await library.wallpaper(wallpaper)
            try await library.rememberAsLastWorkedOn(wallpaper)
            return opened
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
