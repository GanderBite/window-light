@testable import Features
import Foundation
import Testing

private func languageBundle(_ language: String) throws -> Bundle {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    return try #require(Bundle(url: languageURL))
}

struct LibraryTextTests {
    @Test(arguments: LibraryText.allCases, ["en", "pl"])
    func everyTextHasAValueInEveryLanguage(libraryText: LibraryText, language: String) throws {
        let bundle = try languageBundle(language)
        let textThatNoCatalogueHolds = "<missing text>"
        let found = bundle.localizedString(forKey: libraryText.key, value: textThatNoCatalogueHolds, table: nil)
        #expect(found != textThatNoCatalogueHolds)
        #expect(libraryText.text(from: bundle) == found)
    }

    @Test func theEmptyExplanationSaysWhatAWallpaperIsInEnglish() throws {
        #expect(
            try LibraryText.emptyExplanation.text(from: languageBundle("en"))
                == "A wallpaper is two to eight of your own pictures. Your Mac changes between them through the day.",
        )
    }

    @Test func theEmptyExplanationSaysWhatAWallpaperIsInPolish() throws {
        #expect(
            try LibraryText.emptyExplanation.text(from: languageBundle("pl"))
                == "Tapeta to od dwóch do ośmiu Twoich zdjęć. Mac zmienia je w ciągu dnia.",
        )
    }

    @Test func threePicturesReadThreeOfEightInEnglish() throws {
        #expect(try LibraryText.picturesOfEight.text(from: languageBundle("en"), filledWith: 3) == "3 of 8 pictures")
    }

    @Test func threePicturesReadThreeOfEightInPolish() throws {
        #expect(try LibraryText.picturesOfEight.text(from: languageBundle("pl"), filledWith: 3) == "3 z 8 zdjęć")
    }

    @Test func theDeleteQuestionNamesTheWallpaperInEnglish() throws {
        #expect(try LibraryText.deleteQuestion
            .text(from: languageBundle("en"), filledWith: "Summer") == "Delete “Summer”?")
    }

    @Test func theDeleteQuestionNamesTheWallpaperInPolish() throws {
        #expect(
            try LibraryText.deleteQuestion
                .text(from: languageBundle("pl"), filledWith: "Summer") == "Usunąć tapetę „Summer”?",
        )
    }

    @Test func aTooLongNameNamesTheLimitInEnglish() throws {
        #expect(
            try LibraryText.nameTooLong.text(from: languageBundle("en"), filledWith: 50)
                == "A name can have up to 50 characters.",
        )
    }

    @Test func aTooLongNameNamesTheLimitInPolish() throws {
        #expect(
            try LibraryText.nameTooLong.text(from: languageBundle("pl"), filledWith: 50)
                == "Nazwa może mieć najwyżej 50 znaków.",
        )
    }

    @Test func theDefaultNameStemIsWallpaperInEnglish() throws {
        #expect(try LibraryText.defaultNameStem.text(from: languageBundle("en")) == "Wallpaper")
    }

    @Test func theDefaultNameStemIsTapetaInPolish() throws {
        #expect(try LibraryText.defaultNameStem.text(from: languageBundle("pl")) == "Tapeta")
    }

    @Test @MainActor func theScreenOffersTheDefaultNameStemInTheAppLanguage() {
        #expect(LibraryScreen.defaultWallpaperNameStem == LibraryText.defaultNameStem.text(from: .module))
        #expect(["Wallpaper", "Tapeta"].contains(LibraryScreen.defaultWallpaperNameStem))
    }
}
