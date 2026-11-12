public enum PictureOrigin: Hashable, Sendable {
    case imported
    case madeWithAI

    public var isReal: Bool {
        self == .imported
    }
}
