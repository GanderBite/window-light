struct AutomaticPlacement {
    private let newPictures: [Picture]
    private var emptySlots: Set<Slot>
    private var slotByPositionGiven: [Int: Slot] = [:]

    init(of newPictures: [Picture], into emptySlots: [Slot]) {
        self.newPictures = newPictures
        self.emptySlots = Set(emptySlots)
        giveEachEmptyMatchingSlotToThePictureClosestToItsMiddle()
        giveThePicturesThatMissedTheirMatchingSlotTheNearestEmptySlot()
        spreadThePicturesWithoutACaptureTimeOverTheDay()
    }

    var placedPictures: [PlacedPicture] {
        newPictures.indices.compactMap { position in
            slotByPositionGiven[position].map { PlacedPicture(picture: newPictures[position], slot: $0) }
        }
    }

    private var picturesWithACaptureTime: [TimedPicture] {
        newPictures.indices.compactMap { position in
            newPictures[position].captureTime.map { TimedPicture(positionGiven: position, captureTime: $0) }
        }
    }

    private var positionsOfPicturesWithoutACaptureTime: [Int] {
        newPictures.indices.filter { newPictures[$0].captureTime == nil }
    }

    private mutating func giveEachEmptyMatchingSlotToThePictureClosestToItsMiddle() {
        let contendersBySlot = Dictionary(grouping: picturesWithACaptureTime, by: \.matchingSlot)
        for slot in Slot.allCases where emptySlots.contains(slot) {
            guard let winner = contendersBySlot[slot]?.min(by: { $0.hasAStrongerClaim(on: slot, than: $1) }) else {
                continue
            }

            give(slot, toPictureGivenAt: winner.positionGiven)
        }
    }

    private mutating func giveThePicturesThatMissedTheirMatchingSlotTheNearestEmptySlot() {
        let picturesThatMissed = picturesWithACaptureTime
            .filter { slotByPositionGiven[$0.positionGiven] == nil }
            .sorted { $0.comesEarlierInTheDay(than: $1) }
        for picture in picturesThatMissed {
            let matchingSlot = picture.matchingSlot
            guard let nearest = emptySlots.min(by: { Self.isNearer($0, than: $1, to: matchingSlot) }) else { return }

            give(nearest, toPictureGivenAt: picture.positionGiven)
        }
    }

    private mutating func spreadThePicturesWithoutACaptureTimeOverTheDay() {
        let positions = positionsOfPicturesWithoutACaptureTime
        var occupiedSlots = Set(Slot.allCases).subtracting(emptySlots)
        var pickedSlots: [Slot] = []
        for _ in positions {
            let candidates = emptySlots.subtracting(pickedSlots)
            guard let pick = candidates.min(by: { Self.isAStrongerSpreadPick($0, than: $1, awayFrom: occupiedSlots) })
            else { break }

            pickedSlots.append(pick)
            occupiedSlots.insert(pick)
        }
        for (position, slot) in zip(positions, pickedSlots.sorted()) {
            give(slot, toPictureGivenAt: position)
        }
    }

    private mutating func give(_ slot: Slot, toPictureGivenAt position: Int) {
        slotByPositionGiven[position] = slot
        emptySlots.remove(slot)
    }

    private static func isNearer(_ slot: Slot, than other: Slot, to matchingSlot: Slot) -> Bool {
        let steps = slot.steps(to: matchingSlot)
        let otherSteps = other.steps(to: matchingSlot)
        guard steps == otherSteps else { return steps < otherSteps }

        return slot > other
    }

    private static func isAStrongerSpreadPick(
        _ slot: Slot,
        than other: Slot,
        awayFrom occupiedSlots: Set<Slot>,
    ) -> Bool {
        let distance = stepsToTheNearest(of: occupiedSlots, from: slot)
        let otherDistance = stepsToTheNearest(of: occupiedSlots, from: other)
        guard distance == otherDistance else { return distance > otherDistance }

        return spreadPreference(of: slot) < spreadPreference(of: other)
    }

    private static func stepsToTheNearest(of occupiedSlots: Set<Slot>, from slot: Slot) -> Int {
        occupiedSlots.map { slot.steps(to: $0) }.min() ?? Int.max
    }

    private static func spreadPreference(of slot: Slot) -> Int {
        let slotsPreferredOnATie: [Slot] = [.midday, .night]
        if let preferred = slotsPreferredOnATie.firstIndex(of: slot) {
            return preferred
        }
        return slotsPreferredOnATie.count + (Slot.allCases.firstIndex(of: slot) ?? Slot.allCases.count)
    }
}

private struct TimedPicture {
    let positionGiven: Int
    let captureTime: CaptureTime

    var matchingSlot: Slot {
        Slot.matching(captureTime)
    }

    private var secondsIntoTheDay: Int {
        Slot.secondsIntoTheDay(of: captureTime)
    }

    func hasAStrongerClaim(on slot: Slot, than other: Self) -> Bool {
        (slot.secondsBetweenTheMiddle(and: captureTime), secondsIntoTheDay, positionGiven)
            < (slot.secondsBetweenTheMiddle(and: other.captureTime), other.secondsIntoTheDay, other.positionGiven)
    }

    func comesEarlierInTheDay(than other: Self) -> Bool {
        (secondsIntoTheDay, positionGiven) < (other.secondsIntoTheDay, other.positionGiven)
    }
}
