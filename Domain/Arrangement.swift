public struct Arrangement: Equatable, Sendable {
    let picturesBySlot: [Slot: Picture]

    public func picture(in slot: Slot) -> Picture? {
        picturesBySlot[slot]
    }
}
