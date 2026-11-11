import Testing
@testable import Domain

private func name(_ text: String) throws -> WallpaperName {
    try WallpaperName(text)
}

private func names(_ texts: [String]) throws -> [WallpaperName] {
    try texts.map { try WallpaperName($0) }
}

struct WallpaperNameTests {
    @Test func aNameKeepsItsText() throws {
        #expect(try name("Holiday").text == "Holiday")
    }

    @Test func aNameOfFiftyCharactersIsAccepted() throws {
        let text = String(repeating: "a", count: 50)
        #expect(try name(text).text == text)
    }

    @Test func aNameOfFiftyOneCharactersIsRefused() {
        #expect(throws: WallpaperNameError.tooLong(limit: 50)) {
            try WallpaperName(String(repeating: "a", count: 51))
        }
    }

    @Test(arguments: ["", "   ", "\t\n\t", " \r\n \t "])
    func aNameWithNothingLeftAfterTrimmingIsRefused(text: String) {
        #expect(throws: WallpaperNameError.empty) {
            try WallpaperName(text)
        }
    }

    @Test func spacesAroundTheNameAreRemoved() throws {
        #expect(try name("  Sea view  ").text == "Sea view")
    }

    @Test func fiftyCharactersWithSpacesAroundThemAreAccepted() throws {
        let text = String(repeating: "a", count: 50)
        #expect(try name("  \(text)  ").text == text)
    }

    @Test func fiftyEmojiBuiltFromSeveralScalarsAreFiftyCharacters() throws {
        let text = String(repeating: "👨‍👩‍👧", count: 50)
        #expect(try name(text).text == text)
    }

    @Test func namesMadeFromTheSameTextAreEqual() throws {
        #expect(try name("Holiday") == name(" Holiday "))
    }

    @Test(arguments: [("Wallpaper", "Wallpaper 1"), ("Tapeta", "Tapeta 1")])
    func theFirstDefaultNameIsNumberedOne(stem: String, expected: String) throws {
        let defaultName = try WallpaperName.defaultName(startingWith: stem, unusedAmong: [WallpaperName]())
        #expect(defaultName.text == expected)
    }

    @Test(arguments: [
        (["Wallpaper 1"], "Wallpaper 2"),
        (["Wallpaper 1", "Wallpaper 3"], "Wallpaper 2"),
        (["Wallpaper 2"], "Wallpaper 1")
    ])
    func theDefaultNameTakesTheLowestUnusedNumber(inUse: [String], expected: String) throws {
        let defaultName = try WallpaperName.defaultName(startingWith: "Wallpaper", unusedAmong: names(inUse))
        #expect(defaultName.text == expected)
    }

    @Test func theComparisonOfDefaultNamesIsExact() throws {
        let defaultName = try WallpaperName.defaultName(startingWith: "Wallpaper", unusedAmong: names(["wallpaper 1"]))
        #expect(defaultName.text == "Wallpaper 1")
    }

    @Test func aStemOfFortyNineCharactersMakesTheDefaultNameTooLong() {
        let stem = String(repeating: "a", count: 49)
        #expect(throws: WallpaperNameError.tooLong(limit: 50)) {
            try WallpaperName.defaultName(startingWith: stem, unusedAmong: [WallpaperName]())
        }
    }
}
