import Foundation
import SwiftUI
import Testing
@testable import Features

private let textThatNoCatalogueHolds = "<missing text>"

private func text(_ welcomeText: WelcomeText, inLanguage language: String) throws -> String {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    let languageBundle = try #require(Bundle(url: languageURL))
    return languageBundle.localizedString(
        forKey: welcomeText.key,
        value: textThatNoCatalogueHolds,
        table: nil
    )
}

struct WelcomeScreenTests {
    @Test(arguments: WelcomeText.allCases, ["en", "pl"])
    func everyTextHasAValueInEveryLanguage(welcomeText: WelcomeText, language: String) throws {
        #expect(try text(welcomeText, inLanguage: language) != textThatNoCatalogueHolds)
    }

    @Test func thePurposeIsTheSentenceAboutPicturesAndVideosInEnglish() throws {
        #expect(
            try text(.purpose, inLanguage: "en")
                == "Turn your own pictures and videos into a wallpaper that changes through the day."
        )
    }

    @Test func thePurposeIsTheSentenceAboutPicturesAndVideosInPolish() throws {
        #expect(
            try text(.purpose, inLanguage: "pl")
                == "Zamień własne zdjęcia i filmy w tapetę, która zmienia się w ciągu dnia."
        )
    }

    @Test(arguments: ["en", "pl"])
    func theNameIsWindowLightInEveryLanguage(language: String) throws {
        #expect(try text(.appName, inLanguage: language) == "Window Light")
    }

    @Test @MainActor func rendersTheWelcomeScreen() throws {
        let renderer = ImageRenderer(content: WelcomeScreen())
        renderer.proposedSize = ProposedViewSize(width: 500, height: nil)
        let size = try #require(renderer.nsImage?.size)
        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
