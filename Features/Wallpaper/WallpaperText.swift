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
