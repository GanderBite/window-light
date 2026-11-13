import Application
import Domain
@testable import Features
import Foundation
import Testing

private func languageBundle(_ language: String) throws -> Bundle {
    let languageURL = try #require(Bundle.module.url(forResource: language, withExtension: "lproj"))
    return try #require(Bundle(url: languageURL))
}

private func file(_ name: String) -> URL {
    URL(fileURLWithPath: "/Users/someone/Pictures/\(name)")
}

private func readable(
    _ name: String,
    fingerprint: String? = nil,
    width: Int = PixelSize.sharpDesktopWidth,
    height: Int = PixelSize.sharpDesktopHeight,
) throws -> Result<PictureFile, PictureFileError> {
    try .success(PictureFile(
        content: Data("content of \(name)".utf8),
        fingerprint: ContentFingerprint(fingerprint ?? "fingerprint of \(name)"),
        captureTime: nil,
        pixelSize: PixelSize(width: width, height: height),
    ))
}

private func sharpPictures(_ count: Int) throws -> [String: Result<PictureFile, PictureFileError>] {
    var answers: [String: Result<PictureFile, PictureFileError>] = [:]
    for number in 1 ... count {
        answers["\(number).jpg"] = try readable("\(number).jpg")
    }
    return answers
}

private let fingerprintOfTheStoredPicture = "stored picture"

private func addWallpaperWithTwoPictures(to library: WallpaperLibraryStandIn) async throws -> Wallpaper {
    let dawnPicture = try Domain.Picture(
        id: PictureID(UUID()),
        origin: .imported,
        captureTime: nil,
        fingerprint: ContentFingerprint(fingerprintOfTheStoredPicture),
    )
    let nightPicture = try Domain.Picture(
        id: PictureID(UUID()),
        origin: .imported,
        captureTime: nil,
        fingerprint: ContentFingerprint("another stored picture"),
    )
    let wallpaper = try Wallpaper(
        id: WallpaperID(UUID()),
        name: WallpaperName("Stored"),
        pictures: [.dawn: dawnPicture, .night: nightPicture],
    )
    let contents = [dawnPicture.id: Data("dawn".utf8), nightPicture.id: Data("night".utf8)]
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: contents)
    return wallpaper
}

@MainActor
private func importModel(
    over library: WallpaperLibraryStandIn,
    answering answers: [String: Result<PictureFile, PictureFileError>],
    stoppingTheImportWhenAskedFor nameOfTheFileWhoseReadStopsTheImport: String? = nil,
) -> PictureImportModel {
    var answersByFile: [URL: Result<PictureFile, PictureFileError>] = [:]
    for (name, answer) in answers {
        answersByFile[file(name)] = answer
    }
    let pictureFiles = PictureFilesStandIn(
        answering: answersByFile,
        cancellingTheAskingTaskWhenAskedFor: nameOfTheFileWhoseReadStopsTheImport.map(file),
    )
    let previews = PicturePreviewsStandIn()
    return PictureImportModel(
        createWallpaper: CreateWallpaper(library: library, previews: previews, files: pictureFiles),
        addPictures: AddPictures(library: library, previews: previews, files: pictureFiles),
        addPictureToSlot: AddPictureToSlot(library: library, previews: previews, files: pictureFiles),
        defaultWallpaperNameStem: "Wallpaper",
        wallpaperChanged: { _ in },
    )
}

@MainActor
private func outcomeOfCreatingAWallpaper(
    from answers: [String: Result<PictureFile, PictureFileError>],
) async throws -> PictureImportModel.Outcome {
    let model = importModel(over: WallpaperLibraryStandIn(), answering: answers)
    await model.importFiles(answers.keys.map(file), to: .newWallpaper)
    return try #require(model.outcome)
}

@MainActor
private func outcomeOfCreatingAWallpaperStoppedWhileReadingTheFourthOfFiveFiles() async throws
    -> PictureImportModel.Outcome
{
    var answers = try sharpPictures(5)
    answers["4.jpg"] = .failure(.unexpected(description: "The read was interrupted."))
    let model = importModel(
        over: WallpaperLibraryStandIn(),
        answering: answers,
        stoppingTheImportWhenAskedFor: "4.jpg",
    )
    let chosenFiles = answers.keys.map(file)
    await Task { await model.importFiles(chosenFiles, to: .newWallpaper) }.value
    return try #require(model.outcome)
}

@MainActor
private func outcomeWithEveryReasonForSkippingAFile() async throws -> PictureImportModel.Outcome {
    let library = WallpaperLibraryStandIn()
    let wallpaper = try await addWallpaperWithTwoPictures(to: library)
    await library.fail(.keepAdding, with: .noSpaceLeft)
    let answers: [String: Result<PictureFile, PictureFileError>] = try [
        "a.jpg": .failure(.notAPicture),
        "b.jpg": .failure(.damaged),
        "c.jpg": .failure(.notFound),
        "d.jpg": readable("d.jpg", fingerprint: fingerprintOfTheStoredPicture),
        "e.jpg": readable("e.jpg", fingerprint: "twin"),
        "f.jpg": readable("f.jpg", fingerprint: "twin"),
    ]
    let model = importModel(over: library, answering: answers)
    await model.importFiles(answers.keys.map(file), to: .wallpaper(wallpaper.id))
    return try #require(model.outcome)
}

