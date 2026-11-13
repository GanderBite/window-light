@testable import Features
import Foundation
import Testing

private func languageBundle(_ language: String) throws -> Bundle {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    return try #require(Bundle(url: languageURL))
}

struct ArrangingWordingTests {
    @Test func aMovedPictureIsAnnouncedWithTheSlotItIsNowInInEnglish() throws {
        let english = try languageBundle("en")
        #expect(
            ArrangingWording.announcement(of: .moved(from: .morning, to: .afternoon), from: english)
                == "The picture is now in Afternoon",
        )
    }

    @Test func aMovedPictureIsAnnouncedWithTheSlotItIsNowInInPolish() throws {
        let polish = try languageBundle("pl")
        #expect(
            ArrangingWording.announcement(of: .moved(from: .morning, to: .afternoon), from: polish)
                == "Zdjęcie jest teraz w porze dnia: Popołudnie",
        )
    }

    @Test func swappedPicturesAreAnnouncedWithBothSlotsInEnglish() throws {
        let english = try languageBundle("en")
        #expect(
            ArrangingWording.announcement(of: .swapped(.dawn, with: .dusk), from: english)
                == "The pictures of Dawn and Dusk changed places",
        )
    }

    @Test func swappedPicturesAreAnnouncedWithBothSlotsInPolish() throws {
        let polish = try languageBundle("pl")
        #expect(
            ArrangingWording.announcement(of: .swapped(.dawn, with: .dusk), from: polish)
                == "Zdjęcia z pór dnia Świt i Zmierzch zamieniły się miejscami",
        )
    }

    @Test func aRemovedPictureIsAnnouncedWithItsSlotInEnglish() throws {
        let english = try languageBundle("en")
        #expect(
            ArrangingWording.announcement(of: .removed(from: .night), from: english)
                == "The picture was removed from Night",
        )
    }

    @Test func aRemovedPictureIsAnnouncedWithItsSlotInPolish() throws {
        let polish = try languageBundle("pl")
        #expect(
            ArrangingWording.announcement(of: .removed(from: .night), from: polish)
                == "Usunięto zdjęcie z pory dnia: Noc",
        )
    }

    @Test func placingByTimeAgainUndoingAndRedoingAreAnnouncedInEnglish() throws {
        let english = try languageBundle("en")
        #expect(
            ArrangingWording.announcement(of: .placedByTimeAgain, from: english)
                == "The pictures were placed by time again",
        )
        #expect(ArrangingWording.announcement(of: .undone, from: english) == "The last step was undone")
        #expect(ArrangingWording.announcement(of: .redone, from: english) == "The step was done again")
    }

    @Test func placingByTimeAgainUndoingAndRedoingAreAnnouncedInPolish() throws {
        let polish = try languageBundle("pl")
        #expect(
            ArrangingWording.announcement(of: .placedByTimeAgain, from: polish)
                == "Zdjęcia ułożono ponownie według czasu",
        )
        #expect(ArrangingWording.announcement(of: .undone, from: polish) == "Cofnięto ostatni krok")
        #expect(ArrangingWording.announcement(of: .redone, from: polish) == "Ponowiono cofnięty krok")
    }

    @Test(arguments: ["en", "pl"])
    func addedPicturesAreLeftToTheImportToAnnounce(language: String) throws {
        let bundle = try languageBundle(language)
        #expect(ArrangingWording.announcement(of: .picturesAdded, from: bundle) == nil)
    }

    @Test func everyNewStepNamesItsUndoActionInEnglish() throws {
        let english = try languageBundle("en")
        let steps: [WallpaperModel.Step] = [
            .moved(from: .morning, to: .afternoon),
            .swapped(.dawn, with: .dusk),
            .removed(from: .night),
            .placedByTimeAgain,
            .picturesAdded,
        ]
        #expect(
            steps.map { ArrangingWording.undoActionName(of: $0, from: english) }
                == ["Picture Move", "Picture Swap", "Picture Removal", "Placing by Time", "Picture Addition"],
        )
    }

    @Test func everyNewStepNamesItsUndoActionInPolish() throws {
        let polish = try languageBundle("pl")
        let steps: [WallpaperModel.Step] = [
            .moved(from: .morning, to: .afternoon),
            .swapped(.dawn, with: .dusk),
            .removed(from: .night),
            .placedByTimeAgain,
            .picturesAdded,
        ]
        #expect(
            steps.map { ArrangingWording.undoActionName(of: $0, from: polish) }
                == [
                    "Przeniesienie zdjęcia",
                    "Zamiana zdjęć",
                    "Usunięcie zdjęcia",
                    "Ułożenie według czasu",
                    "Dodanie zdjęć",
                ],
        )
    }

    @Test(arguments: ["en", "pl"])
    func undoingAndRedoingNameNoUndoAction(language: String) throws {
        let bundle = try languageBundle(language)
        #expect(ArrangingWording.undoActionName(of: .undone, from: bundle) == nil)
        #expect(ArrangingWording.undoActionName(of: .redone, from: bundle) == nil)
    }
}
