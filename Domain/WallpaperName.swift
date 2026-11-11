import Foundation

public struct WallpaperName: Hashable, Sendable {
    public static let longestAllowed = 50

    private static let edgeCharacters = CharacterSet(charactersIn: " \t\n\r")

    public let text: String

    public init(_ proposedText: String) throws(WallpaperNameError) {
        let trimmedText = proposedText.trimmingCharacters(in: Self.edgeCharacters)
        guard !trimmedText.isEmpty else { throw .empty }
        guard trimmedText.count <= Self.longestAllowed else {
            throw .tooLong(limit: Self.longestAllowed)
        }

        text = trimmedText
    }

    public static func defaultName(
        startingWith stem: String,
        unusedAmong namesInUse: some Sequence<Self>,
    ) throws(WallpaperNameError) -> Self {
        let textsInUse = Set(namesInUse.map(\.text))
        var number = 1
        while textsInUse.contains("\(stem) \(number)") {
            number += 1
        }
        return try Self("\(stem) \(number)")
    }
}
