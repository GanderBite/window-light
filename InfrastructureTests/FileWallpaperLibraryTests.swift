import Application
import Domain
import Foundation
@testable import Infrastructure
import Testing

private let readOnlyPermissions = 0o555
private let writablePermissions = 0o755
private let sizeOfARealPreview = 20000

private struct LibraryFolder {
    let surroundings: URL
    let url: URL

    static func make() throws -> Self {
        let surroundings = FileManager.default.temporaryDirectory
            .appending(path: "FileWallpaperLibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let url = surroundings.appending(path: "Library", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return Self(surroundings: surroundings, url: url)
    }

    func library() -> FileWallpaperLibrary {
        FileWallpaperLibrary(folder: url)
    }

    var wallpapersFolder: URL {
        url.appending(path: "Wallpapers", directoryHint: .isDirectory)
    }

    func wallpaperFolder(of wallpaper: Wallpaper) -> URL {
        wallpapersFolder.appending(path: wallpaper.id.value.uuidString, directoryHint: .isDirectory)
    }

    func documentFile(of wallpaper: Wallpaper) -> URL {
        wallpaperFolder(of: wallpaper).appending(path: "Wallpaper.json")
    }

    func storedContentFile(of picture: Picture, in wallpaper: Wallpaper) -> URL {
        wallpaperFolder(of: wallpaper).appending(path: "Pictures/\(picture.id.value.uuidString)")
    }

    var beingAddedFolder: URL {
        url.appending(path: "BeingAdded", directoryHint: .isDirectory)
    }

    var lastWorkedOnFile: URL {
        url.appending(path: "LastWorkedOn")
    }

    func storedDocument(of wallpaper: Wallpaper) throws -> [String: Any] {
        let content = try Data(contentsOf: documentFile(of: wallpaper))
        return try #require(try JSONSerialization.jsonObject(with: content) as? [String: Any])
    }

    func replaceStoredDocument(of wallpaper: Wallpaper, changing change: (inout [String: Any]) -> Void) throws {
        var document = try storedDocument(of: wallpaper)
        change(&document)
        try JSONSerialization.data(withJSONObject: document).write(to: documentFile(of: wallpaper))
    }

    func pathsOfEverythingInside() -> [String] {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
        return (enumerator?.allObjects as? [URL] ?? []).map(\.path)
    }

    func totalSizeOfFiles() throws -> Int {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        )
        var total = 0
        for case let item as URL in enumerator?.allObjects ?? [] {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                total += values.fileSize ?? 0
            }
        }
        return total
    }

    func setPermissionsOfEveryFolder(to permissions: Int) throws {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey])
        var folders = [url]
        for case let item as URL in enumerator?.allObjects ?? []
            where try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        {
            folders.append(item)
        }
        for folder in folders {
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: folder.path)
        }
    }

    func remove() {
        try? setPermissionsOfEveryFolder(to: writablePermissions)
        try? FileManager.default.removeItem(at: surroundings)
    }
}

private func withLibraryFolder(_ test: (LibraryFolder) async throws -> Void) async throws {
    let folder = try LibraryFolder.make()
    defer { folder.remove() }
    try await test(folder)
}

private func wallpaper(
    named name: String = "Lisbon",
    filling slots: [Slot] = [.dawn, .midday, .night],
) throws -> Wallpaper {
    var pictures: [Slot: Picture] = [:]
    for slot in slots {
        pictures[slot] = try picture(origin: .imported, captureTime: nil)
    }
    return try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(name), pictures: pictures)
}

private func picture(origin: PictureOrigin, captureTime: CaptureTime?) throws -> Picture {
    let id = PictureID(UUID())
    return try Picture(
        id: id,
        origin: origin,
        captureTime: captureTime,
        fingerprint: ContentFingerprint("fingerprint of \(id.value.uuidString)"),
    )
}

