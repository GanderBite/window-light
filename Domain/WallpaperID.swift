import Foundation

public struct WallpaperID: Hashable, Sendable {
    public let value: UUID

    public init(_ value: UUID) {
        self.value = value
    }
}
