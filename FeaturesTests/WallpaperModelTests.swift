import Application
import CoreGraphics
import Domain
@testable import Features
import Foundation
import ImageIO
import Testing

private enum PreviewMakingFailure: Error {
    case noDrawingContext, noImage, noEncoder, notEncoded
}

private func previewBytes() throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: 32,
        height: 18,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ) else { throw PreviewMakingFailure.noDrawingContext }

    context.setFillColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 18))
    guard let image = context.makeImage() else { throw PreviewMakingFailure.noImage }

    let encoded = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        encoded as CFMutableData,
        "public.jpeg" as CFString,
        1,
        nil,
    ) else {
        throw PreviewMakingFailure.noEncoder
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw PreviewMakingFailure.notEncoded }

    return encoded as Data
}

private func picture(madeWith origin: PictureOrigin = .imported) throws -> Picture {
    try Picture(
        id: PictureID(UUID()),
        origin: origin,
        captureTime: nil,
        fingerprint: ContentFingerprint(UUID().uuidString),
    )
}

private func store(_ wallpaper: Wallpaper, in library: WallpaperLibraryStandIn) async throws {
    var contents: [PictureID: Data] = [:]
    var previews: [PictureID: Data] = [:]
    for held in wallpaper.picturesInDayOrder {
        contents[held.id] = Data("content \(held.id)".utf8)
        previews[held.id] = try previewBytes()
    }
    try await library.add(wallpaper, pictureContents: contents, picturePreviews: previews)
}

@discardableResult
private func addWallpaper(
    named text: String = "Summer",
    pictures picturesBySlot: [Slot: Picture],
    to library: WallpaperLibraryStandIn,
) async throws -> Wallpaper {
    let wallpaper = try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName(text), pictures: picturesBySlot)
    try await store(wallpaper, in: library)
    return wallpaper
}

@discardableResult
private func addWallpaper(
    named text: String = "Summer",
    filling slots: [Slot],
    to library: WallpaperLibraryStandIn,
) async throws -> Wallpaper {
    var picturesBySlot: [Slot: Picture] = [:]
    for slot in slots {
        picturesBySlot[slot] = try picture()
    }
    return try await addWallpaper(named: text, pictures: picturesBySlot, to: library)
}

@MainActor
private func wallpaperModel(over library: WallpaperLibraryStandIn) -> WallpaperModel {
    WallpaperModel(openWallpaper: OpenWallpaper(library: library))
}

@MainActor
private final class SeenWhileWaiting<Value> {
    var values: [Value] = []
}

@MainActor
private final class OnlyOnce {
    private var hasRun = false

    func run(_ action: () async -> Void) async {
        guard !hasRun else { return }

        hasRun = true
        await action()
    }
}

@MainActor
struct WallpaperModelTests {
    @Test func aNewModelHasNothingOpenAndNoSlots() {
        let model = wallpaperModel(over: WallpaperLibraryStandIn())
        #expect(model.phase == .nothingOpen)
        #expect(model.slots.isEmpty)
        #expect(model.wallpaperID == nil)
        #expect(model.name.isEmpty)
        #expect(!model.hasEmptySlot)
    }

    @Test func showingAWallpaperWithDawnAndDuskHoldsItsNameAndEightSlotsInTheOrderOfTheDay() async throws {
        let library = WallpaperLibraryStandIn()
        let summer = try await addWallpaper(named: "Summer", filling: [.dawn, .dusk], to: library)
        let model = wallpaperModel(over: library)
        await model.show(summer.id)
        #expect(model.phase == .open)
        #expect(model.wallpaperID == summer.id)
        #expect(model.name == "Summer")
        #expect(model.slots.map(\.slot) == Slot.allCases)
        let filledSlots = model.slots.filter(\.isFilled).map(\.slot)
        #expect(filledSlots == [.dawn, .dusk])
        let slotsWithPreview = model.slots.filter { $0.preview != nil }.map(\.slot)
        #expect(slotsWithPreview == [.dawn, .dusk])
    }

