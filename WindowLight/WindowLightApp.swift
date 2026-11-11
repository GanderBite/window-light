import Application
import Features
import Infrastructure
import SwiftUI

@main
struct WindowLightApp: App {
    private static let windowID = "library"

    @State private var libraryModel: LibraryModel

    init() {
        let library = FileWallpaperLibrary()
        _libraryModel = State(initialValue: LibraryModel(
            openLibrary: OpenLibrary(library: library),
            openWallpaper: OpenWallpaper(library: library),
            renameWallpaper: RenameWallpaper(library: library),
            deleteWallpaper: DeleteWallpaper(library: library),
        ))
    }

    var body: some Scene {
        Window("Window Light", id: Self.windowID) {
            LibraryScreen(model: libraryModel)
        }
    }
}
