import Application
import Domain
import Foundation

public actor FileWallpaperLibrary: WallpaperLibrary {
    private static let storageFolderName = "WallpaperLibrary"

    private let givenFolder: URL?
    private var preparedLayout: LibraryLayout?

    public init() {
        givenFolder = nil
    }

    public init(folder: URL) {
        givenFolder = folder
    }

    public func wallpapers() async throws(WallpaperLibraryError) -> [Wallpaper] {
        try storedWallpapers(in: layout()).map(\.wallpaper)
    }

    public func wallpaper(_ id: WallpaperID) async throws(WallpaperLibraryError) -> Wallpaper {
        try storedWallpaper(id, in: layout()).wallpaper
    }

    public func picturePreviews(of wallpaper: WallpaperID) async throws(WallpaperLibraryError) -> [PictureID: Data] {
        let layout = try layout()
        let stored = try storedWallpaper(wallpaper, in: layout)
        var previews: [PictureID: Data] = [:]
        for picture in stored.wallpaper.picturesInDayOrder {
            let previewFile = layout.previewFile(of: picture.id, inWallpaper: wallpaper)
            previews[picture.id] = try Self.readingWhatMustBeThere { () throws(WallpaperLibraryError) in
                try Self.translatingFailures { try Data(contentsOf: previewFile) }
            }
        }
        return previews
    }

    public func add(
        _ wallpaper: Wallpaper,
        pictureContents: [PictureID: Data],
        picturePreviews: [PictureID: Data]
    ) async throws(WallpaperLibraryError) {
        let pictureFiles = try Self.pictureFiles(of: wallpaper, contents: pictureContents, previews: picturePreviews)
        let layout = try layout()
        let document = WallpaperDocument(of: wallpaper, at: try nextPosition(in: layout))
        let folderBeingAdded = layout.folderBeingAdded(for: wallpaper.id)
        do {
            try Self.build(folderBeingAdded, holding: document, and: pictureFiles, in: layout)
            try Self.translatingFailures {
                try FileManager.default.createDirectory(at: layout.wallpapersFolder, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: folderBeingAdded, to: layout.wallpaperFolder(of: wallpaper.id))
            }
        } catch {
            Self.discardUnfinishedAdditionLeavingAnyRestForTheNextCleanUp(at: folderBeingAdded)
            throw error
        }
    }

    public func keep(_ wallpaper: Wallpaper) async throws(WallpaperLibraryError) {
        let layout = try layout()
        let stored = try storedWallpaper(wallpaper.id, in: layout)
        let document = WallpaperDocument(of: wallpaper, at: stored.position)
        try Self.write(document, to: layout.documentFile(ofWallpaper: wallpaper.id), atomically: true)
    }

    public func remove(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        let layout = try layout()
        let wasLastWorkedOn = try rememberedLastWorkedOn(in: layout) == wallpaper
        try Self.removeUnlessAlreadyGone(layout.wallpaperFolder(of: wallpaper))
        if wasLastWorkedOn {
            try Self.removeUnlessAlreadyGone(layout.lastWorkedOnFile)
        }
    }

    public func wallpaperLastWorkedOn() async throws(WallpaperLibraryError) -> WallpaperID? {
        let layout = try layout()
        guard let remembered = try rememberedLastWorkedOn(in: layout), try holds(remembered, in: layout) else {
            return nil
        }
        return remembered
    }

    public func rememberAsLastWorkedOn(_ wallpaper: WallpaperID) async throws(WallpaperLibraryError) {
        let layout = try layout()
        guard try holds(wallpaper, in: layout) else { throw .notFound }
        let content = Data(wallpaper.value.uuidString.utf8)
        try Self.translatingFailures { try content.write(to: layout.lastWorkedOnFile, options: .atomic) }
    }

    static func libraryError(describing failure: any Error) -> WallpaperLibraryError {
        if let libraryError = failure as? WallpaperLibraryError {
            return libraryError
        }
        if let cocoaError = failure as? CocoaError {
            switch cocoaError.code {
            case .fileNoSuchFile, .fileReadNoSuchFile: return .notFound
            case .fileReadNoPermission, .fileWriteNoPermission: return .notPermitted
            case .fileWriteOutOfSpace: return .noSpaceLeft
            case .fileWriteVolumeReadOnly: return .unavailable
            default:
                if let underlyingFailure = cocoaError.underlying {
                    return libraryError(describing: underlyingFailure, otherwiseUnexpected: cocoaError)
                }
            }
        }
        if let posixError = failure as? POSIXError {
            switch posixError.code {
            case .ENOENT: return .notFound
            case .EACCES, .EPERM: return .notPermitted
            case .ENOSPC, .EDQUOT: return .noSpaceLeft
            case .EROFS: return .unavailable
            default: break
            }
        }
        return .unexpected(description: String(describing: failure))
    }

    private static func libraryError(
        describing underlyingFailure: any Error,
        otherwiseUnexpected failure: any Error
    ) -> WallpaperLibraryError {
        let recognised = libraryError(describing: underlyingFailure)
        if case .unexpected = recognised {
            return .unexpected(description: String(describing: failure))
        }
        return recognised
    }

    private static func translatingFailures<Result>(_ work: () throws -> Result) throws(WallpaperLibraryError) -> Result {
        do {
            return try work()
        } catch {
            throw libraryError(describing: error)
        }
    }

    private static func readingWhatMustBeThere<Result>(
        _ work: () throws(WallpaperLibraryError) -> Result
    ) throws(WallpaperLibraryError) -> Result {
        do {
            return try work()
        } catch .notFound {
            throw .unreadable
        } catch {
            throw error
        }
    }

    private static func removeUnlessAlreadyGone(_ item: URL) throws(WallpaperLibraryError) {
        do {
            try translatingFailures { try FileManager.default.removeItem(at: item) }
        } catch .notFound {
            return
        } catch {
            throw error
        }
    }

    private func layout() throws(WallpaperLibraryError) -> LibraryLayout {
        if let preparedLayout {
            return preparedLayout
        }
        let layout = LibraryLayout(folder: try madeStorageFolder())
        try Self.removeUnfinishedAdditions(in: layout)
        preparedLayout = layout
        return layout
    }

    private func madeStorageFolder() throws(WallpaperLibraryError) -> URL {
        do {
            let folder = try givenFolder ?? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appending(path: Self.storageFolderName, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            throw .unavailable
        }
    }

    private static func removeUnfinishedAdditions(in layout: LibraryLayout) throws(WallpaperLibraryError) {
        let unfinishedAdditions: [URL]
        do {
            unfinishedAdditions = try translatingFailures {
                try FileManager.default.contentsOfDirectory(at: layout.beingAddedFolder, includingPropertiesForKeys: nil)
            }
        } catch .notFound {
            return
        } catch {
            throw error
        }
        for unfinishedAddition in unfinishedAdditions {
            try translatingFailures { try FileManager.default.removeItem(at: unfinishedAddition) }
        }
    }

    private static func discardUnfinishedAdditionLeavingAnyRestForTheNextCleanUp(at folderBeingAdded: URL) {
        try? FileManager.default.removeItem(at: folderBeingAdded)
    }

    private func storedWallpapers(in layout: LibraryLayout) throws(WallpaperLibraryError) -> [StoredWallpaper] {
        var stored: [StoredWallpaper] = []
        for id in try idsOfStoredWallpapers(in: layout) {
            stored.append(try Self.readingWhatMustBeThere { () throws(WallpaperLibraryError) in
                try storedWallpaper(id, in: layout)
            })
        }
        return stored.sorted { $0.position < $1.position }
    }

    private func idsOfStoredWallpapers(in layout: LibraryLayout) throws(WallpaperLibraryError) -> [WallpaperID] {
        let wallpaperFolders: [URL]
        do {
            wallpaperFolders = try Self.translatingFailures {
                try FileManager.default.contentsOfDirectory(
                    at: layout.wallpapersFolder,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
            }
        } catch .notFound {
            return []
        } catch {
            throw error
        }
        var ids: [WallpaperID] = []
        for wallpaperFolder in wallpaperFolders {
            guard let id = UUID(uuidString: wallpaperFolder.lastPathComponent) else { throw .unreadable }
            ids.append(WallpaperID(id))
        }
        return ids
    }

    private func storedWallpaper(_ id: WallpaperID, in layout: LibraryLayout) throws(WallpaperLibraryError) -> StoredWallpaper {
        let documentFile = layout.documentFile(ofWallpaper: id)
        let documentContent = try Self.translatingFailures { try Data(contentsOf: documentFile) }
        let stored = try WallpaperDocument.storedWallpaper(decodedFrom: documentContent)
        guard stored.wallpaper.id == id else { throw .unreadable }
        return stored
    }

    private func holds(_ wallpaper: WallpaperID, in layout: LibraryLayout) throws(WallpaperLibraryError) -> Bool {
        do {
            _ = try storedWallpaper(wallpaper, in: layout)
            return true
        } catch .notFound {
            return false
        } catch {
            throw error
        }
    }

    private func nextPosition(in layout: LibraryLayout) throws(WallpaperLibraryError) -> Int {
        let highestPosition = try storedWallpapers(in: layout).map(\.position).max() ?? 0
        return highestPosition + 1
    }

    private func rememberedLastWorkedOn(in layout: LibraryLayout) throws(WallpaperLibraryError) -> WallpaperID? {
        let content: Data
        do {
            content = try Self.translatingFailures { try Data(contentsOf: layout.lastWorkedOnFile) }
        } catch .notFound {
            return nil
        } catch {
            throw error
        }
        guard let id = UUID(uuidString: String(decoding: content, as: UTF8.self)) else { throw .unreadable }
        return WallpaperID(id)
    }

    private static func pictureFiles(
        of wallpaper: Wallpaper,
        contents: [PictureID: Data],
        previews: [PictureID: Data]
    ) throws(WallpaperLibraryError) -> [PictureFiles] {
        var pictureFiles: [PictureFiles] = []
        for picture in wallpaper.picturesInDayOrder {
            guard let content = contents[picture.id], let preview = previews[picture.id] else {
                throw .unexpected(
                    description: "The picture \(picture.id.value.uuidString) of the wallpaper "
                        + "\(wallpaper.id.value.uuidString) was given without its content or its preview"
                )
            }
            pictureFiles.append(PictureFiles(picture: picture.id, content: content, preview: preview))
        }
        return pictureFiles
    }

    private static func build(
        _ folderBeingAdded: URL,
        holding document: WallpaperDocument,
        and pictureFiles: [PictureFiles],
        in layout: LibraryLayout
    ) throws(WallpaperLibraryError) {
        let picturesFolder = layout.picturesFolder(in: folderBeingAdded)
        let previewsFolder = layout.previewsFolder(in: folderBeingAdded)
        try translatingFailures {
            try FileManager.default.createDirectory(at: picturesFolder, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: previewsFolder, withIntermediateDirectories: true)
            for pictureFile in pictureFiles {
                try pictureFile.content.write(to: layout.file(of: pictureFile.picture, in: picturesFolder))
                try pictureFile.preview.write(to: layout.file(of: pictureFile.picture, in: previewsFolder))
            }
        }
        try write(document, to: layout.documentFile(in: folderBeingAdded), atomically: false)
    }

    private static func write(
        _ document: WallpaperDocument,
        to documentFile: URL,
        atomically: Bool
    ) throws(WallpaperLibraryError) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let content: Data
        do {
            content = try encoder.encode(document)
        } catch {
            throw .unexpected(description: "The wallpaper \(document.id) could not be encoded: \(error)")
        }
        try translatingFailures { try content.write(to: documentFile, options: atomically ? .atomic : []) }
    }
}

private struct LibraryLayout {
    let folder: URL

    var wallpapersFolder: URL {
        folder.appending(path: "Wallpapers", directoryHint: .isDirectory)
    }

    var beingAddedFolder: URL {
        folder.appending(path: "BeingAdded", directoryHint: .isDirectory)
    }

    var lastWorkedOnFile: URL {
        folder.appending(path: "LastWorkedOn", directoryHint: .notDirectory)
    }

    func wallpaperFolder(of wallpaper: WallpaperID) -> URL {
        wallpapersFolder.appending(path: wallpaper.value.uuidString, directoryHint: .isDirectory)
    }

    func folderBeingAdded(for wallpaper: WallpaperID) -> URL {
        beingAddedFolder.appending(path: wallpaper.value.uuidString, directoryHint: .isDirectory)
    }

    func documentFile(ofWallpaper wallpaper: WallpaperID) -> URL {
        documentFile(in: wallpaperFolder(of: wallpaper))
    }

    func documentFile(in wallpaperFolder: URL) -> URL {
        wallpaperFolder.appending(path: "Wallpaper.json", directoryHint: .notDirectory)
    }

    func picturesFolder(in wallpaperFolder: URL) -> URL {
        wallpaperFolder.appending(path: "Pictures", directoryHint: .isDirectory)
    }

    func previewsFolder(in wallpaperFolder: URL) -> URL {
        wallpaperFolder.appending(path: "Previews", directoryHint: .isDirectory)
    }

    func previewFile(of picture: PictureID, inWallpaper wallpaper: WallpaperID) -> URL {
        file(of: picture, in: previewsFolder(in: wallpaperFolder(of: wallpaper)))
    }

    func file(of picture: PictureID, in folder: URL) -> URL {
        folder.appending(path: picture.value.uuidString, directoryHint: .notDirectory)
    }
}

private struct PictureFiles {
    let picture: PictureID
    let content: Data
    let preview: Data
}

private struct StoredWallpaper {
    let wallpaper: Wallpaper
    let position: Int
}

private struct WallpaperDocument: Codable {
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
        let document: WallpaperDocument
        do {
            document = try JSONDecoder().decode(WallpaperDocument.self, from: content)
        } catch {
            throw .unreadable
        }
        return try document.storedWallpaper()
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
                pictures: picturesBySlot
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
