import Application
import Foundation

struct ImportOutcomeWording: Equatable {
    let headline: String
    let notes: [String]
}

extension PictureImportModel.Outcome {
    func wording(from bundle: Bundle) -> ImportOutcomeWording {
        ImportOutcomeWording(headline: headline(from: bundle), notes: notes(from: bundle))
    }

    var wordingInTheAppLanguage: ImportOutcomeWording {
        wording(from: .module)
    }

    private func headline(from bundle: Bundle) -> String {
        guard summary.addedPictureCount > 0 else { return PictureImportText.noPicturesAdded.text(from: bundle) }

        return PictureImportText.picturesAdded.text(from: bundle, filledWith: summary.addedPictureCount)
    }

    private func notes(from bundle: Bundle) -> [String] {
        var notes: [String] = []
        if summary.stoppedForLackOfSpace {
            notes.append(PictureImportText.stoppedForLackOfSpace.text(from: bundle))
        }
        notes += summary.skippedFiles.map { skipped in
            Self.text(forSkipping: skipped.reason).text(from: bundle, filledWith: skipped.name)
        }
        notes += summary.filesThatMayLookBlurry.map { name in
            PictureImportText.mayLookBlurry.text(from: bundle, filledWith: name)
        }
        if wallpaperNeedsMorePictures {
            notes.append(PictureImportText.wallpaperNeedsMorePictures.text(from: bundle))
        }
        return notes
    }

    private static func text(forSkipping reason: SkippedFile.Reason) -> PictureImportText {
        switch reason {
        case .notAPicture: .notAPicture
        case .damaged: .damaged
        case .soundOnly: .soundOnly
        case .copyProtected: .copyProtected
        case .cannotBeRead: .cannotBeRead
        case .alreadyInWallpaper: .alreadyInWallpaper
        case .sameAsAnotherChosenFile: .sameAsAnotherChosenFile
        case .noSpaceLeft: .noSpaceForFile
        }
    }
}

extension PictureImportModel.Refusal {
    func message(from bundle: Bundle) -> String {
        switch self {
        case let .tooFewFiles(fewest): PictureImportText.tooFewFiles.text(from: bundle, filledWith: fewest)
        case let .tooManyFiles(most): PictureImportText.tooManyFiles.text(from: bundle, filledWith: most)
        case .noEmptySlot: PictureImportText.noEmptySlot.text(from: bundle)
        case let .moreFilesThanEmptySlots(emptySlots):
            PictureImportText.moreFilesThanEmptySlots.text(from: bundle, filledWith: emptySlots)
        case .oneFileForASlot: PictureImportText.oneFileForASlot.text(from: bundle)
        case .slotHoldsRealPicture: PictureImportText.slotHoldsRealPicture.text(from: bundle)
        case .wallpaperGone: PictureImportText.wallpaperGone.text(from: bundle)
        case .couldNotImport: PictureImportText.couldNotImport.text(from: bundle)
        }
    }

    var messageInTheAppLanguage: String {
        message(from: .module)
    }
}
