import Domain
import Foundation

public struct DeleteWallpaper: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute(_ wallpaper: WallpaperID) async throws(DeleteWallpaperError) {
        do throws(WallpaperLibraryError) {
            try await library.remove(wallpaper)
        } catch {
            throw .unavailable(description: error.causeDescription)
        }
    }
}

public enum DeleteWallpaperError: Error, Equatable, Sendable {
    case unavailable(description: String)
}
