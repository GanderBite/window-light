import Application
import Domain
import Foundation

struct StoredWallpaper {
    let wallpaper: Wallpaper
    let position: Int
}

struct WallpaperDocument: Codable {
    private static let currentFormatVersion = 1

    let formatVersion: Int
    let id: String
    let name: String
    let position: Int
    let pictures: [String: String]

    init(of wallpaper: Wallpaper, at position: Int) {
        formatVersion = Self.currentFormatVersion
        id = wallpaper.id.value.uuidString
        name = wallpaper.name.text
        self.position = position
        var pictures: [String: String] = [:]
        for slot in Slot.allCases {
            if let picture = wallpaper.picture(in: slot) {
                pictures[slot.storedWord] = picture.id.value.uuidString
            }
        }
        self.pictures = pictures
    }

    static func storedWallpaper(decodedFrom content: Data) throws(WallpaperLibraryError) -> StoredWallpaper {
        let document: Self
        do {
            document = try JSONDecoder().decode(Self.self, from: content)
        } catch {
            throw .unreadable
        }
        return try document.storedWallpaper()
    }

    func encoded() throws(WallpaperLibraryError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            throw .unexpected(description: "The wallpaper \(id) could not be encoded: \(error)")
        }
    }

    private func storedWallpaper() throws(WallpaperLibraryError) -> StoredWallpaper {
        guard formatVersion == Self.currentFormatVersion, let wallpaperID = UUID(uuidString: id) else {
            throw .unreadable
        }

        var picturesBySlot: [Slot: Picture] = [:]
        for (slotWord, pictureIDText) in pictures {
            guard let slot = Slot(storedWord: slotWord), let pictureID = UUID(uuidString: pictureIDText) else {
                throw .unreadable
            }

            picturesBySlot[slot] = Picture(id: PictureID(pictureID))
        }
        do {
            let wallpaper = try Wallpaper(
                id: WallpaperID(wallpaperID),
                name: WallpaperName(name),
                pictures: picturesBySlot,
            )
            return StoredWallpaper(wallpaper: wallpaper, position: position)
        } catch {
            throw .unreadable
        }
    }
}

private extension Slot {
    var storedWord: String {
        switch self {
        case .dawn: "dawn"
        case .sunrise: "sunrise"
        case .morning: "morning"
        case .midday: "midday"
        case .afternoon: "afternoon"
        case .sunset: "sunset"
        case .dusk: "dusk"
        case .night: "night"
        }
    }

    init?(storedWord: String) {
        switch storedWord {
        case "dawn": self = .dawn
        case "sunrise": self = .sunrise
        case "morning": self = .morning
        case "midday": self = .midday
        case "afternoon": self = .afternoon
        case "sunset": self = .sunset
        case "dusk": self = .dusk
        case "night": self = .night
        default: return nil
        }
    }
}
