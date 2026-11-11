public struct Picture: Identifiable, Hashable, Sendable {
    public let id: PictureID

    public init(id: PictureID) {
        self.id = id
    }
}
