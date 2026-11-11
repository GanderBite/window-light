import Foundation
import Presentation
import SwiftUI

enum WelcomeText: String, CaseIterable {
    case appName = "Window Light"
    case purpose = "Turn your own pictures and videos into a wallpaper that changes through the day."

    var key: String { rawValue }

    var inTheAppLanguage: String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}

public struct WelcomeScreen: View {
    public init() {}

    public var body: some View {
        TitledMessage(
            title: WelcomeText.appName.inTheAppLanguage,
            message: WelcomeText.purpose.inTheAppLanguage
        )
    }
}
