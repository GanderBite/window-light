@testable import Features
import Foundation
import Testing

private func languageBundle(_ language: String) throws -> Bundle {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    return try #require(Bundle(url: languageURL))
}

struct PictureImportTextTests {
    @Test(arguments: PictureImportText.allCases, ["en", "pl"])
    func everyTextHasAValueInEveryLanguage(importText: PictureImportText, language: String) throws {
        let bundle = try languageBundle(language)
        let textThatNoCatalogueHolds = "<missing text>"
        let found = bundle.localizedString(forKey: importText.key, value: textThatNoCatalogueHolds, table: nil)
        #expect(found != textThatNoCatalogueHolds)
        #expect(importText.text(from: bundle) == found)
    }

    @Test func theSignOfWorkSaysPicturesAreBeingImportedInEnglish() throws {
        #expect(try PictureImportText.importing.text(from: languageBundle("en")) == "Importing pictures")
    }

    @Test func theSignOfWorkSaysPicturesAreBeingImportedInPolish() throws {
        #expect(try PictureImportText.importing.text(from: languageBundle("pl")) == "Importowanie zdjęć")
    }

    @Test func oneFreeTimeOfDayAsksForOneFileInEnglish() throws {
        #expect(
            try PictureImportText.moreFilesThanEmptySlots.text(from: languageBundle("en"), filledWith: 1)
                == "Only 1 time of day is free. Choose one file.",
        )
    }

    @Test func fiveFreeTimesOfDayUseTheManyFormInPolish() throws {
        #expect(
            try PictureImportText.moreFilesThanEmptySlots.text(from: languageBundle("pl"), filledWith: 5)
                == "Wolnych jest tylko 5 pór dnia. Wybierz najwyżej tyle plików.",
        )
    }

    @Test func theTextsSharedWithTheLibraryKeepTheirPolishValues() throws {
        let polish = try languageBundle("pl")
        #expect(PictureImportText.wallpaperGone.text(from: polish) == LibraryText.wallpaperGone.text(from: polish))
        #expect(PictureImportText.ok.text(from: polish) == LibraryText.ok.text(from: polish))
    }
}
