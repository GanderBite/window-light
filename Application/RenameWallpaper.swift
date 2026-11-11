import Domain
import Foundation

public struct RenameWallpaper: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    public func execute(
        _ wallpaper: WallpaperID,
        to proposedName: String,
    ) async throws(RenameWallpaperError) -> Wallpaper {
        let newName = try Self.name(from: proposedName)
        do throws(WallpaperLibraryError) {
            var renamed = try await library.wallpaper(wallpaper)
            renamed.rename(to: newName)
            try await library.keep(renamed)
            return renamed
        } catch {
            throw Self.renameWallpaperError(for: error)
        }
    }

    private static func name(from proposedName: String) throws(RenameWallpaperError) -> WallpaperName {
        do throws(WallpaperNameError) {
            return try WallpaperName(proposedName)
        } catch {
            switch error {
            case .empty: throw .nameEmpty
            case let .tooLong(limit): throw .nameTooLong(limit: limit)
            }
        }
    }

    private static func renameWallpaperError(for libraryError: WallpaperLibraryError) -> RenameWallpaperError {
        switch libraryError {
        case .notFound: .wallpaperGone
        case .noSpaceLeft: .noSpaceLeft
        case .notPermitted, .unreadable, .unavailable, .unexpected:
            .unavailable(description: libraryError.causeDescription)
        }
    }
}

public enum RenameWallpaperError: Error, Equatable, Sendable {
    case nameEmpty
    case nameTooLong(limit: Int)
    case wallpaperGone
    case noSpaceLeft
    case unavailable(description: String)
}
