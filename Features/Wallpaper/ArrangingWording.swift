import Domain
import Foundation

enum ArrangingWording {
    static func announcement(of step: WallpaperModel.Step, from bundle: Bundle) -> String? {
        switch step {
        case let .moved(_, destination):
            WallpaperText.pictureNowIn.text(from: bundle, filledWith: name(of: destination, from: bundle))
        case let .swapped(first, second):
            WallpaperText.picturesSwapped.text(
                from: bundle,
                filledWith: name(of: first, from: bundle), name(of: second, from: bundle),
            )
        case let .removed(slot):
            WallpaperText.pictureRemovedFrom.text(from: bundle, filledWith: name(of: slot, from: bundle))
        case .placedByTimeAgain:
            WallpaperText.placedByTimeAgain.text(from: bundle)
        case .undone:
            WallpaperText.stepUndone.text(from: bundle)
        case .redone:
            WallpaperText.stepRedone.text(from: bundle)
        case .picturesAdded:
            nil
        }
    }

    static func undoActionName(of step: WallpaperModel.Step, from bundle: Bundle) -> String? {
        switch step {
        case .moved: WallpaperText.pictureMove.text(from: bundle)
        case .swapped: WallpaperText.pictureSwap.text(from: bundle)
        case .removed: WallpaperText.pictureRemoval.text(from: bundle)
        case .placedByTimeAgain: WallpaperText.placingByTime.text(from: bundle)
        case .picturesAdded: WallpaperText.pictureAddition.text(from: bundle)
        case .undone, .redone: nil
        }
    }

    private static func name(of slot: Slot, from bundle: Bundle) -> String {
        WallpaperText.name(of: slot).text(from: bundle)
    }
}
