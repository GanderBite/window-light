import Features
import SwiftUI

@main
struct WindowLightApp: App {
    private static let windowID = "welcome"

    var body: some Scene {
        Window("Window Light", id: Self.windowID) {
            WelcomeScreen()
        }
    }
}
