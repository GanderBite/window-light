@testable import Domain
import Testing

struct ContentFingerprintTests {
    @Test func aFingerprintKeepsItsText() throws {
        #expect(try ContentFingerprint("abc123").text == "abc123")
    }

    @Test func fingerprintsWithTheSameTextAreEqual() throws {
        let first = try ContentFingerprint("abc123")
        let second = try ContentFingerprint("abc123")
        #expect(first == second)
    }

    @Test func fingerprintsWithDifferentTextAreNotEqual() throws {
        #expect(try ContentFingerprint("abc123") != ContentFingerprint("abc124"))
    }

    @Test(arguments: ["", "   ", "\n\n", " \r\n "])
    func anEmptyOrBlankTextIsRefused(text: String) {
        #expect(throws: ContentFingerprintError.empty) {
            try ContentFingerprint(text)
        }
    }
}
