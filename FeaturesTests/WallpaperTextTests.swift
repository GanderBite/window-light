import Domain
@testable import Features
import Foundation
import Testing

private func languageBundle(_ language: String) throws -> Bundle {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    return try #require(Bundle(url: languageURL))
}

struct WallpaperTextTests {
    @Test(arguments: WallpaperText.allCases, ["en", "pl"])
    func everyTextHasAValueInEveryLanguage(wallpaperText: WallpaperText, language: String) throws {
        let bundle = try languageBundle(language)
        let textThatNoCatalogueHolds = "<missing text>"
        let found = bundle.localizedString(forKey: wallpaperText.key, value: textThatNoCatalogueHolds, table: nil)
        #expect(found != textThatNoCatalogueHolds)
        #expect(wallpaperText.text(from: bundle) == found)
    }

    @Test func theEightSlotNamesReadDawnToNightInEnglishInTheOrderOfTheDay() throws {
        let english = try languageBundle("en")
        #expect(
            Slot.allCases.map { WallpaperText.name(of: $0).text(from: english) }
                == ["Dawn", "Sunrise", "Morning", "Midday", "Afternoon", "Sunset", "Dusk", "Night"],
        )
    }

    @Test func theEightSlotNamesReadSwitToNocInPolishInTheOrderOfTheDay() throws {
        let polish = try languageBundle("pl")
        #expect(
            Slot.allCases.map { WallpaperText.name(of: $0).text(from: polish) }
                == [
                    "Świt",
                    "Wschód słońca",
                    "Poranek",
                    "Południe",
                    "Popołudnie",
                    "Zachód słońca",
                    "Zmierzch",
                    "Noc",
                ],
        )
    }

    @Test func theAddButtonOfASlotIsReadWithTheSlotsNameInEnglish() throws {
        let english = try languageBundle("en")
        #expect(
            WallpaperText.addPictureToSlot.text(from: english, filledWith: "Dusk") == "Add a picture to Dusk",
        )
    }

    @Test func theAddButtonOfASlotIsReadWithTheSlotsNameInPolish() throws {
        let polish = try languageBundle("pl")
        #expect(
            WallpaperText.addPictureToSlot.text(from: polish, filledWith: "Zmierzch")
                == "Dodaj zdjęcie do pory dnia: Zmierzch",
        )
    }

    @Test func theTextsSharedWithTheLibraryKeepTheirPolishValues() throws {
        let polish = try languageBundle("pl")
        #expect(WallpaperText.goneTitle.text(from: polish) == LibraryText.wallpaperGone.text(from: polish))
        #expect(
            WallpaperText.unavailableMessage.text(from: polish) == LibraryText.unavailableMessage.text(from: polish),
        )
        #expect(WallpaperText.tryAgain.text(from: polish) == LibraryText.tryAgain.text(from: polish))
    }
}
