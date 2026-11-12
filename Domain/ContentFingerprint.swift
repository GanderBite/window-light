import Foundation

public struct ContentFingerprint: Hashable, Sendable {
    private static let blankCharacters = CharacterSet.whitespacesAndNewlines

    public let text: String

    public init(_ text: String) throws(ContentFingerprintError) {
        guard !text.trimmingCharacters(in: Self.blankCharacters).isEmpty else { throw .empty }

        self.text = text
    }
}
