public struct Wallpaper: Identifiable, Equatable, Sendable {
    public let id: WallpaperID
    public private(set) var name: WallpaperName
    private let pictures: [Slot: Picture]

    public init(id: WallpaperID, name: WallpaperName, pictures: [Slot: Picture]) throws(WallpaperError) {
        guard !pictures.isEmpty else { throw .noPictures }
        var seenIDs = Set<PictureID>()
        for slot in Slot.allCases {
            guard let picture = pictures[slot] else { continue }
            guard seenIDs.insert(picture.id).inserted else {
                throw .pictureInTwoSlots(picture.id)
            }
        }
        self.id = id
        self.name = name
        self.pictures = pictures
    }

    public mutating func rename(to newName: WallpaperName) {
        name = newName
    }

    public func picture(in slot: Slot) -> Picture? {
        pictures[slot]
    }

    public var picturesInDayOrder: [Picture] {
        Slot.allCases.compactMap { pictures[$0] }
    }

    public var filledSlotCount: Int {
        pictures.count
    }
}
