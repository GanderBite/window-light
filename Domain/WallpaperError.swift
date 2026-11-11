public enum WallpaperError: Error, Equatable, Sendable {
    case noPictures
    case pictureInTwoSlots(PictureID)
}
