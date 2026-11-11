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
        picturePreviews: [PictureID: Data],
    ) async throws(WallpaperLibraryError) {
        let pictureFiles = try Self.pictureFiles(of: wallpaper, contents: pictureContents, previews: picturePreviews)
        let layout = try layout()
        let document = try WallpaperDocument(of: wallpaper, at: nextPosition(in: layout))
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

    private func layout() throws(WallpaperLibraryError) -> LibraryLayout {
        if let preparedLayout {
            return preparedLayout
        }
        let layout = try LibraryLayout(folder: madeStorageFolder())
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
                create: true,
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
                try FileManager.default.contentsOfDirectory(
                    at: layout.beingAddedFolder,
                    includingPropertiesForKeys: nil,
                )
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
            try stored.append(Self.readingWhatMustBeThere { () throws(WallpaperLibraryError) in
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
                    options: .skipsHiddenFiles,
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

    private func storedWallpaper(
        _ id: WallpaperID,
        in layout: LibraryLayout,
    ) throws(WallpaperLibraryError) -> StoredWallpaper {
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
        guard let text = String(data: content, encoding: .utf8), let id = UUID(uuidString: text) else {
            throw .unreadable
        }

        return WallpaperID(id)
    }

    private static func pictureFiles(
        of wallpaper: Wallpaper,
        contents: [PictureID: Data],
        previews: [PictureID: Data],
    ) throws(WallpaperLibraryError) -> [PictureFiles] {
        var pictureFiles: [PictureFiles] = []
        for picture in wallpaper.picturesInDayOrder {
            guard let content = contents[picture.id], let preview = previews[picture.id] else {
                throw .unexpected(
                    description: "The picture \(picture.id.value.uuidString) of the wallpaper "
                        + "\(wallpaper.id.value.uuidString) was given without its content or its preview",
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
        in layout: LibraryLayout,
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
        atomically: Bool,
    ) throws(WallpaperLibraryError) {
        let content = try document.encoded()
        try translatingFailures { try content.write(to: documentFile, options: atomically ? .atomic : []) }
    }
}

private struct PictureFiles {
    let picture: PictureID
    let content: Data
    let preview: Data
}