private let namesOfTheSkippedFiles = ["a.jpg", "b.jpg", "c.jpg", "d.jpg", "e.jpg", "f.jpg"]

private func everyRefusal() -> [PictureImportModel.Refusal] {
    [
        .tooFewFiles(fewest: 2),
        .tooManyFiles(most: 8),
        .noEmptySlot,
        .moreFilesThanEmptySlots(emptySlots: 3),
        .oneFileForASlot,
        .slotHoldsRealPicture(.dawn),
        .wallpaperGone,
        .couldNotImport,
    ]
}

@MainActor
struct PictureImportWordingTests {
    @Test func fivePicturesAddedReadInEnglishAndPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: sharpPictures(5))
        #expect(try outcome.wording(from: languageBundle("en")).headline == "5 pictures added")
        #expect(try outcome.wording(from: languageBundle("pl")).headline == "Dodano 5 zdjęć")
    }

    @Test func threePicturesAddedReadInPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: sharpPictures(3))
        #expect(try outcome.wording(from: languageBundle("pl")).headline == "Dodano 3 zdjęcia")
    }

    @Test func onePictureAddedWithADamagedFileReadsInEnglishAndPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "good.jpg": readable("good.jpg"),
            "broken.jpg": .failure(.damaged),
        ])
        let english = try outcome.wording(from: languageBundle("en"))
        let polish = try outcome.wording(from: languageBundle("pl"))
        #expect(english.headline == "1 picture added")
        #expect(polish.headline == "Dodano 1 zdjęcie")
        #expect(english.notes.first == "“broken.jpg” is damaged and couldn't be opened.")
        #expect(polish.notes.first?.contains("broken.jpg") == true)
        #expect(polish.notes.first != english.notes.first)
    }

    @Test func aSoundOnlyFileIsNamedInEnglishAndPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "good.jpg": readable("good.jpg"),
            "concert.m4a": .failure(.soundOnly),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).notes.first
            == "“concert.m4a” has sound only, so there is no picture to take from it.")
        #expect(try outcome.wording(from: languageBundle("pl")).notes.first
            == "Plik „concert.m4a” zawiera tylko dźwięk, więc nie ma w nim obrazu, z którego powstałoby zdjęcie.")
    }

    @Test func aCopyProtectedFileIsNamedInEnglishAndPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "good.jpg": readable("good.jpg"),
            "film.mov": .failure(.copyProtected),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).notes.first
            == "“film.mov” is copy-protected, so Window Light can't take a picture from it.")
        #expect(try outcome.wording(from: languageBundle("pl")).notes.first
            == "Plik „film.mov” jest chroniony przed kopiowaniem, więc Window Light nie może pobrać z niego zdjęcia.")
    }

    @Test func noPicturesAddedReadsAsSuch() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "a.jpg": .failure(.damaged),
            "b.jpg": .failure(.notAPicture),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).headline == "No pictures were added")
        #expect(try outcome.wording(from: languageBundle("pl")).headline == "Nie dodano żadnego zdjęcia")
    }

    @Test func eachReasonForSkippingAFileGivesItsOwnNoteAfterTheStoppedNote() async throws {
        let outcome = try await outcomeWithEveryReasonForSkippingAFile()
        try #require(outcome.summary.skippedFiles.count == 6)
        #expect(try outcome.wording(from: languageBundle("en")).notes == [
            "Your Mac ran out of storage, so the import stopped. Pictures already added are kept.",
            "“a.jpg” isn't a picture or video Window Light can use.",
            "“b.jpg” is damaged and couldn't be opened.",
            "“c.jpg” couldn't be read.",
            "“d.jpg” is already in this wallpaper.",
            "“e.jpg” wasn't added because your Mac has no storage left.",
            "“f.jpg” is the same as another file you chose.",
        ])
    }

    @Test func eachReasonForSkippingAFileGivesItsOwnNoteNamingTheFileInPolish() async throws {
        let outcome = try await outcomeWithEveryReasonForSkippingAFile()
        let notes = try outcome.wording(from: languageBundle("pl")).notes
        try #require(notes.count == 7)
        #expect(notes
            .first == "Na Macu zabrakło miejsca, więc import został przerwany. Dodane już zdjęcia zostały zachowane.")
        let skippedNotes = Array(notes.dropFirst())
        for (note, name) in zip(skippedNotes, namesOfTheSkippedFiles) {
            #expect(note.contains("„\(name)”"))
        }
        let notesWithoutTheirNames = zip(skippedNotes, namesOfTheSkippedFiles).map { note, name in
            note.replacingOccurrences(of: name, with: "")
        }
        #expect(Set(notesWithoutTheirNames).count == namesOfTheSkippedFiles.count)
    }

    @Test func aFileThatMayLookBlurryIsNamedWithTheSharpSize() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "sharp.jpg": readable("sharp.jpg"),
            "small.jpg": readable("small.jpg", width: 800, height: 600),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).notes == [
            "“small.jpg” is smaller than 1920 × 1080 and may look blurry on the desktop.",
        ])
        let polishNotes = try outcome.wording(from: languageBundle("pl")).notes
        #expect(polishNotes.count == 1)
        #expect(polishNotes.first?.contains("small.jpg") == true)
        #expect(polishNotes.first?.contains("1920 × 1080") == true)
    }

    @Test func aFileThatIsNeitherAPictureNorAVideoIsNamedInEnglishAndPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "good.jpg": readable("good.jpg"),
            "notes.txt": .failure(.notAPicture),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).notes.first
            == "“notes.txt” isn't a picture or video Window Light can use.")
        #expect(try outcome.wording(from: languageBundle("pl")).notes.first
            == "„notes.txt” nie jest zdjęciem ani filmem, którego Window Light może użyć.")
    }

    @Test func aVideoThatMayLookBlurryIsNamedWithTheSharpSize() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "sharp.mov": readable("sharp.mov"),
            "clip.mov": readable("clip.mov", width: 1280, height: 720),
        ])
        #expect(try outcome.wording(from: languageBundle("en")).notes == [
            "“clip.mov” is smaller than 1920 × 1080 and may look blurry on the desktop.",
        ])
    }

    @Test func aWallpaperThatNeedsMorePicturesEndsTheNotesSayingSo() async throws {
        let outcome = try await outcomeOfCreatingAWallpaper(from: [
            "good.jpg": readable("good.jpg"),
            "broken.jpg": .failure(.damaged),
        ])
        try #require(outcome.wallpaperNeedsMorePictures)
        #expect(
            try outcome.wording(from: languageBundle("en")).notes.last
                == "This wallpaper needs at least two pictures before it can be applied.",
        )
        #expect(
            try outcome.wording(from: languageBundle("pl")).notes.last
                == "Ta tapeta potrzebuje co najmniej dwóch zdjęć, zanim będzie można ją zastosować.",
        )
    }

    @Test func tooManyFilesNamesTheMostInBothLanguages() throws {
        let refusal = PictureImportModel.Refusal.tooManyFiles(most: 8)
        #expect(try refusal.message(from: languageBundle("en"))
            == "A wallpaper can have at most 8 pictures. Choose fewer files.")
        #expect(try refusal
            .message(from: languageBundle("pl")) == "Tapeta może mieć najwyżej 8 zdjęć. Wybierz mniej plików.")
    }

    @Test func tooFewFilesNamesTheFewestInBothLanguages() throws {
        let refusal = PictureImportModel.Refusal.tooFewFiles(fewest: 2)
        #expect(try refusal.message(from: languageBundle("en")) == "Choose at least 2 files to create a wallpaper.")
        #expect(try refusal.message(from: languageBundle("pl")) == "Wybierz co najmniej 2 pliki, aby utworzyć tapetę.")
    }

    @Test func moreFilesThanEmptySlotsNamesTheFreeTimesOfDayInBothLanguages() throws {
        let refusal = PictureImportModel.Refusal.moreFilesThanEmptySlots(emptySlots: 3)
        #expect(try refusal.message(from: languageBundle("en"))
            == "Only 3 times of day are free. Choose that many files or fewer.")
        #expect(try refusal.message(from: languageBundle("pl"))
            == "Wolne są tylko 3 pory dnia. Wybierz najwyżej tyle plików.")
    }

    @Test(arguments: ["en", "pl"])
    func eachRefusalHasAMessageOfItsOwn(language: String) throws {
        let bundle = try languageBundle(language)
        let messages = everyRefusal().map { $0.message(from: bundle) }
        #expect(Set(messages).count == everyRefusal().count)
        #expect(!messages.contains(""))
    }

    @Test func eachRefusalReadsDifferentlyInPolishThanInEnglish() throws {
        let english = try languageBundle("en")
        let polish = try languageBundle("pl")
        for refusal in everyRefusal() {
            #expect(refusal.message(from: english) != refusal.message(from: polish))
        }
    }

    @Test func aStoppedImportSaysSoFirstAndNamesEachFileItDidNotAddInEnglish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaperStoppedWhileReadingTheFourthOfFiveFiles()
        #expect(try outcome.wording(from: languageBundle("en")).notes == [
            "You stopped the import. Pictures already added are kept.",
            "“4.jpg” wasn't added because you stopped the import.",
            "“5.jpg” wasn't added because you stopped the import.",
        ])
    }

    @Test func aStoppedImportSaysSoFirstAndNamesEachFileItDidNotAddInPolish() async throws {
        let outcome = try await outcomeOfCreatingAWallpaperStoppedWhileReadingTheFourthOfFiveFiles()
        #expect(try outcome.wording(from: languageBundle("pl")).notes == [
            "Import został zatrzymany. Dodane już zdjęcia zostały zachowane.",
            "Nie dodano pliku „4.jpg”, bo import został zatrzymany.",
            "Nie dodano pliku „5.jpg”, bo import został zatrzymany.",
        ])
    }
}
