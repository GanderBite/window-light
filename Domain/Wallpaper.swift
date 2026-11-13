public struct Wallpaper: Identifiable, Equatable, Sendable {
    public static let fewestPicturesToApply = 2
    public static let fewestFilesToCreate = 2

    public static var mostPictures: Int {
        Slot.allCases.count
    }

    public let id: WallpaperID
    public private(set) var name: WallpaperName
    private var pictures: [Slot: Picture]

    public init(id: WallpaperID, name: WallpaperName, pictures: [Slot: Picture]) throws(WallpaperError) {
        var seenIDs = Set<PictureID>()
        var seenFingerprints = Set<ContentFingerprint>()
        for slot in Slot.allCases {
            guard let picture = pictures[slot] else { continue }
            guard seenIDs.insert(picture.id).inserted else {
                throw .pictureInTwoSlots(picture.id)
            }
            guard seenFingerprints.insert(picture.fingerprint).inserted else {
                throw .identicalPictureAlreadyInWallpaper(picture.fingerprint)
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

    public func standIn(for slot: Slot) -> PlacedPicture? {
        guard pictures[slot] == nil else { return nil }

        if let mirror = slot.mirror, let mirrorPicture = pictures[mirror] {
            return PlacedPicture(picture: mirrorPicture, slot: mirror)
        }
        return pictures
            .min { Self.lends($0.key, ratherThan: $1.key, to: slot) }
            .map { PlacedPicture(picture: $0.value, slot: $0.key) }
    }

    public var picturesInDayOrder: [Picture] {
        Slot.allCases.compactMap { pictures[$0] }
    }

    public var filledSlotCount: Int {
        pictures.count
    }

    public var emptySlots: [Slot] {
        Slot.allCases.filter { pictures[$0] == nil }
    }

    public var isReadyToApply: Bool {
        filledSlotCount >= Self.fewestPicturesToApply
    }

    public func holdsPicture(identicalTo fingerprint: ContentFingerprint) -> Bool {
        pictures.values.contains { $0.fingerprint == fingerprint }
    }

    public func canTakeAFile(into slot: Slot) -> Bool {
        guard let held = pictures[slot] else { return true }

        return !held.isReal
    }

    public static func checkCanBeCreated(fromFileCount count: Int) throws(WallpaperError) {
        guard count >= fewestFilesToCreate else { throw .tooFewFilesToCreate(fewest: fewestFilesToCreate) }
        guard count <= mostPictures else { throw .tooManyFilesToCreate(most: mostPictures) }
    }

    public func checkCanTake(fileCount count: Int) throws(WallpaperError) {
        try Self.checkEmptySlots(emptySlots, canTake: count)
    }

    public func checkCanTakeAFile(into slot: Slot) throws(WallpaperError) {
        guard canTakeAFile(into: slot) else { throw .slotHoldsRealPicture(slot) }
    }

    public static func automaticPlacementInNewWallpaper(
        of newPictures: [Picture],
    ) throws(WallpaperError) -> [PlacedPicture] {
        try placement(of: newPictures, into: Slot.allCases)
    }

    public func automaticPlacement(of newPictures: [Picture]) throws(WallpaperError) -> [PlacedPicture] {
        try Self.placement(of: newPictures, into: emptySlots)
    }

    @discardableResult
    public mutating func place(_ picture: Picture, in slot: Slot) throws(WallpaperError) -> Picture? {
        try checkCanTakeAFile(into: slot)
        guard !pictures.values.contains(where: { $0.id == picture.id }) else {
            throw .pictureInTwoSlots(picture.id)
        }
        guard !holdsPicture(identicalTo: picture.fingerprint, outside: slot) else {
            throw .identicalPictureAlreadyInWallpaper(picture.fingerprint)
        }

        return pictures.updateValue(picture, forKey: slot)
    }

    public func canMovePicture(from slot: Slot) -> Bool {
        pictures[slot]?.isReal ?? false
    }

    @discardableResult
    public mutating func movePicture(from source: Slot, to destination: Slot) throws(WallpaperError) -> Picture? {
        guard let moving = pictures[source] else { throw .noPictureToMove(source) }
        guard moving.isReal else { throw .pictureMadeWithAICannotBeMoved(source) }
        guard source != destination else { return nil }

        let displaced = pictures.updateValue(moving, forKey: destination)
        if let displaced, displaced.isReal {
            pictures[source] = displaced
            return nil
        }
        pictures[source] = nil
        return displaced
    }

    @discardableResult
    public mutating func removePicture(from slot: Slot) -> Picture? {
        pictures.removeValue(forKey: slot)
    }

    private func holdsPicture(identicalTo fingerprint: ContentFingerprint, outside slot: Slot) -> Bool {
        pictures.contains { heldSlot, held in heldSlot != slot && held.fingerprint == fingerprint }
    }

    private static func lends(_ candidate: Slot, ratherThan other: Slot, to emptySlot: Slot) -> Bool {
        let candidateSteps = emptySlot.steps(to: candidate)
        let otherSteps = emptySlot.steps(to: other)
        guard candidateSteps == otherSteps else { return candidateSteps < otherSteps }

        let candidateStepsToMidday = candidate.steps(to: .midday)
        let otherStepsToMidday = other.steps(to: .midday)
        guard candidateStepsToMidday == otherStepsToMidday else {
            return candidateStepsToMidday < otherStepsToMidday
        }

        return comes(candidate, before: emptySlot)
    }

    private static func comes(_ candidate: Slot, before emptySlot: Slot) -> Bool {
        let slotJustBefore = Slot.allCases.last { $0 < emptySlot } ?? .night
        return slotJustBefore.steps(to: candidate) < emptySlot.steps(to: candidate)
    }

    private static func checkEmptySlots(_ emptySlots: [Slot], canTake fileCount: Int) throws(WallpaperError) {
        guard !emptySlots.isEmpty else { throw .noEmptySlot }
        guard fileCount <= emptySlots.count else {
            throw .moreFilesThanEmptySlots(emptySlots: emptySlots.count)
        }
    }

    private static func placement(
        of newPictures: [Picture],
        into emptySlots: [Slot],
    ) throws(WallpaperError) -> [PlacedPicture] {
        try checkEmptySlots(emptySlots, canTake: newPictures.count)
        return AutomaticPlacement(of: newPictures, into: emptySlots).placedPictures
    }
}
