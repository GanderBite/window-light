import Foundation

enum LibraryText: String, CaseIterable {
    case emptyTitle = "No Wallpapers"
    case emptyExplanation = """
    A wallpaper is two to eight of your own pictures. \
    Your Mac changes between them through the day.
    """
    case createWallpaper = "Create a Wallpaper…"
    case opening = "Opening your wallpapers"
    case picturesOfEight = "%lld of 8 pictures"
    case rename = "Rename"
    case delete = "Delete…"
    case nameField = "Wallpaper name"
    case nameEmpty = "A name needs at least one character that is not a space."
    case nameTooLong = "A name can have up to %lld characters."
    case deleteQuestion = "Delete “%@”?"
    case deleteConsequence = """
    Its pictures are removed from Window Light and can't be brought back. \
    The files you imported them from stay where they are.
    """
    case confirmDelete = "Delete"
    case cancel = "Cancel"
    case unreadableTitle = "Your wallpapers couldn't be read"
    case unreadableMessage = "Something in the storage of Window Light is damaged. Try again."
    case unavailableTitle = "Your wallpapers aren't available right now"
    case unavailableMessage = "Window Light couldn't reach its own storage. Try again."
    case tryAgain = "Try Again"
    case wallpaperGone = "This wallpaper is no longer in your library."
    case noSpaceLeft = "Your Mac has no storage left, so the change wasn't kept. Free up some space and try again."
    case changeNotKept = "The change couldn't be kept. Try again."
    case ok = "OK"
    case defaultNameStem = "Wallpaper"

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