    @Test func anEmptySlotAndASlotWithAPictureMadeWithAICanTakeAFileButASlotWithARealPictureCannot(
    ) async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(
            pictures: [.dawn: picture(madeWith: .imported), .midday: picture(madeWith: .madeWithAI)],
            to: library,
        )
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        let slotsByName = Dictionary(uniqueKeysWithValues: model.slots.map { ($0.slot, $0) })
        #expect(slotsByName[.dawn]?.canTakeAFile == false)
        #expect(slotsByName[.midday]?.canTakeAFile == true)
        #expect(slotsByName[.night]?.canTakeAFile == true)
        #expect(model.slots.map(\.canTakeAFile) == Slot.allCases.map { wallpaper.canTakeAFile(into: $0) })
    }

    @Test func aWallpaperWithTwoPicturesHasAnEmptySlot() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        #expect(model.hasEmptySlot)
    }

    @Test func aWallpaperWithEightPicturesHasNoEmptySlot() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: Slot.allCases, to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        #expect(model.phase == .open)
        #expect(!model.hasEmptySlot)
    }

    @Test func showingAWallpaperThatIsNotInTheLibraryIsGoneWithNoSlots() async {
        let model = wallpaperModel(over: WallpaperLibraryStandIn())
        await model.show(WallpaperID(UUID()))
        #expect(model.phase == .gone)
        #expect(model.slots.isEmpty)
        #expect(!model.hasEmptySlot)
    }

    @Test func showingAWallpaperOfALibraryThatFailsIsUnavailableWithNoSlots() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .night], to: library)
        await library.fail(.wallpaper, with: .unavailable)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        #expect(model.phase == .unavailable)
        #expect(model.slots.isEmpty)
        #expect(!model.hasEmptySlot)
    }

    @Test func showingNothingAfterAWallpaperReturnsToNothingOpen() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dawn, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        await model.show(nil)
        #expect(model.phase == .nothingOpen)
        #expect(model.wallpaperID == nil)
        #expect(model.name.isEmpty)
        #expect(model.slots.isEmpty)
        #expect(!model.hasEmptySlot)
    }

    @Test func reloadingAfterAPictureWasAddedShowsItWithoutEverOpeningAgain() async throws {
        let library = WallpaperLibraryStandIn()
        var wallpaper = try await addWallpaper(filling: [.dawn, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        try wallpaper.place(picture(), in: .midday)
        try await library.remove(wallpaper.id)
        try await store(wallpaper, in: library)
        let phasesWhileReloading = SeenWhileWaiting<WallpaperModel.Phase>()
        await library.beforeAnswering(.wallpaper) { @MainActor in
            phasesWhileReloading.values.append(model.phase)
        }
        await library.beforeAnswering(.picturePreviews) { @MainActor in
            phasesWhileReloading.values.append(model.phase)
        }
        await model.reload()
        #expect(phasesWhileReloading.values == [.open, .open])
        #expect(model.phase == .open)
        #expect(model.slots.filter(\.isFilled).map(\.slot) == [.dawn, .midday, .night])
        #expect(model.slots.first { $0.slot == .midday }?.preview != nil)
    }

    @Test func showingAWallpaperWithDuskAndNightGivesDawnTheStandInOfDuskWithItsPreview() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dusk, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        let dawn = try #require(model.slots.first { $0.slot == .dawn })
        let dusk = try #require(model.slots.first { $0.slot == .dusk })
        #expect(!dawn.isFilled)
        let standIn = try #require(dawn.standIn)
        #expect(standIn.slot == .dusk)
        let duskPreview = try #require(dusk.preview)
        #expect(standIn.preview === duskPreview)
    }

    @Test func everyEmptySlotHasTheStandInTheWallpaperNamesAndEveryFilledSlotHasNone() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.sunrise, .afternoon, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.slots.count == Slot.allCases.count)
        for state in model.slots {
            if state.isFilled {
                #expect(state.standIn == nil)
            } else {
                let standIn = try #require(state.standIn)
                #expect(standIn.slot == wallpaper.standIn(for: state.slot)?.slot)
                #expect(standIn.preview != nil)
            }
        }
    }

    @Test func anEmptySlotWithAStandInStaysEmptyAndCanStillTakeAFile() async throws {
        let library = WallpaperLibraryStandIn()
        let wallpaper = try await addWallpaper(filling: [.dusk, .night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        let dawn = try #require(model.slots.first { $0.slot == .dawn })
        try #require(dawn.standIn != nil)
        #expect(!dawn.isFilled)
        #expect(dawn.canTakeAFile)
        #expect(model.hasEmptySlot)
    }

    @Test func reloadingAfterAPictureWasAddedToDuskGivesDawnTheStandInOfDuskAndDuskNone() async throws {
        let library = WallpaperLibraryStandIn()
        var wallpaper = try await addWallpaper(filling: [.night], to: library)
        let model = wallpaperModel(over: library)
        await model.show(wallpaper.id)
        try #require(model.phase == .open)
        try wallpaper.place(picture(), in: .dusk)
        try await library.remove(wallpaper.id)
        try await store(wallpaper, in: library)
        let phasesWhileReloading = SeenWhileWaiting<WallpaperModel.Phase>()
        await library.beforeAnswering(.wallpaper) { @MainActor in
            phasesWhileReloading.values.append(model.phase)
        }
        await library.beforeAnswering(.picturePreviews) { @MainActor in
            phasesWhileReloading.values.append(model.phase)
        }
        await model.reload()
        #expect(phasesWhileReloading.values == [.open, .open])
        #expect(model.phase == .open)
        #expect(model.slots.first { $0.slot == .dawn }?.standIn?.slot == .dusk)
        let dusk = try #require(model.slots.first { $0.slot == .dusk })
        #expect(dusk.standIn == nil)
    }

    @Test func reloadingWithNothingShownAsksTheLibraryNothing() async {
        let library = WallpaperLibraryStandIn()
        let model = wallpaperModel(over: library)
        await model.reload()
        #expect(model.phase == .nothingOpen)
        #expect(await library.receivedCalls.isEmpty)
    }

    @Test func showingASecondWallpaperBeforeTheFirstHasOpenedEndsWithTheSecond() async throws {
        let library = WallpaperLibraryStandIn()
        let summer = try await addWallpaper(named: "Summer", filling: [.dawn, .night], to: library)
        let winter = try await addWallpaper(named: "Winter", filling: [.morning, .dusk, .night], to: library)
        let model = wallpaperModel(over: library)
        let onlyOnce = OnlyOnce()
        await library.beforeAnswering(.wallpaper) { @MainActor in
            await onlyOnce.run { await model.show(winter.id) }
        }
        await model.show(summer.id)
        #expect(model.phase == .open)
        #expect(model.wallpaperID == winter.id)
        #expect(model.name == "Winter")
        #expect(model.slots.filter(\.isFilled).map(\.slot) == [.morning, .dusk, .night])
    }
}
