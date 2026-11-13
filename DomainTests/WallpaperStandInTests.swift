@testable import Domain
import Foundation
import Testing

private func picture(
    origin: PictureOrigin = .imported,
    captureTime: CaptureTime? = nil,
    fingerprint text: String? = nil,
) throws -> Picture {
    let id = PictureID(UUID())
    return try Picture(
        id: id,
        origin: origin,
        captureTime: captureTime,
        fingerprint: ContentFingerprint(text ?? "fingerprint \(id.value.uuidString)"),
    )
}

private func wallpaper(pictures: [Slot: Picture]) throws -> Wallpaper {
    try Wallpaper(id: WallpaperID(UUID()), name: WallpaperName("Holiday"), pictures: pictures)
}

private func wallpaper(filling slots: [Slot]) throws -> Wallpaper {
    try wallpaper(pictures: Dictionary(uniqueKeysWithValues: slots.map { try ($0, picture()) }))
}

private func lender(of slot: Slot, in wallpaper: Wallpaper) -> Slot? {
    wallpaper.standIn(for: slot)?.slot
}

private var everyArrangementOfFilledSlots: [[Slot]] {
    (1 ..< (1 << Slot.allCases.count)).map { arrangement in
        Slot.allCases.enumerated().filter { index, _ in arrangement & (1 << index) != 0 }.map(\.element)
    }
}

struct NearestSlotCase: CustomTestStringConvertible {
    let emptySlot: Slot
    let filledSlots: [Slot]
    let lender: Slot

    var testDescription: String {
        "\(emptySlot) borrows from \(lender) among \(filledSlots)"
    }
}

private let nearestSlotCases = [
    NearestSlotCase(emptySlot: .dawn, filledSlots: [.sunrise, .morning], lender: .sunrise),
    NearestSlotCase(emptySlot: .sunrise, filledSlots: [.dawn, .midday], lender: .dawn),
    NearestSlotCase(emptySlot: .morning, filledSlots: [.midday, .dawn], lender: .midday),
    NearestSlotCase(emptySlot: .midday, filledSlots: [.afternoon, .sunrise], lender: .afternoon),
    NearestSlotCase(emptySlot: .afternoon, filledSlots: [.sunset, .dawn], lender: .sunset),
    NearestSlotCase(emptySlot: .sunset, filledSlots: [.dusk, .morning], lender: .dusk),
    NearestSlotCase(emptySlot: .dusk, filledSlots: [.night, .morning], lender: .night),
    NearestSlotCase(emptySlot: .night, filledSlots: [.dawn, .midday], lender: .dawn),
]

struct WallpaperStandInTests {
    @Test(arguments: [PictureOrigin.imported, .madeWithAI])
    func aFilledSlotBorrowsNothing(origin: PictureOrigin) throws {
        let wallpaper = try wallpaper(pictures: [.dawn: picture(origin: origin), .night: picture()])

        #expect(wallpaper.standIn(for: .dawn) == nil)
        #expect(wallpaper.standIn(for: .night) == nil)
    }

    @Test func theStandInIsThePictureTheWallpaperHoldsInTheSlotItNames() throws {
        let wallpaper = try wallpaper(filling: [.midday, .dusk])

        for slot in wallpaper.emptySlots {
            let standIn = try #require(wallpaper.standIn(for: slot))
            #expect(wallpaper.picture(in: standIn.slot) == standIn.picture)
        }
    }

    @Test func dawnBorrowsFromItsMirrorDuskAlthoughNightIsNearer() throws {
        let dusk = try picture()
        let wallpaper = try wallpaper(pictures: [.dusk: dusk, .night: picture()])

        #expect(wallpaper.standIn(for: .dawn) == PlacedPicture(picture: dusk, slot: .dusk))
    }

    @Test func withOnlyMiddayAndNightTheDayBorrowsFromMiddayAndTheTwilightFromNight() throws {
        let wallpaper = try wallpaper(filling: [.midday, .night])

        #expect(lender(of: .sunrise, in: wallpaper) == .midday)
        #expect(lender(of: .sunset, in: wallpaper) == .midday)
        #expect(lender(of: .morning, in: wallpaper) == .midday)
        #expect(lender(of: .afternoon, in: wallpaper) == .midday)
        #expect(lender(of: .dawn, in: wallpaper) == .night)
        #expect(lender(of: .dusk, in: wallpaper) == .night)
    }

    @Test func withOnlyDawnAndDuskNightBorrowsFromDuskWhichComesBeforeIt() throws {
        let dusk = try picture()
        let wallpaper = try wallpaper(pictures: [.dawn: picture(), .dusk: dusk])

        #expect(wallpaper.standIn(for: .night) == PlacedPicture(picture: dusk, slot: .dusk))
    }

