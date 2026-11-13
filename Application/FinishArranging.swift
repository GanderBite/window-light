import Domain
import Foundation

public struct FinishArranging: Sendable {
    private let library: any WallpaperLibrary

    public init(library: any WallpaperLibrary) {
        self.library = library
    }

    @discardableResult
    public func execute(_ wallpaper: WallpaperID) async -> FinishArrangingOutcome {
        do throws(WallpaperLibraryError) {
            try await library.discardPicturesNoLongerHeld(by: wallpaper)
            return .picturesDiscarded
        } catch {
            if error == .notFound {
                return .picturesDiscarded
            }
            return .picturesLeftForLater(description: error.causeDescription)
        }
    }
}

public enum FinishArrangingOutcome: Equatable, Sendable {
    case picturesDiscarded
    case picturesLeftForLater(description: String)
}
