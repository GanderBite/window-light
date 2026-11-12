@testable import Domain
import Foundation
import Testing

private func picture(
    origin: PictureOrigin = .imported,
    captureTime: CaptureTime? = nil,
    fingerprint text: String = "9f86d081884c7d65",
) throws -> Picture {
    try Picture(id: PictureID(UUID()), origin: origin, captureTime: captureTime, fingerprint: ContentFingerprint(text))
}

struct PictureTests {
    @Test func aPictureGivesBackTheIdOriginCaptureTimeAndFingerprintItWasCreatedWith() throws {
        let id = PictureID(UUID())
        let captureTime = try CaptureTime(year: 2026, month: 6, day: 21, hour: 5, minute: 30, second: 0)
        let fingerprint = try ContentFingerprint("9f86d081884c7d65")

        let picture = Picture(id: id, origin: .madeWithAI, captureTime: captureTime, fingerprint: fingerprint)

        #expect(picture.id == id)
        #expect(picture.origin == .madeWithAI)
        #expect(picture.captureTime == captureTime)
        #expect(picture.fingerprint == fingerprint)
    }

    @Test func aPictureCanBeCreatedWithoutACaptureTime() throws {
        #expect(try picture(captureTime: nil).captureTime == nil)
    }

    @Test func anImportedPictureIsReal() throws {
        #expect(try picture(origin: .imported).isReal)
    }

    @Test func aPictureMadeWithAIIsNotReal() throws {
        #expect(try !picture(origin: .madeWithAI).isReal)
    }

    @Test func twoPicturesWithDifferentIdsAndTheSameFingerprintAreIdentical() throws {
        let first = try picture(fingerprint: "abc123")
        let second = try picture(fingerprint: "abc123")

        #expect(first.id != second.id)
        #expect(first.isIdentical(to: second))
    }

    @Test func twoPicturesWithDifferentFingerprintsAreNotIdentical() throws {
        let first = try picture(fingerprint: "abc123")
        let second = try picture(fingerprint: "abc124")

        #expect(!first.isIdentical(to: second))
    }
}
