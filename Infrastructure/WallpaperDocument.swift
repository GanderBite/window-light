import Application
import Domain
import Foundation

struct StoredWallpaper {
    let wallpaper: Wallpaper
    let position: Int
}

struct WallpaperDocument: Codable {
    private static let currentFormatVersion = 2

    let formatVersion: Int
    let id: String
    let name: String
    let position: Int
    let pictures: [String: PictureEntry]

    init(of wallpaper: Wallpaper, at position: Int) {
        formatVersion = Self.currentFormatVersion
        id = wallpaper.id.value.uuidString
        name = wallpaper.name.text
        self.position = position
        var pictures: [String: PictureEntry] = [:]
        for slot in Slot.allCases {
            if let picture = wallpaper.picture(in: slot) {
                pictures[slot.storedWord] = PictureEntry(of: picture)
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
        for (slotWord, entry) in pictures {
            guard let slot = Slot(storedWord: slotWord) else { throw .unreadable }

            picturesBySlot[slot] = try entry.picture()
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

struct PictureEntry: Codable {
    let id: String
    let origin: String
    let captureTime: String?
    let fingerprint: String

    init(of picture: Picture) {
        id = picture.id.value.uuidString
        origin = picture.origin.storedWord
        captureTime = picture.captureTime?.storedText
        fingerprint = picture.fingerprint.text
    }

    func picture() throws(WallpaperLibraryError) -> Picture {
        guard let pictureID = UUID(uuidString: id), let pictureOrigin = PictureOrigin(storedWord: origin) else {
            throw .unreadable
        }

        let pictureCaptureTime = try captureTime.map { text throws(WallpaperLibraryError) in
            try CaptureTime(storedText: text)
        }
        let pictureFingerprint: ContentFingerprint
        do {
            pictureFingerprint = try ContentFingerprint(fingerprint)
        } catch {
            throw .unreadable
        }
        return Picture(
            id: PictureID(pictureID),
            origin: pictureOrigin,
            captureTime: pictureCaptureTime,
            fingerprint: pictureFingerprint,
        )
    }
}

private extension PictureOrigin {
    var storedWord: String {
        switch self {
        case .imported: "imported"
        case .madeWithAI: "madeWithAI"
        }
    }

    init?(storedWord: String) {
        switch storedWord {
        case "imported": self = .imported
        case "madeWithAI": self = .madeWithAI
        default: return nil
        }
    }
}

private extension CaptureTime {
    private static let dateSeparator: Character = "-"
    private static let clockSeparator: Character = ":"
    private static let dateAndClockSeparator: Character = "T"
    private static let digitCountsOfDateParts = [4, 2, 2]
    private static let digitCountsOfClockParts = [2, 2, 2]

    var storedText: String {
        let dateText = Self.text(
            of: [year, month, day],
            digitCounts: Self.digitCountsOfDateParts,
            separatedBy: Self.dateSeparator,
        )
        let clockText = Self.text(
            of: [hour, minute, second],
            digitCounts: Self.digitCountsOfClockParts,
            separatedBy: Self.clockSeparator,
        )
        return dateText + String(Self.dateAndClockSeparator) + clockText
    }

    init(storedText: String) throws(WallpaperLibraryError) {
        let dateAndClock = storedText.split(separator: Self.dateAndClockSeparator, omittingEmptySubsequences: false)
        guard dateAndClock.count == 2 else { throw .unreadable }

        let dateParts = try Self.numbers(
            in: dateAndClock[0],
            separatedBy: Self.dateSeparator,
            digitCounts: Self.digitCountsOfDateParts,
        )
        let clockParts = try Self.numbers(
            in: dateAndClock[1],
            separatedBy: Self.clockSeparator,
            digitCounts: Self.digitCountsOfClockParts,
        )
        do {
            try self.init(
                year: dateParts[0],
                month: dateParts[1],
                day: dateParts[2],
                hour: clockParts[0],
                minute: clockParts[1],
                second: clockParts[2],
            )
        } catch {
            throw .unreadable
        }
    }

    private static func text(of numbers: [Int], digitCounts: [Int], separatedBy separator: Character) -> String {
        zip(numbers, digitCounts)
            .map { number, digitCount in
                let digits = String(number)
                return String(repeating: "0", count: max(0, digitCount - digits.count)) + digits
            }
            .joined(separator: String(separator))
    }

    private static func numbers(
        in text: Substring,
        separatedBy separator: Character,
        digitCounts: [Int],
    ) throws(WallpaperLibraryError) -> [Int] {
        let parts = text.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == digitCounts.count else { throw .unreadable }

        var numbers: [Int] = []
        for (part, digitCount) in zip(parts, digitCounts) {
            guard part.count == digitCount,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(part)
            else {
                throw .unreadable
            }

            numbers.append(number)
        }
        return numbers
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
