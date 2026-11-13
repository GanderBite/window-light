import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO
import Observation

@MainActor
@Observable
public final class WallpaperModel {
    public enum Phase: Equatable { case nothingOpen, opening, open, gone, unavailable }

    private let openWallpaper: OpenWallpaper
    private let arrangePictures: ArrangePictures
    private let finishArranging: FinishArranging
    private let wallpaperChanged: @MainActor (WallpaperID) async -> Void
    private var arrangingSession = 0
    private var firstOpening: Task<Void, Never>?
    private let actionsInOrder = ActionsInOrder()
    private var openWallpaperState: Wallpaper?
    private var history: ArrangingHistory?

    public private(set) var phase: Phase = .nothingOpen
    public private(set) var wallpaperID: WallpaperID?
    public private(set) var name = ""
    public private(set) var slots: [SlotState] = []
    public private(set) var hasEmptySlot = false
    public private(set) var isAskingToPlaceByTimeAgain = false
    public private(set) var lastStep: Step?
    public private(set) var newStepCount = 0
    public private(set) var arrangingFailure: ArrangingFailure?

    public init(
        openWallpaper: OpenWallpaper,
        arrangePictures: ArrangePictures,
        finishArranging: FinishArranging,
        wallpaperChanged: @escaping @MainActor (WallpaperID) async -> Void = { _ in },
    ) {
        self.openWallpaper = openWallpaper
        self.arrangePictures = arrangePictures
        self.finishArranging = finishArranging
        self.wallpaperChanged = wallpaperChanged
    }

    public var needsMorePictures: Bool {
        openWallpaperState.map { !$0.isReadyToApply } ?? false
    }

    public var canPlaceByTimeAgain: Bool {
        openWallpaperState?.picturesInDayOrder.contains(where: \.isReal) ?? false
    }

    public var canUndo: Bool {
        openWallpaperState != nil && history?.canUndo == true
    }

    public var canRedo: Bool {
        openWallpaperState != nil && history?.canRedo == true
    }

    public func show(_ wallpaper: WallpaperID?) async {
        if let wallpaper, wallpaper == wallpaperID {
            await openAgain(wallpaper)
        } else {
            await open(wallpaper, insteadOf: wallpaperID)
        }
    }

    public func reload() async {
        guard let wallpaperID else { return }

        await show(wallpaperID)
    }

    public func movePicture(from source: Slot, to destination: Slot) async {
        await makeStep(.movePicture(from: source, to: destination)) { wallpaperBefore in
            .movingPicture(from: source, to: destination, in: wallpaperBefore)
        }
    }

    public func removePicture(from slot: Slot) async {
        await makeStep(.removePicture(from: slot)) { _ in .removed(from: slot) }
    }

    public func askToPlaceByTimeAgain() {
        guard canPlaceByTimeAgain else { return }

        isAskingToPlaceByTimeAgain = true
    }

    public func confirmPlacingByTimeAgain() async {
        guard isAskingToPlaceByTimeAgain else { return }

        isAskingToPlaceByTimeAgain = false
        await makeStep(.placeByTimeAgain) { _ in .placedByTimeAgain }
    }

    public func declinePlacingByTimeAgain() {
        isAskingToPlaceByTimeAgain = false
    }

    public func undo() async {
        await goBack(as: .undone) { history in history.undo() }
    }

    public func redo() async {
        await goBack(as: .redone) { history in history.redo() }
    }

    public func dismissArrangingFailure() {
        arrangingFailure = nil
    }

    private func openAgain(_ wallpaper: WallpaperID) async {
        let session = arrangingSession
        let firstOpening = firstOpening
        await actionsInOrder.carryOut {
            await firstOpening?.value
            guard session == self.arrangingSession else { return }

            await self.open(wallpaper, inSession: session)
        }
    }

    private func open(_ wallpaper: WallpaperID?, insteadOf finishedWallpaper: WallpaperID?) async {
        wallpaperID = wallpaper
        clearWallpaper()
        endArranging()
        phase = wallpaper == nil ? .nothingOpen : .opening
        let session = arrangingSession
        let actionsSentEarlier = actionsInOrder.lastSentAction
        let opening = Task {
            await actionsSentEarlier?.value
            if let finishedWallpaper {
                await self.finishArranging.execute(finishedWallpaper)
            }
            guard let wallpaper, session == self.arrangingSession else { return }

            await self.finishArranging.execute(wallpaper)
            await self.open(wallpaper, inSession: session)
        }
        firstOpening = opening
        await opening.value
    }

    private func makeStep(
        _ change: ArrangementChange,
        describedBy step: @escaping @MainActor (Wallpaper) -> Step,
    ) async {
        let changedWallpaper = await actionsInOrder.carryOut { () -> WallpaperID? in
            guard let wallpaperBefore = self.openWallpaperState, var history = self.history,
                  let arranged = await self.arrange(change, in: wallpaperBefore.id),
                  arranged.arrangement != history.current
            else { return nil }

            history.record(arranged.arrangement)
            self.history = history
            self.lastStep = step(wallpaperBefore)
            self.newStepCount += 1
            return arranged.id
        }
        await tellThat(changedWallpaper)
    }

    private func goBack(
        as step: Step,
        takingFrom historyMove: @escaping @MainActor (inout ArrangingHistory) -> Arrangement?,
    ) async {
        let changedWallpaper = await actionsInOrder.carryOut { () -> WallpaperID? in
            guard let wallpaperBefore = self.openWallpaperState, var history = self.history,
                  let arrangement = historyMove(&history),
                  let arranged = await self.arrange(.goBack(to: arrangement), in: wallpaperBefore.id)
            else { return nil }

            self.history = history
            self.lastStep = step
            return arranged.id
        }
        await tellThat(changedWallpaper)
    }

