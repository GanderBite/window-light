import Application
import Domain
import Foundation

actor WallpaperLibraryStandIn: WallpaperLibrary {
    enum Call: Hashable, Sendable {
        case wallpapers
        case wallpaper(WallpaperID)
        case picturePreviews(WallpaperID)
        case add(WallpaperID)
        case keep(WallpaperID)
        case remove(WallpaperID)
        case wallpaperLastWorkedOn
        case rememberAsLastWorkedOn(WallpaperID)
    }

    enum CallKind: Hashable, Sendable {
        case wallpapers, wallpaper, picturePreviews, add, keep, remove, wallpaperLastWorkedOn, rememberAsLastWorkedOn
    }

    private(set) var storedWallpapers: [Wallpaper] = []
    private var storedPicturePreviews: [PictureID: Data] = [:]
    private var rememberedLastWorkedOn: WallpaperID?
    private(set) var receivedCalls: [Call] = []
    private var failures: [CallKind: WallpaperLibraryError] = [:]
    private var actionsBeforeAnswering: [CallKind: @Sendable () async -> Void] = [:]

    var lastWorkedOn: WallpaperID? {
        guard let rememberedLastWorkedOn, holds(rememberedLastWorkedOn) else { return nil }
        return rememberedLastWorkedOn
    }

    func storedWallpaper(_ id: WallpaperID) -> Wallpaper? {
        storedWallpapers.first { $0.id == id }
    }

    func hasReceived(_ kind: CallKind) -> Bool {
        receivedCalls.contains { Self.kind(of: $0) == kind }
    }

    func fail(_ kind: CallKind, with error: WallpaperLibraryError) {
        failures[kind] = error
    }

    func failEveryCall(with error: WallpaperLibraryError) {
        for kind in [CallKind.wallpapers, .wallpaper, .picturePreviews, .add, .keep, .remove, .wallpaperLastWorkedOn, .rememberAsLastWorkedOn] {
            failures[kind] = error
        }
    }

    func workAgain() {
        failures = [:]
    }

    func beforeAnswering(_ kind: CallKind, run action: @escaping @Sendable () async -> Void) {
        actionsBeforeAnswering[kind] = action
    }

    func wallpapers() async throws(WallpaperLibraryError) -> [Wallpaper] {
        try await receive(.wallpapers)
        return storedWallpapers
    }

    func wallpaper(_ id: WallpaperID) async throws(WallpaperLibraryError) -> Wallpaper {
        try await receive(.wallpaper(id))
        guard let found = storedWallpaper(id) else { throw .notFound }
        return found
    }

    func picturePreviews(of wallpaper: WallpaperID) async throws(WallpaperLibraryError) -> [PictureID: Data] {
        try await receive(.picturePreviews(wallpaper))
        guard let found = storedWallpaper(wallpaper) else { throw .notFound }
        var previews: [PictureID: Data] = [:]
        for picture in found.picturesInDayOrder {
            previews[picture.id] = storedPicturePreviews[picture.id]
        }
        return previews
    }

    func add(
        _ wallpaper: Wallpaper,
        pictureContents: [PictureID: Data],
        picturePreviews: [PictureID: Data]
    ) async throws(WallpaperLibraryError) {
        try await receive(.add(wallpaper.id))
        let pictureIDs = wallpaper.picturesInDayOrder.map(\.id)
        guard pictureIDs.allSatisfy({ pictureContents[$0] != nil && picturePreviews[$0] != nil }) else {
            throw .unexpected(description: "A picture has no content or no preview.")
        }
        storedWallpapers.append(wallpaper)
        for pictureID in pictureIDs {
            storedPicturePreviews[pictureID] = picturePreviews[pictureID]
        }
    }

    func keep(_ wallpaper: Wallpaper) async throws(WallpaperLibraryError) {
        try await receive(.keep(wallpaper.id))
        guard let index = storedWallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { throw .notFound }
        storedWallpapers[index] = wallpaper
    }

    func remove(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try await receive(.remove(wallpaper))
        guard let index = storedWallpapers.firstIndex(where: { $0.id == wallpaper }) else { return }
        for picture in storedWallpapers[index].picturesInDayOrder {
            storedPicturePreviews[picture.id] = nil
        }
        storedWallpapers.remove(at: index)
    }

    func wallpaperLastWorkedOn() async throws(WallpaperLibraryError) -> WallpaperID? {
        try await receive(.wallpaperLastWorkedOn)
        return lastWorkedOn
    }

    func rememberAsLastWorkedOn(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        try await receive(.rememberAsLastWorkedOn(wallpaper))
        guard holds(wallpaper) else { throw .notFound }
        rememberedLastWorkedOn = wallpaper
    }

    private func holds(_ wallpaper: WallpaperID) -> Bool {
        storedWallpapers.contains { $0.id == wallpaper }
    }

    private func receive(_ call: Call) async throws(WallpaperLibraryError) {
        let kind = Self.kind(of: call)
        receivedCalls.append(call)
        if let action = actionsBeforeAnswering[kind] {
            await action()
        }
        if let failure = failures[kind] {
            throw failure
        }
    }

    private static func kind(of call: Call) -> CallKind {
        switch call {
        case .wallpapers: .wallpapers
        case .wallpaper: .wallpaper
        case .picturePreviews: .picturePreviews
        case .add: .add
        case .keep: .keep
        case .remove: .remove
        case .wallpaperLastWorkedOn: .wallpaperLastWorkedOn
        case .rememberAsLastWorkedOn: .rememberAsLastWorkedOn
        }
    }
}