    @Test func withOnlyMorningAndAfternoonMiddayBorrowsFromMorningWhichComesBeforeIt() throws {
        let wallpaper = try wallpaper(filling: [.morning, .afternoon])

        #expect(lender(of: .midday, in: wallpaper) == .morning)
    }

    @Test func withMiddaySunsetDuskAndNightTheMirrorsLendFirstAndAnEqualTieGoesToMidday() throws {
        let wallpaper = try wallpaper(filling: [.midday, .sunset, .dusk, .night])

        #expect(lender(of: .dawn, in: wallpaper) == .dusk)
        #expect(lender(of: .sunrise, in: wallpaper) == .sunset)
        #expect(lender(of: .morning, in: wallpaper) == .midday)
        #expect(lender(of: .afternoon, in: wallpaper) == .midday)
    }

    @Test(arguments: Slot.allCases)
    func aWallpaperWithOnePictureLendsItToAllSevenEmptySlots(filledSlot: Slot) throws {
        let onlyPicture = try picture()
        let wallpaper = try wallpaper(pictures: [filledSlot: onlyPicture])

        #expect(wallpaper.emptySlots.count == 7)
        for slot in wallpaper.emptySlots {
            #expect(wallpaper.standIn(for: slot) == PlacedPicture(picture: onlyPicture, slot: filledSlot))
        }
    }

    @Test(arguments: Slot.allCases.filter { $0.mirror != nil })
    func aSlotBorrowsFromItsMirrorEvenWhenBothNeighboursAreFilled(emptySlot: Slot) throws {
        let mirror = try #require(emptySlot.mirror)
        let neighbours = Slot.allCases.filter { emptySlot.steps(to: $0) == 1 }
        let wallpaper = try wallpaper(filling: neighbours + [mirror])

        #expect(lender(of: emptySlot, in: wallpaper) == mirror)
    }

    @Test(arguments: nearestSlotCases)
    func aSlotWhoseMirrorIsEmptyBorrowsFromTheNearestFilledSlot(_ nearestSlotCase: NearestSlotCase) throws {
        let wallpaper = try wallpaper(filling: nearestSlotCase.filledSlots)

        #expect(lender(of: nearestSlotCase.emptySlot, in: wallpaper) == nearestSlotCase.lender)
    }

    @Test func inEveryArrangementEachEmptySlotBorrowsFromTheMirrorOrElseFromANearestFilledSlot() throws {
        let arrangements = everyArrangementOfFilledSlots
        #expect(arrangements.count == 255)

        for filledSlots in arrangements {
            let wallpaper = try wallpaper(filling: filledSlots)
            for emptySlot in wallpaper.emptySlots {
                let standIn = try #require(wallpaper.standIn(for: emptySlot))
                #expect(filledSlots.contains(standIn.slot))
                #expect(wallpaper.picture(in: standIn.slot) == standIn.picture)
                if let mirror = emptySlot.mirror, filledSlots.contains(mirror) {
                    #expect(standIn.slot == mirror)
                } else {
                    let stepsToLender = emptySlot.steps(to: standIn.slot)
                    #expect(filledSlots.allSatisfy { emptySlot.steps(to: $0) >= stepsToLender })
                }
            }
        }
    }

    @Test func afterPlacingAPictureTheStandInsAnswerForTheNewArrangement() throws {
        var wallpaper = try wallpaper(filling: [.night])
        #expect(lender(of: .dawn, in: wallpaper) == .night)

        try wallpaper.place(picture(), in: .dusk)

        #expect(wallpaper.standIn(for: .dusk) == nil)
        #expect(lender(of: .dawn, in: wallpaper) == .dusk)
    }

    @Test func anEmptiedSlotIsAnsweredForLikeAnyOtherArrangement() throws {
        let night = try picture()
        let dusk = try picture()
        let withDusk = try wallpaper(pictures: [.night: night, .dusk: dusk])
        let withoutDusk = try wallpaper(pictures: [.night: night])

        #expect(withDusk.standIn(for: .dawn) == PlacedPicture(picture: dusk, slot: .dusk))
        #expect(withoutDusk.standIn(for: .dusk) == PlacedPicture(picture: night, slot: .night))
        #expect(withoutDusk.standIn(for: .dawn) == PlacedPicture(picture: night, slot: .night))
    }

    @Test func askingForAStandInChangesNothing() throws {
        let wallpaper = try wallpaper(filling: [.midday, .dusk])
        let before = wallpaper

        for slot in Slot.allCases {
            _ = wallpaper.standIn(for: slot)
        }

        #expect(wallpaper == before)
        #expect(wallpaper.emptySlots == before.emptySlots)
        for slot in before.emptySlots {
            #expect(wallpaper.picture(in: slot) == nil)
        }
    }
}
