public struct ImportSummary: Equatable, Sendable {
    public let addedPictureCount: Int
    public let skippedFiles: [SkippedFile]
    public let filesThatMayLookBlurry: [String]
    public let stoppedForLackOfSpace: Bool
}

public struct SkippedFile: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case notAPicture
        case damaged
        case soundOnly
        case copyProtected
        case cannotBeRead
        case alreadyInWallpaper
        case sameAsAnotherChosenFile
        case noSpaceLeft
    }

    public let name: String
    public let reason: Reason
}
