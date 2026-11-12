public enum WallpaperError: Error, Equatable, Sendable {
    case noPictures
    case pictureInTwoSlots(PictureID)
    case tooFewFilesToCreate(fewest: Int)
    case tooManyFilesToCreate(most: Int)
    case noEmptySlot
    case moreFilesThanEmptySlots(emptySlots: Int)
    case slotHoldsRealPicture(Slot)
    case identicalPictureAlreadyInWallpaper(ContentFingerprint)
}
