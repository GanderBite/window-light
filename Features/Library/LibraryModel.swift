import Application
import Domain
import Observation

@MainActor
@Observable
public final class LibraryModel {
    public enum Phase: Equatable { case opening, open, unreadable, unavailable }
    public enum NameProblem: Equatable { case empty, tooLong(limit: Int) }
    public enum Problem: Equatable { case wallpaperGone, noSpaceLeft, changeNotKept }

    private let openLibrary: OpenLibrary
    private let openWallpaper: OpenWallpaper
    private let renameWallpaper: RenameWallpaper
    private let deleteWallpaper: DeleteWallpaper

    public private(set) var phase: Phase = .opening
    public private(set) var wallpapers: [LibraryWallpaper] = []
    public private(set) var openWallpaperID: WallpaperID?
    public private(set) var wallpaperBeingRenamed: WallpaperID?
    public private(set) var nameProblem: NameProblem?
    public private(set) var wallpaperAwaitingDeletion: LibraryWallpaper?
    public private(set) var problem: Problem?

    public init(
        openLibrary: OpenLibrary,
        openWallpaper: OpenWallpaper,
        renameWallpaper: RenameWallpaper,
        deleteWallpaper: DeleteWallpaper
    ) {
        self.openLibrary = openLibrary
        self.openWallpaper = openWallpaper
        self.renameWallpaper = renameWallpaper
        self.deleteWallpaper = deleteWallpaper
    }

    public var isEmpty: Bool {
        phase == .open && wallpapers.isEmpty
    }

    public func open() async {
        phase = .opening
        do throws(OpenLibraryError) {
            let contents = try await openLibrary.execute()
            let previews = await LibraryWallpaper.decodedPreviews(of: contents.wallpapers)
            wallpapers = zip(contents.wallpapers, previews).map { entry, entryPreviews in
                LibraryWallpaper(showing: entry.wallpaper, withPreviews: entryPreviews)
            }
            openWallpaperID = contents.wallpaperLastWorkedOn
            phase = .open
        } catch {
            wallpapers = []
            switch error {
            case .unreadable: phase = .unreadable
            case .unavailable: phase = .unavailable
            }
        }
    }

    public func select(_ wallpaper: WallpaperID) async {
        openWallpaperID = wallpaper
        do throws(OpenWallpaperError) {
            _ = try await openWallpaper.execute(wallpaper)
        } catch {
            switch error {
            case .wallpaperGone:
                removeEntry(of: wallpaper)
                openWallpaperID = nil
                problem = .wallpaperGone
            case .unavailable:
                problem = .changeNotKept
            }
        }
    }

    public func startRenaming(_ wallpaper: WallpaperID) {
        wallpaperBeingRenamed = wallpaper
        nameProblem = nil
    }

    public func rename(to proposedName: String) async {
        guard let wallpaper = wallpaperBeingRenamed else { return }
        do throws(RenameWallpaperError) {
            let renamed = try await renameWallpaper.execute(wallpaper, to: proposedName)
            wallpapers = wallpapers.map { entry in
                entry.id == renamed.id ? entry.renamed(as: renamed) : entry
            }
            endRenaming()
        } catch {
            switch error {
            case .nameEmpty:
                nameProblem = .empty
            case .nameTooLong(let limit):
                nameProblem = .tooLong(limit: limit)
            case .wallpaperGone:
                removeEntry(of: wallpaper)
                endRenaming()
                problem = .wallpaperGone
            case .noSpaceLeft:
                endRenaming()
                problem = .noSpaceLeft
            case .unavailable:
                endRenaming()
                problem = .changeNotKept
            }
        }
    }

    public func cancelRenaming() {
        endRenaming()
    }

    public func askToDelete(_ wallpaper: WallpaperID) {
        wallpaperAwaitingDeletion = wallpapers.first { $0.id == wallpaper }
    }

    public func confirmDeletion() async {
        guard let wallpaper = wallpaperAwaitingDeletion?.id else { return }
        wallpaperAwaitingDeletion = nil
        do throws(DeleteWallpaperError) {
            try await deleteWallpaper.execute(wallpaper)
            removeEntry(of: wallpaper)
            if openWallpaperID == wallpaper {
                openWallpaperID = nil
            }
        } catch {
            switch error {
            case .unavailable: problem = .changeNotKept
            }
        }
    }

    public func declineDeletion() {
        wallpaperAwaitingDeletion = nil
    }

    public func dismissProblem() {
        problem = nil
    }

    private func endRenaming() {
        wallpaperBeingRenamed = nil
        nameProblem = nil
    }

    private func removeEntry(of wallpaper: WallpaperID) {
        wallpapers.removeAll { $0.id == wallpaper }
    }
}
