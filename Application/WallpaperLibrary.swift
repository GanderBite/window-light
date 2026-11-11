import Domain
import Foundation

public protocol WallpaperLibrary: Sendable {
    func wallpapers() async throws(WallpaperLibraryError) -> [Wallpaper]
    func wallpaper(_ id: WallpaperID) async throws(WallpaperLibraryError) -> Wallpaper
    func picturePreviews(of wallpaper: WallpaperID) async throws(WallpaperLibraryError) -> [PictureID: Data]
    func add(
        _ wallpaper: Wallpaper,
        pictureContents: [PictureID: Data],
        picturePreviews: [PictureID: Data]
    ) async throws(WallpaperLibraryError)
    func keep(_ wallpaper: Wallpaper) async throws(WallpaperLibraryError)
    func remove(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError)
    func wallpaperLastWorkedOn() async throws(WallpaperLibraryError) -> WallpaperID?
    func rememberAsLastWorkedOn(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError)
}

public enum WallpaperLibraryError: Error, Equatable, Sendable {
    case notFound
    case notPermitted
    case noSpaceLeft
    case unreadable
    case unavailable
    case unexpected(description: String)
}

extension WallpaperLibraryError {
    var causeDescription: String {
        switch self {
        case .notFound: "The wallpaper library has no such wallpaper."
        case .notPermitted: "The wallpaper library may not be used."
        case .noSpaceLeft: "There is no space left for the wallpaper library."
        case .unreadable: "The wallpaper library cannot be read."
        case .unavailable: "The wallpaper library is unavailable."
        case .unexpected(let description): description
        }
    }
}
