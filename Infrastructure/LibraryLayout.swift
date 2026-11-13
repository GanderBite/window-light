import Domain
import Foundation

struct LibraryLayout {
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

    func pictureFileFolders(ofWallpaper wallpaper: WallpaperID) -> [URL] {
        let wallpaperFolder = wallpaperFolder(of: wallpaper)
        return [picturesFolder(in: wallpaperFolder), previewsFolder(in: wallpaperFolder)]
    }

    func contentFile(of picture: PictureID, inWallpaper wallpaper: WallpaperID) -> URL {
        file(of: picture, in: picturesFolder(in: wallpaperFolder(of: wallpaper)))
    }

    func previewFile(of picture: PictureID, inWallpaper wallpaper: WallpaperID) -> URL {
        file(of: picture, in: previewsFolder(in: wallpaperFolder(of: wallpaper)))
    }

    func names(_ file: URL, asOneOf pictures: Set<PictureID>) -> Bool {
        pictures.contains { $0.value.uuidString == file.lastPathComponent }
    }

    func file(of picture: PictureID, in folder: URL) -> URL {
        folder.appending(path: picture.value.uuidString, directoryHint: .notDirectory)
    }
}