private func wallpaperOfEveryKindOfPicture() throws -> Wallpaper {
    try Wallpaper(
        id: WallpaperID(UUID()),
        name: WallpaperName("Kinds"),
        pictures: [
            .dawn: picture(
                origin: .imported,
                captureTime: CaptureTime(year: 2026, month: 6, day: 21, hour: 5, minute: 30, second: 0),
            ),
            .midday: picture(origin: .imported, captureTime: nil),
            .night: picture(origin: .madeWithAI, captureTime: nil),
        ],
    )
}

enum DocumentDamage: CaseIterable {
    case formatVersionOne
    case unknownOrigin
    case captureTimeThatIsNoDate
    case emptyFingerprint
}

private func contents(of wallpaper: Wallpaper) -> [PictureID: Data] {
    var contents: [PictureID: Data] = [:]
    for picture in wallpaper.picturesInDayOrder {
        contents[picture.id] = Data("content of picture \(picture.id.value.uuidString)".utf8)
    }
    return contents
}

private func previews(of wallpaper: Wallpaper, eachOfSize size: Int = 64) -> [PictureID: Data] {
    var previews: [PictureID: Data] = [:]
    for picture in wallpaper.picturesInDayOrder {
        let label = Data("preview of picture \(picture.id.value.uuidString)".utf8)
        previews[picture.id] = label + Data(repeating: 0x5A, count: max(0, size - label.count))
    }
    return previews
}

private func add(_ wallpaper: Wallpaper, to library: FileWallpaperLibrary) async throws {
    try await library.add(wallpaper, pictureContents: contents(of: wallpaper), picturePreviews: previews(of: wallpaper))
}

private func renamed(_ wallpaper: Wallpaper, to newName: String) throws -> Wallpaper {
    var renamedWallpaper = wallpaper
    try renamedWallpaper.rename(to: WallpaperName(newName))
    return renamedWallpaper
}

enum RefusedContent: CaseIterable {
    case nameThatIsNotAllowed
    case noPictures
    case onePictureInTwoSlots
}

enum MissingPart: CaseIterable {
    case content
    case preview
}

struct FileWallpaperLibraryTests {
    @Test func aLibraryInANewEmptyFolderHasNoWallpapersAndNoWallpaperLastWorkedOn() async throws {
        try await withLibraryFolder { (folder: LibraryFolder) async throws in
            let library = folder.library()

            #expect(try await library.wallpapers().isEmpty)
            #expect(try await library.wallpaperLastWorkedOn() == nil)
        }
    }

    @Test func anAddedWallpaperComesBackWithItsIdNameAndPictureInEverySlotAfterARestart(
    ) async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaper(named: "Porto at noon", filling: Slot.allCases)
            try await add(original, to: folder.library())

            let restored = try await folder.library().wallpaper(original.id)

