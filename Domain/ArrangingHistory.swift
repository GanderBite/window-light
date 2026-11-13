public struct ArrangingHistory: Equatable, Sendable {
    public private(set) var current: Arrangement
    private var earlierArrangements: [Arrangement] = []
    private var undoneArrangements: [Arrangement] = []

    public init(startingFrom arrangement: Arrangement) {
        current = arrangement
    }

    public var canUndo: Bool {
        !earlierArrangements.isEmpty
    }

    public var canRedo: Bool {
        !undoneArrangements.isEmpty
    }

    public mutating func record(_ arrangement: Arrangement) {
        guard arrangement != current else { return }

        earlierArrangements.append(current)
        current = arrangement
        undoneArrangements.removeAll()
    }

    @discardableResult
    public mutating func undo() -> Arrangement? {
        guard let previous = earlierArrangements.popLast() else { return nil }

        undoneArrangements.append(current)
        current = previous
        return previous
    }

    @discardableResult
    public mutating func redo() -> Arrangement? {
        guard let next = undoneArrangements.popLast() else { return nil }

        earlierArrangements.append(current)
        current = next
        return next
    }
}
