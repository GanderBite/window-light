public enum WallpaperError: Error, Equatable, Sendable {
    case pictureInTwoSlots(PictureID)
    case tooFewFilesToCreate(fewest: Int)
    case tooManyFilesToCreate(most: Int)
    case noEmptySlot
    case moreFilesThanEmptySlots(emptySlots: Int)
    case slotHoldsRealPicture(Slot)
    case identicalPictureAlreadyInWallpaper(ContentFingerprint)
    case noPictureToMove(Slot)
    case pictureMadeWithAICannotBeMoved(Slot)
}
