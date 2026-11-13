import Application
import Features
import Infrastructure
import SwiftUI

@main
struct WindowLightApp: App {
    private static let windowID = "library"

    @State private var libraryModel: LibraryModel
    @State private var wallpaperModel: WallpaperModel
    @State private var pictureImportModel: PictureImportModel

    init() {
        let library = FileWallpaperLibrary()
        let previews = ImageIOPicturePreviews()
        let files = ChosenPictureFiles()
        let libraryModel = LibraryModel(
            openLibrary: OpenLibrary(library: library),
            openWallpaper: OpenWallpaper(library: library),
            renameWallpaper: RenameWallpaper(library: library),
            deleteWallpaper: DeleteWallpaper(library: library),
        )
        let wallpaperModel = WallpaperModel(openWallpaper: OpenWallpaper(library: library))
        let pictureImportModel = PictureImportModel(
            createWallpaper: CreateWallpaper(library: library, previews: previews, files: files),
            addPictures: AddPictures(library: library, previews: previews, files: files),
            addPictureToSlot: AddPictureToSlot(library: library, previews: previews, files: files),
            defaultWallpaperNameStem: LibraryScreen.defaultWallpaperNameStem,
            wallpaperChanged: { wallpaper in
                await libraryModel.reload()
                await libraryModel.select(wallpaper)
                await wallpaperModel.show(wallpaper)
            },
        )
        _libraryModel = State(initialValue: libraryModel)
        _wallpaperModel = State(initialValue: wallpaperModel)
        _pictureImportModel = State(initialValue: pictureImportModel)
    }

    var body: some Scene {
        Window("Window Light", id: Self.windowID) {
            NavigationSplitView {
                LibraryScreen(
                    model: libraryModel,
                    createWallpaper: { pictureImportModel.chooseFiles(for: .newWallpaper) },
                    createWallpaperFromFiles: { files in
                        Task { await pictureImportModel.importFiles(files, to: .newWallpaper) }
                    },
                )
            } detail: {
                WallpaperScreen(
                    model: wallpaperModel,
                    addPictures: { wallpaper in pictureImportModel.chooseFiles(for: .wallpaper(wallpaper)) },
                    addPicture: { slot, wallpaper in pictureImportModel.chooseFiles(for: .slot(slot, of: wallpaper)) },
                    addDroppedFiles: { files, wallpaper in
                        Task { await pictureImportModel.importFiles(files, to: .wallpaper(wallpaper)) }
                    },
                    addDroppedFile: { file, slot, wallpaper in
                        Task { await pictureImportModel.importFiles([file], to: .slot(slot, of: wallpaper)) }
                    },
                )
            }
            .importingPictures(with: pictureImportModel)
            .task(id: libraryModel.openWallpaperID) {
                await wallpaperModel.show(libraryModel.openWallpaperID)
            }
        }
    }
}
