import Application
import Domain
import Foundation

actor WallpaperLibraryStandIn: WallpaperLibrary {
    enum Call: Hashable {
        case wallpapers
        case wallpaper(WallpaperID)
        case picturePreviews(WallpaperID)
        case add(WallpaperID)
        case keep(WallpaperID)
        case remove(WallpaperID)
        case wallpaperLastWorkedOn
        case rememberAsLastWorkedOn(WallpaperID)
    }

    enum CallKind: Hashable {
        case wallpapers, wallpaper, picturePreviews, add, keep, remove, wallpaperLastWorkedOn, rememberAsLastWorkedOn
    }

    private(set) var storedWallpapers: [Wallpaper] = []
    private(set) var storedPictureContents: [PictureID: Data] = [:]
    private(set) var storedPicturePreviews: [PictureID: Data] = [:]
    private var rememberedLastWorkedOn: WallpaperID?
    private(set) var receivedCalls: [Call] = []
    private var failures: [CallKind: WallpaperLibraryError] = [:]

    var lastWorkedOn: WallpaperID? {
        guard let rememberedLastWorkedOn, holds(rememberedLastWorkedOn) else { return nil }

        return rememberedLastWorkedOn
    }

    var receivedAnAdd: Bool {
        receivedCalls.contains { call in
            if case .add = call {
                return true
            }
            return false
        }
    }

    func fail(_ kind: CallKind, with error: WallpaperLibraryError) {
        failures[kind] = error
    }

    func failEveryCall(with error: WallpaperLibraryError) {
        for kind in [
            CallKind.wallpapers,
            .wallpaper,
            .picturePreviews,
            .add,
            .keep,
            .remove,
            .wallpaperLastWorkedOn,
            .rememberAsLastWorkedOn,
        ] {
            failures[kind] = error
        }
    }

    func wallpapers() async throws(WallpaperLibraryError) -> [Wallpaper] {
        try receive(.wallpapers, of: .wallpapers)
        return storedWallpapers
    }

    func wallpaper(_ id: WallpaperID) async throws(WallpaperLibraryError) -> Wallpaper {
        try receive(.wallpaper(id), of: .wallpaper)
        guard let found = storedWallpapers.first(where: { $0.id == id }) else { throw .notFound }

        return found
    }

    func picturePreviews(of wallpaper: WallpaperID) async throws(WallpaperLibraryError) -> [PictureID: Data] {
        try receive(.picturePreviews(wallpaper), of: .picturePreviews)
        guard let found = storedWallpapers.first(where: { $0.id == wallpaper }) else { throw .notFound }

        var previews: [PictureID: Data] = [:]
        for picture in found.picturesInDayOrder {
            previews[picture.id] = storedPicturePreviews[picture.id]
        }
        return previews
    }

    func add(
        _ wallpaper: Wallpaper,
        pictureContents: [PictureID: Data],
        picturePreviews: [PictureID: Data],
    ) async throws(WallpaperLibraryError) {
        try receive(.add(wallpaper.id), of: .add)
        let pictureIDs = wallpaper.picturesInDayOrder.map(\.id)
        guard pictureIDs.allSatisfy({ pictureContents[$0] != nil && picturePreviews[$0] != nil }) else {
            throw .unexpected(description: "A picture has no content or no preview.")
        }

        storedWallpapers.append(wallpaper)
        for pictureID in pictureIDs {
            storedPictureContents[pictureID] = pictureContents[pictureID]
            storedPicturePreviews[pictureID] = picturePreviews[pictureID]
        }
    }

    func keep(_ wallpaper: Wallpaper) async throws(WallpaperLibraryError) {
        try receive(.keep(wallpaper.id), of: .keep)
        guard let index = storedWallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { throw .notFound }

        storedWallpapers[index] = wallpaper
    }

    func remove(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try receive(.remove(wallpaper), of: .remove)
        guard let index = storedWallpapers.firstIndex(where: { $0.id == wallpaper }) else { return }

        for picture in storedWallpapers[index].picturesInDayOrder {
            storedPictureContents[picture.id] = nil
            storedPicturePreviews[picture.id] = nil
        }
        storedWallpapers.remove(at: index)
    }

    func wallpaperLastWorkedOn() async throws(WallpaperLibraryError) -> WallpaperID? {
        try receive(.wallpaperLastWorkedOn, of: .wallpaperLastWorkedOn)
        return lastWorkedOn
    }

    func rememberAsLastWorkedOn(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try receive(.rememberAsLastWorkedOn(wallpaper), of: .rememberAsLastWorkedOn)
        guard holds(wallpaper) else { throw .notFound }

        rememberedLastWorkedOn = wallpaper
    }

    private func holds(_ wallpaper: WallpaperID) -> Bool {
        storedWallpapers.contains { $0.id == wallpaper }
    }

    private func receive(_ call: Call, of kind: CallKind) throws(WallpaperLibraryError) {
        receivedCalls.append(call)
        if let failure = failures[kind] {
            throw failure
        }
    }
}
