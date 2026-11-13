import Foundation

enum PictureImportText: String, CaseIterable {
    case importing = "Importing pictures"
    case picturesAdded = "%lld pictures added"
    case noPicturesAdded = "No pictures were added"
    case notAPicture = "“%@” isn't a picture Window Light can use."
    case damaged = "“%@” is damaged and couldn't be opened."
    case soundOnly = "“%@” has sound only, so there is no picture to take from it."
    case copyProtected = "“%@” is copy-protected, so Window Light can't take a picture from it."
    case cannotBeRead = "“%@” couldn't be read."
    case alreadyInWallpaper = "“%@” is already in this wallpaper."
    case sameAsAnotherChosenFile = "“%@” is the same as another file you chose."
    case noSpaceForFile = "“%@” wasn't added because your Mac has no storage left."
    case notAddedBecauseStopped = "“%@” wasn't added because you stopped the import."
    case mayLookBlurry = "“%@” is smaller than 1920 × 1080 and may look blurry on the desktop."
    case stoppedForLackOfSpace = "Your Mac ran out of storage, so the import stopped. Pictures already added are kept."
    case importStopped = "You stopped the import. Pictures already added are kept."
    case wallpaperNeedsMorePictures = "This wallpaper needs at least two pictures before it can be applied."
    case tooFewFiles = "Choose at least %lld files to create a wallpaper."
    case tooManyFiles = "A wallpaper can have at most %lld pictures. Choose fewer files."
    case noEmptySlot = "Every time of day in this wallpaper already has a picture."
    case moreFilesThanEmptySlots = "Only %lld times of day are free. Choose that many files or fewer."
    case oneFileForASlot = "Choose one file for a time of day."
    case slotHoldsRealPicture = "This time of day already has one of your pictures. Remove or move it first."
    case wallpaperGone = "This wallpaper is no longer in your library."
    case couldNotImport = "The pictures couldn't be imported. Try again."
    case ok = "OK"
    case stop = "Stop"

    var key: String {
        rawValue
    }

    func text(from bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func text(from bundle: Bundle, filledWith values: CVarArg...) -> String {
        text(from: bundle, filledWithEach: values)
    }

    var inTheAppLanguage: String {
        text(from: .module)
    }

    func inTheAppLanguage(filledWith values: CVarArg...) -> String {
        text(from: .module, filledWithEach: values)
    }

    private func text(from bundle: Bundle, filledWithEach values: [CVarArg]) -> String {
        String(format: text(from: bundle), locale: Self.languageOfTheTexts(in: bundle), arguments: values)
    }

    private static let languageFolderExtension = "lproj"

    private static func languageOfTheTexts(in bundle: Bundle) -> Locale {
        let bundleFolder = bundle.bundleURL
        if bundleFolder.pathExtension == languageFolderExtension {
            return Locale(identifier: bundleFolder.deletingPathExtension().lastPathComponent)
        }
        return bundle.preferredLocalizations.first.map(Locale.init(identifier:)) ?? .current
    }
}