            #expect(restored.id == original.id)
            #expect(restored.name == original.name)
            #expect(Slot.allCases.map { restored.picture(in: $0) } == Slot.allCases.map { original.picture(in: $0) })
            #expect(try await folder.library().wallpapers() == [original])
        }
    }

    @Test func wallpapersComeBackInTheOrderTheyWereAddedAlsoAfterARestartAndAfterTheFirstWasRenamed(
    ) async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let first = try wallpaper(named: "Zurich")
            let second = try wallpaper(named: "Athens")
            let third = try wallpaper(named: "Madrid")
            for added in [first, second, third] {
                try await add(added, to: library)
            }

            #expect(try await library.wallpapers().map(\.id) == [first.id, second.id, third.id])
            #expect(try await folder.library().wallpapers().map(\.id) == [first.id, second.id, third.id])

            let renamedFirst = try renamed(first, to: "Lisbon")
            try await library.keep(renamedFirst)

            #expect(try await folder.library().wallpapers() == [renamedFirst, second, third])
        }
    }

    @Test func aWallpaperAddedAfterEarlierOnesWereRemovedComesLast() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let first = try wallpaper(named: "Zurich")
            let second = try wallpaper(named: "Athens")
            let third = try wallpaper(named: "Madrid")
            let fourth = try wallpaper(named: "Bergen")
            try await add(first, to: library)
            try await add(second, to: library)
            try await add(third, to: library)
            try await library.remove(first.id)
            try await library.remove(second.id)
            try await add(fourth, to: library)

            #expect(try await folder.library().wallpapers().map(\.id) == [third.id, fourth.id])
        }
    }

    @Test func picturePreviewsAreExactlyThePreviewBytesGivenToAdd() async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaper(filling: [.sunrise, .afternoon, .dusk])
            let givenPreviews = previews(of: original, eachOfSize: 300)
            try await folder.library().add(
                original,
                pictureContents: contents(of: original),
                picturePreviews: givenPreviews,
            )

            #expect(try await folder.library().picturePreviews(of: original.id) == givenPreviews)
        }
    }

    @Test func theStoredContentOfEveryPictureIsTheGivenBytesAndOutlivesTheFileItWasReadFrom(
    ) async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaper(filling: [.dawn, .sunset])
            var givenContents: [PictureID: Data] = [:]
            for (pictureID, content) in contents(of: original) {
                let importedFile = folder.surroundings.appending(path: "Imported-\(pictureID.value.uuidString)")
                try content.write(to: importedFile)
                givenContents[pictureID] = try Data(contentsOf: importedFile)
            }
            try await folder.library().add(
                original,
                pictureContents: givenContents,
                picturePreviews: previews(of: original),
            )
            for pictureID in givenContents.keys {
                try FileManager.default
                    .removeItem(at: folder.surroundings.appending(path: "Imported-\(pictureID.value.uuidString)"))
            }

            #expect(try await folder.library().wallpaper(original.id) == original)
            for picture in original.picturesInDayOrder {
                #expect(try Data(contentsOf: folder.storedContentFile(of: picture, in: original)) ==
                    givenContents[picture.id])
            }
        }
    }

    @Test func afterKeepWithANewNameARestartedLibraryReturnsTheNewName() async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaper(named: "Before")
            try await add(original, to: folder.library())

            try await folder.library().keep(renamed(original, to: "After"))

            #expect(try await folder.library().wallpaper(original.id).name.text == "After")
        }
    }

    @Test func everyPictureComesBackWithItsIdOriginCaptureTimeAndFingerprintInItsSlotAfterARestart(
    ) async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaperOfEveryKindOfPicture()
            try await add(original, to: folder.library())

            let restored = try await folder.library().wallpaper(original.id)

            for slot in Slot.allCases {
                let originalPicture = original.picture(in: slot)
                let restoredPicture = restored.picture(in: slot)
                #expect(restoredPicture?.id == originalPicture?.id)
                #expect(restoredPicture?.origin == originalPicture?.origin)
                #expect(restoredPicture?.captureTime == originalPicture?.captureTime)
                #expect(restoredPicture?.fingerprint == originalPicture?.fingerprint)
            }
            #expect(restored.filledSlotCount == 3)
        }
    }

    @Test func theStoredDocumentHasFormatVersionTwoAndAPictureWithoutACaptureTimeHasNoCaptureTimeKey(
    ) async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaperOfEveryKindOfPicture()
            try await add(original, to: folder.library())

            let document = try folder.storedDocument(of: original)

            #expect(document["formatVersion"] as? Int == 2)
            let pictures = try #require(document["pictures"] as? [String: [String: String]])
            #expect(pictures["dawn"]?["captureTime"] == "2026-06-21T05:30:00")
            #expect(pictures["dawn"]?["origin"] == "imported")
            #expect(pictures["night"]?["origin"] == "madeWithAI")
            let middayPicture = try #require(pictures["midday"])
            #expect(middayPicture["captureTime"] == nil)
            #expect(Set(middayPicture.keys) == ["id", "origin", "fingerprint"])
        }
    }

    @Test(arguments: DocumentDamage.allCases)
    func aStoredDocumentWithAnOutdatedVersionOrAPictureThatCannotBeTrustedMakesTheLibraryUnreadable(
        damage: DocumentDamage,
    ) async throws {
        try await withLibraryFolder { folder in
            let stored = try wallpaperOfEveryKindOfPicture()
            try await add(stored, to: folder.library())
            try folder.replaceStoredDocument(of: stored) { document in
                guard var pictures = document["pictures"] as? [String: [String: String]] else { return }

                switch damage {
                case .formatVersionOne: document["formatVersion"] = 1
                case .unknownOrigin: pictures["dawn"]?["origin"] = "drawn"
                case .captureTimeThatIsNoDate: pictures["dawn"]?["captureTime"] = "2026-02-30T10:00:00"
                case .emptyFingerprint: pictures["dawn"]?["fingerprint"] = ""
                }
                document["pictures"] = pictures
            }

            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpapers()
            }
            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpaper(stored.id)
            }
        }
    }

    @Test func theStoredDocumentUsesTheFixedSlotWords() async throws {
        try await withLibraryFolder { folder in
            let original = try wallpaper(filling: Slot.allCases)
            try await add(original, to: folder.library())

            let document = try folder.storedDocument(of: original)

            let pictures = try #require(document["pictures"] as? [String: [String: String]])
            #expect(Set(pictures.keys) == [
                "dawn",
                "sunrise",
                "morning",
                "midday",
                "afternoon",
                "sunset",
                "dusk",
                "night",
            ])
            #expect(pictures["midday"]?["id"] == original.picture(in: .midday)?.id.value.uuidString)
        }
    }

    @Test func askingForAWallpaperNotInTheLibraryThrowsNotFound() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            try await add(wallpaper(), to: library)

            await #expect(throws: WallpaperLibraryError.notFound) {
                try await library.wallpaper(WallpaperID(UUID()))
            }
        }
    }

    @Test func askingForThePreviewsOfAWallpaperNotInTheLibraryThrowsNotFound() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            try await add(wallpaper(), to: library)

            await #expect(throws: WallpaperLibraryError.notFound) {
                try await library.picturePreviews(of: WallpaperID(UUID()))
            }
        }
    }

    @Test func keepingAWallpaperNotInTheLibraryThrowsNotFoundAndStoresNothing() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let stored = try wallpaper()
            try await add(stored, to: library)
            let stranger = try wallpaper(named: "Stranger")

            await #expect(throws: WallpaperLibraryError.notFound) {
                try await library.keep(stranger)
            }
            #expect(try await folder.library().wallpapers() == [stored])
        }
    }

    @Test func rememberingAWallpaperNotInTheLibraryAsLastWorkedOnThrowsNotFound() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            try await add(wallpaper(), to: library)

            await #expect(throws: WallpaperLibraryError.notFound) {
                try await library.rememberAsLastWorkedOn(WallpaperID(UUID()))
            }
            #expect(try await library.wallpaperLastWorkedOn() == nil)
        }
    }

    @Test(arguments: MissingPart.allCases)
    func addingAWallpaperWithAPictureMissingAPartThrowsUnexpectedAndStoresNothing(
        missing: MissingPart,
    ) async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let earlier = try wallpaper(named: "Earlier")
            try await add(earlier, to: library)
            let incomplete = try wallpaper(named: "Incomplete")
            let pictureWithoutPart = try #require(incomplete.picturesInDayOrder.last)
            var givenContents = contents(of: incomplete)
            var givenPreviews = previews(of: incomplete)
            switch missing {
            case .content: givenContents[pictureWithoutPart.id] = nil
            case .preview: givenPreviews[pictureWithoutPart.id] = nil
            }

            await #expect {
                try await library.add(incomplete, pictureContents: givenContents, picturePreviews: givenPreviews)
            } throws: { error in
                guard case .unexpected = error as? WallpaperLibraryError else { return false }

                return true
            }
            #expect(try await library.wallpapers() == [earlier])
            #expect(try await folder.library().wallpapers() == [earlier])
            let pathsNamingTheIncompleteWallpaper = folder.pathsOfEverythingInside().filter { path in
                path.contains(incomplete.id.value.uuidString)
                    || incomplete.picturesInDayOrder.contains { path.contains($0.id.value.uuidString) }
            }
            #expect(pathsNamingTheIncompleteWallpaper.isEmpty)
        }
    }

    @Test func addingIntoAFolderThatCannotBeWrittenThrowsNotPermittedAndLeavesTheLibraryAsItWas(
    ) async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let earlier = try wallpaper(named: "Earlier")
            try await add(earlier, to: library)
            let refused = try wallpaper(named: "Refused")

            try folder.setPermissionsOfEveryFolder(to: readOnlyPermissions)
            await #expect(throws: WallpaperLibraryError.notPermitted) {
                try await add(refused, to: library)
            }
            await #expect(throws: WallpaperLibraryError.notPermitted) {
                try await add(refused, to: folder.library())
            }
            try folder.setPermissionsOfEveryFolder(to: writablePermissions)

            #expect(try await library.wallpapers() == [earlier])
            #expect(try await folder.library().wallpapers() == [earlier])
            #expect(!folder.pathsOfEverythingInside().contains { $0.contains(refused.id.value.uuidString) })
        }
    }

    @Test func anAddThatFailsAfterBuildingTheWallpaperRemovesWhatItBuilt() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let earlier = try wallpaper(named: "Earlier")
            try await add(earlier, to: library)
            let refused = try wallpaper(named: "Refused", filling: Slot.allCases)

            try FileManager.default.setAttributes(
                [.posixPermissions: readOnlyPermissions],
                ofItemAtPath: folder.wallpapersFolder.path,
            )
            await #expect(throws: WallpaperLibraryError.notPermitted) {
                try await add(refused, to: library)
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: writablePermissions],
                ofItemAtPath: folder.wallpapersFolder.path,
            )

            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.beingAddedFolder.path).isEmpty)
            #expect(!folder.pathsOfEverythingInside().contains { $0.contains(refused.id.value.uuidString) })
            #expect(try await folder.library().wallpapers() == [earlier])
        }
    }

    @Test func aWallpaperFolderWithoutItsDocumentMakesTheLibraryUnreadableWhileThatWallpaperIsNotFound(
    ) async throws {
        try await withLibraryFolder { folder in
            let incomplete = try wallpaper()
            try await add(incomplete, to: folder.library())
            try FileManager.default.removeItem(at: folder.documentFile(of: incomplete))

            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpapers()
            }
            await #expect(throws: WallpaperLibraryError.notFound) {
                try await folder.library().wallpaper(incomplete.id)
            }
        }
    }

    @Test func aLibraryWhoseFolderCannotBeMadeThrowsUnavailable() async throws {
        try await withLibraryFolder { folder in
            let regularFile = folder.surroundings.appending(path: "NotAFolder")
            try Data("a file, not a folder".utf8).write(to: regularFile)
            let library = FileWallpaperLibrary(folder: regularFile.appending(
                path: "Library",
                directoryHint: .isDirectory,
            ))

            await #expect(throws: WallpaperLibraryError.unavailable) {
                try await library.wallpapers()
            }
        }
    }

    @Test func removingAWallpaperTakesItOutForGoodAndGivesItsSpaceBack() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let kept = try wallpaper(named: "Kept")
            try await add(kept, to: library)
            let sizeBefore = try folder.totalSizeOfFiles()
            let removed = try wallpaper(named: "Removed", filling: Slot.allCases)
            try await library.add(
                removed,
                pictureContents: contents(of: removed),
                picturePreviews: previews(of: removed, eachOfSize: sizeOfARealPreview),
            )

            try await library.remove(removed.id)

            #expect(try await folder.library().wallpapers() == [kept])
            await #expect(throws: WallpaperLibraryError.notFound) {
                try await folder.library().wallpaper(removed.id)
            }
            #expect(!FileManager.default.fileExists(atPath: folder.wallpaperFolder(of: removed).path))
            #expect(try folder.totalSizeOfFiles() == sizeBefore)
        }
    }

    @Test func removingAWallpaperNotInTheLibrarySucceedsAndLeavesTheOthersUnchanged() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let first = try wallpaper(named: "First")
            let second = try wallpaper(named: "Second")
            try await add(first, to: library)
            try await add(second, to: library)

            try await library.remove(WallpaperID(UUID()))

            #expect(try await folder.library().wallpapers() == [first, second])
            #expect(try await folder.library().picturePreviews(of: first.id) == previews(of: first))
        }
    }

    @Test func aFileOutsideTheLibraryWithTheSameBytesAsAPictureIsLeftAloneByAddKeepAndRemove(
    ) async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let original = try wallpaper()
            let picture = try #require(original.picturesInDayOrder.first)
            let outsideFile = folder.surroundings.appending(path: "Original picture")
            let outsideBytes = try #require(contents(of: original)[picture.id])
            try outsideBytes.write(to: outsideFile)
            var givenContents = contents(of: original)
            givenContents[picture.id] = try Data(contentsOf: outsideFile)

            try await library.add(original, pictureContents: givenContents, picturePreviews: previews(of: original))
            #expect(try Data(contentsOf: outsideFile) == outsideBytes)

            try await library.keep(renamed(original, to: "Renamed"))
            #expect(try Data(contentsOf: outsideFile) == outsideBytes)

            try await library.remove(original.id)
            #expect(try Data(contentsOf: outsideFile) == outsideBytes)
            let surroundingsAfterwards = try FileManager.default.contentsOfDirectory(atPath: folder.surroundings.path)
            #expect(Set(surroundingsAfterwards) == ["Library", "Original picture"])
        }
    }

    @Test func theWallpaperLastWorkedOnIsRememberedAcrossARestartUntilItIsRemoved() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let first = try wallpaper(named: "First")
            let second = try wallpaper(named: "Second")
            try await add(first, to: library)
            try await add(second, to: library)

            try await library.rememberAsLastWorkedOn(second.id)
            #expect(try await folder.library().wallpaperLastWorkedOn() == second.id)

            try await folder.library().remove(second.id)
            #expect(try await folder.library().wallpaperLastWorkedOn() == nil)
            #expect(!FileManager.default.fileExists(atPath: folder.lastWorkedOnFile.path))
        }
    }

    @Test func removingAWallpaperOtherThanTheLastWorkedOnKeepsTheLastWorkedOn() async throws {
        try await withLibraryFolder { folder in
            let library = folder.library()
            let first = try wallpaper(named: "First")
            let second = try wallpaper(named: "Second")
            try await add(first, to: library)
            try await add(second, to: library)
            try await library.rememberAsLastWorkedOn(first.id)

            try await library.remove(second.id)

            #expect(try await folder.library().wallpaperLastWorkedOn() == first.id)
        }
    }

    @Test func aDamagedWallpaperDocumentMakesTheLibraryUnreadable() async throws {
        try await withLibraryFolder { folder in
            let damaged = try wallpaper()
            try await add(damaged, to: folder.library())
            try Data("{\"formatVersion\": 1, \"name\": ".utf8).write(to: folder.documentFile(of: damaged))

            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpapers()
            }
            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpaper(damaged.id)
            }
        }
    }

    @Test func aWallpaperDocumentOfANewerFormatVersionMakesTheLibraryUnreadable() async throws {
        try await withLibraryFolder { folder in
            let tooNew = try wallpaper()
            try await add(tooNew, to: folder.library())
            try folder.replaceStoredDocument(of: tooNew) { document in
                document["formatVersion"] = 3
            }

            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpapers()
            }
        }
    }

    @Test(arguments: RefusedContent.allCases)
    func aWallpaperDocumentWhoseContentTheDomainRefusesMakesTheLibraryUnreadable(
        refused: RefusedContent,
    ) async throws {
        try await withLibraryFolder { folder in
            let stored = try wallpaper(filling: [.dawn, .night])
            try await add(stored, to: folder.library())
            let storedPictures = try #require(folder.storedDocument(of: stored)["pictures"] as? [String: Any])
            let dawnEntry = try #require(storedPictures["dawn"])
            try folder.replaceStoredDocument(of: stored) { document in
                switch refused {
                case .nameThatIsNotAllowed: document["name"] = "   "
                case .noPictures: document["pictures"] = [String: String]()
                case .onePictureInTwoSlots: document["pictures"] = ["dawn": dawnEntry, "night": dawnEntry]
                }
            }

            await #expect(throws: WallpaperLibraryError.unreadable) {
                try await folder.library().wallpapers()
            }
        }
    }

    @Test
    func aFolderLeftUnderBeingAddedIsNotAWallpaperAndIsGoneOnceTheLibraryIsUsed() async throws {
        try await withLibraryFolder { folder in
            let complete = try wallpaper(named: "Complete")
            try await add(complete, to: folder.library())
            let unfinished = try wallpaper(named: "Unfinished")
            let scratchFolder = try LibraryFolder.make()
            defer { scratchFolder.remove() }
            try await add(unfinished, to: scratchFolder.library())
            let leftover = folder.beingAddedFolder.appending(
                path: unfinished.id.value.uuidString,
                directoryHint: .isDirectory,
            )
            try FileManager.default.createDirectory(at: folder.beingAddedFolder, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: scratchFolder.wallpaperFolder(of: unfinished), to: leftover)

            #expect(try await folder.library().wallpapers() == [complete])
            #expect(!FileManager.default.fileExists(atPath: leftover.path))
        }
    }

    @Test func aLibraryOfAHundredWallpapersWithEightPicturesEachOpensInUnderASecond() async throws {
        try await withLibraryFolder { folder in
            let filling = folder.library()
            for number in 1 ... 100 {
                let added = try wallpaper(named: "Wallpaper \(number)", filling: Slot.allCases)
                try await filling.add(
                    added,
                    pictureContents: contents(of: added),
                    picturePreviews: previews(of: added, eachOfSize: sizeOfARealPreview),
                )
            }
            let clock = ContinuousClock()
            let start = clock.now

            let opened = folder.library()
            let wallpapers = try await opened.wallpapers()
            var previewCount = 0
            for wallpaper in wallpapers {
                previewCount += try await opened.picturePreviews(of: wallpaper.id).count
            }
            let openingTime = clock.now - start

            #expect(wallpapers.count == 100)
            #expect(previewCount == 800)
            #expect(openingTime < .seconds(1))
        }
    }

    @Test(arguments: [
        (CocoaError(.fileReadNoSuchFile) as any Error, WallpaperLibraryError.notFound),
        (CocoaError(.fileNoSuchFile), .notFound),
        (CocoaError(.fileReadNoPermission), .notPermitted),
        (CocoaError(.fileWriteNoPermission), .notPermitted),
        (CocoaError(.fileWriteOutOfSpace), .noSpaceLeft),
        (CocoaError(.fileWriteVolumeReadOnly), .unavailable),
        (POSIXError(.ENOENT), .notFound),
        (POSIXError(.EACCES), .notPermitted),
        (POSIXError(.EPERM), .notPermitted),
        (POSIXError(.ENOSPC), .noSpaceLeft),
        (POSIXError(.EDQUOT), .noSpaceLeft),
        (POSIXError(.EROFS), .unavailable),
        (CocoaError(.fileWriteUnknown, userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOSPC)]), .noSpaceLeft),
    ] as [(any Error & Sendable, WallpaperLibraryError)])
    func everyFileSystemFailureIsReportedAsThePortError(
        failure: any Error & Sendable,
        expected: WallpaperLibraryError,
    ) {
        #expect(FileWallpaperLibrary.libraryError(describing: failure) == expected)
    }

    @Test func aFileSystemFailureNobodyRecognisesIsReportedAsUnexpectedWithItsCause() {
        let unrecognised = CocoaError(.fileLocking)

        let reported = FileWallpaperLibrary.libraryError(describing: unrecognised)

        guard case let .unexpected(description) = reported else {
            Issue.record("Expected unexpected, got \(reported)")
            return
        }

        #expect(!description.isEmpty)
    }
}
