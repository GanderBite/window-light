import Domain
import Foundation

enum WallpaperText: String, CaseIterable {
    case dawn = "Dawn"
    case sunrise = "Sunrise"
    case morning = "Morning"
    case midday = "Midday"
    case afternoon = "Afternoon"
    case sunset = "Sunset"
    case dusk = "Dusk"
    case night = "Night"
    case emptySlot = "Empty"
    case emptySlotBorrowing = "Empty, borrows the picture from %@"
    case yourPicture = "Your picture"
    case madeWithAI = "Made with AI"
    case addPicture = "Add a Picture…"
    case addPictureToSlot = "Add a picture to %@"
    case addPictures = "Add Pictures…"
    case nothingOpenTitle = "No Wallpaper Selected"
    case nothingOpenMessage = "Choose a wallpaper to see its pictures."
    case opening = "Opening the wallpaper"
    case goneTitle = "This wallpaper is no longer in your library."
    case unavailableTitle = "This wallpaper isn't available right now"
    case unavailableMessage = "Window Light couldn't reach its own storage. Try again."
    case tryAgain = "Try Again"
    case pictureActions = "Picture Actions"
    case moveToMenu = "Move to"
    case moveTo = "Move to %@"
    case removePicture = "Remove Picture"
    case placeByTimeAgain = "Place by Time Again…"
    case placeByTimeAgainQuestion = "Place the pictures by time again?"
    case placeByTimeAgainConsequence =
        "Your pictures are arranged again by the time they were taken. The arrangement you made is replaced."
    case confirmPlaceByTimeAgain = "Place by Time"
    case cancel = "Cancel"
    case ok = "OK"
    case needsMorePictures = "This wallpaper needs at least two pictures before it can be applied."
    case couldNotSaveTitle = "The change couldn't be saved"
    case pictureNowIn = "The picture is now in %@"
    case picturesSwapped = "The pictures of %1$@ and %2$@ changed places"
    case pictureRemovedFrom = "The picture was removed from %@"
    case placedByTimeAgain = "The pictures were placed by time again"
    case stepUndone = "The last step was undone"
    case stepRedone = "The step was done again"

    static func name(of slot: Slot) -> Self {
        switch slot {
        case .dawn: .dawn
        case .sunrise: .sunrise
        case .morning: .morning
        case .midday: .midday
        case .afternoon: .afternoon
        case .sunset: .sunset
        case .dusk: .dusk
        case .night: .night
        }
    }

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
        String(format: text(from: bundle), arguments: values)
    }
}
