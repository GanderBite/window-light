import Foundation

public struct PictureID: Hashable, Sendable {
    public let value: UUID

    public init(_ value: UUID) {
        self.value = value
    }
}