    private func tellThat(_ changedWallpaper: WallpaperID?) async {
        guard let changedWallpaper else { return }

        await wallpaperChanged(changedWallpaper)
    }

    private func arrange(_ change: ArrangementChange, in wallpaper: WallpaperID) async -> Wallpaper? {
        let session = arrangingSession
        do throws(ArrangePicturesError) {
            let arranged = try await arrangePictures.execute(change, in: wallpaper)
            let previews = await Self.decodedPreviewsInDayOrder(of: arranged)
            guard session == arrangingSession else { return nil }

            hold(arranged.wallpaper, withPreviews: previews)
            return arranged.wallpaper
        } catch {
            guard session == arrangingSession else { return nil }

            switch error {
            case .wallpaperGone: loseWallpaper()
            case .unavailable: arrangingFailure = .couldNotSave
            case .noPictureToMove, .pictureMadeWithAICannotBeMoved: return nil
            }
            return nil
        }
    }

    private func open(_ wallpaper: WallpaperID, inSession session: Int) async {
        do throws(OpenWallpaperError) {
            let opened = try await openWallpaper.execute(wallpaper)
            let previews = await Self.decodedPreviewsInDayOrder(of: opened)
            guard session == arrangingSession else { return }

            hold(opened.wallpaper, withPreviews: previews)
            followArrangement(of: opened.wallpaper)
            phase = .open
        } catch {
            guard session == arrangingSession else { return }

            switch error {
            case .wallpaperGone: loseWallpaper()
            case .unavailable:
                clearWallpaper()
                phase = .unavailable
            }
        }
    }

    private func followArrangement(of wallpaper: Wallpaper) {
        guard var history else {
            history = ArrangingHistory(startingFrom: wallpaper.arrangement)
            return
        }
        guard wallpaper.arrangement != history.current else { return }

        history.record(wallpaper.arrangement)
        self.history = history
        lastStep = .picturesAdded
        newStepCount += 1
    }

    private func hold(_ wallpaper: Wallpaper, withPreviews previews: [CGImage?]) {
        openWallpaperState = wallpaper
        name = wallpaper.name.text
        let decodedPreviewsBySlot = Dictionary(uniqueKeysWithValues: zip(Slot.allCases, previews))
            .compactMapValues { $0 }
        slots = Slot.allCases.map { slot in
            SlotState(
                slot: slot,
                preview: decodedPreviewsBySlot[slot],
                isFilled: wallpaper.picture(in: slot) != nil,
                canTakeAFile: wallpaper.canTakeAFile(into: slot),
                canBeMoved: wallpaper.canMovePicture(from: slot),
                standIn: wallpaper.standIn(for: slot).map { lent in
                    StandIn(slot: lent.slot, preview: decodedPreviewsBySlot[lent.slot])
                },
            )
        }
        hasEmptySlot = !wallpaper.emptySlots.isEmpty
    }

    private func loseWallpaper() {
        clearWallpaper()
        history = nil
        isAskingToPlaceByTimeAgain = false
        phase = .gone
    }

    private func clearWallpaper() {
        openWallpaperState = nil
        name = ""
        slots = []
        hasEmptySlot = false
    }

    private func endArranging() {
        arrangingSession += 1
        history = nil
        lastStep = nil
        newStepCount = 0
        isAskingToPlaceByTimeAgain = false
        arrangingFailure = nil
    }

    @concurrent
    private static func decodedPreviewsInDayOrder(of entry: WallpaperInLibrary) async -> [CGImage?] {
        Slot.allCases.map { slot in
            entry.picturePreview(in: slot).flatMap(decodedImage(from:))
        }
    }

    private nonisolated static func decodedImage(from previewBytes: Data) -> CGImage? {
        let decodeNow = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithData(previewBytes as CFData, nil) else { return nil }

        return CGImageSourceCreateImageAtIndex(source, 0, decodeNow)
    }
}

public extension WallpaperModel {
    enum Step: Equatable {
        case moved(from: Slot, to: Slot)
        case swapped(Slot, with: Slot)
        case removed(from: Slot)
        case placedByTimeAgain
        case picturesAdded
        case undone
        case redone
    }

    enum ArrangingFailure: Equatable { case couldNotSave }

    struct StandIn: Equatable {
        public let slot: Slot
        public let preview: CGImage?
    }

    struct SlotState: Identifiable, Equatable {
        public let slot: Slot
        public let preview: CGImage?
        public let isFilled: Bool
        public let canTakeAFile: Bool
        public let canBeMoved: Bool
        public let standIn: StandIn?

        public var id: Slot {
            slot
        }
    }
}

extension WallpaperModel.Step {
    static func movingPicture(from source: Slot, to destination: Slot, in wallpaperBefore: Wallpaper) -> Self {
        let destinationHeldARealPicture = wallpaperBefore.picture(in: destination)?.isReal ?? false
        return destinationHeldARealPicture ? .swapped(source, with: destination) : .moved(from: source, to: destination)
    }
}

@MainActor
private final class ActionsInOrder {
    private(set) var lastSentAction: Task<Void, Never>?

    func carryOut<Outcome: Sendable>(_ action: @escaping @MainActor () async -> Outcome) async -> Outcome {
        let earlierActions = lastSentAction
        let thisAction = Task { @MainActor in
            await earlierActions?.value
            return await action()
        }
        lastSentAction = Task { _ = await thisAction.value }
        return await thisAction.value
    }
}
