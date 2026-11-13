import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PictureImportModel {
    public enum Destination: Equatable {
        case newWallpaper
        case wallpaper(WallpaperID)
        case slot(Slot, of: WallpaperID)
    }

    public enum Refusal: Equatable, Sendable {
        case tooFewFiles(fewest: Int)
        case tooManyFiles(most: Int)
        case noEmptySlot
        case moreFilesThanEmptySlots(emptySlots: Int)
        case oneFileForASlot
        case slotHoldsRealPicture(Slot)
        case wallpaperGone
        case couldNotImport
    }

    private enum ImportEnding {
        case finished(ImportSummary, resultingWallpaper: Wallpaper?)
        case refused(Refusal)
    }

    public struct Outcome: Equatable {
        public let summary: ImportSummary
        public let wallpaperNeedsMorePictures: Bool

        fileprivate init(summary: ImportSummary, resultingWallpaper: Wallpaper?) {
            self.summary = summary
            let wallpaperIsNotReadyToApply = resultingWallpaper.map { !$0.isReadyToApply } ?? false
            wallpaperNeedsMorePictures = wallpaperIsNotReadyToApply && summary.addedPictureCount > 0
        }
    }

    private let createWallpaper: CreateWallpaper
    private let addPictures: AddPictures
    private let addPictureToSlot: AddPictureToSlot
    private let defaultWallpaperNameStem: String
    private let wallpaperChanged: @MainActor (WallpaperID) async -> Void

    public private(set) var destinationAwaitingFiles: Destination?
    public private(set) var isImporting = false
    public private(set) var outcome: Outcome?
    public private(set) var refusal: Refusal?
    private var runningImport: Task<ImportEnding, Never>?

    public init(
        createWallpaper: CreateWallpaper,
        addPictures: AddPictures,
        addPictureToSlot: AddPictureToSlot,
        defaultWallpaperNameStem: String,
        wallpaperChanged: @escaping @MainActor (WallpaperID) async -> Void,
    ) {
        self.createWallpaper = createWallpaper
        self.addPictures = addPictures
        self.addPictureToSlot = addPictureToSlot
        self.defaultWallpaperNameStem = defaultWallpaperNameStem
        self.wallpaperChanged = wallpaperChanged
    }

    public func chooseFiles(for destination: Destination) {
        destinationAwaitingFiles = destination
    }

    public func cancelChoosingFiles() {
        destinationAwaitingFiles = nil
    }

    public func importChosenFiles(_ files: [URL]) async {
        guard canStartImporting(files), let destination = destinationAwaitingFiles else { return }

        destinationAwaitingFiles = nil
        await runImport(of: files, to: destination)
    }

    public func importFiles(_ files: [URL], to destination: Destination) async {
        guard canStartImporting(files) else { return }

        await runImport(of: files, to: destination)
    }

    public func stopImporting() {
        runningImport?.cancel()
    }

    public func dismissOutcome() {
        outcome = nil
    }

    public func dismissRefusal() {
        refusal = nil
    }

    private func canStartImporting(_ files: [URL]) -> Bool {
        !isImporting && !files.isEmpty
    }

    private func runImport(of files: [URL], to destination: Destination) async {
        isImporting = true
        defer { isImporting = false }

        let stoppableImport = Task { await self.ending(ofImporting: files, to: destination) }
        runningImport = stoppableImport
        let ending = await stoppableImport.value
        runningImport = nil
        switch ending {
        case let .finished(summary, resultingWallpaper):
            await finish(with: summary, resultingWallpaper: resultingWallpaper)
        case let .refused(reason):
            refuse(reason)
        }
    }

    private func ending(ofImporting files: [URL], to destination: Destination) async -> ImportEnding {
        switch destination {
        case .newWallpaper:
            await importIntoNewWallpaper(files)
        case let .wallpaper(wallpaper):
            await importIntoEmptySlots(files, of: wallpaper)
        case let .slot(slot, wallpaper):
            await importIntoSlot(files, slot, of: wallpaper)
        }
    }

    private func importIntoNewWallpaper(_ files: [URL]) async -> ImportEnding {
        do throws(CreateWallpaperError) {
            let creation = try await createWallpaper.execute(files: files, defaultNameStem: defaultWallpaperNameStem)
            return .finished(creation.summary, resultingWallpaper: creation.wallpaper)
        } catch {
            let refusal: Refusal =
                switch error {
                case let .tooFewFiles(fewest): .tooFewFiles(fewest: fewest)
                case let .tooManyFiles(most): .tooManyFiles(most: most)
                case .defaultNameTooLong, .unavailable: .couldNotImport
                }
            return .refused(refusal)
        }
    }

    private func importIntoEmptySlots(_ files: [URL], of wallpaper: WallpaperID) async -> ImportEnding {
        do throws(AddPicturesError) {
            let addition = try await addPictures.execute(files: files, to: wallpaper)
            return .finished(addition.summary, resultingWallpaper: addition.wallpaper)
        } catch {
            let refusal: Refusal =
                switch error {
                case .wallpaperGone: .wallpaperGone
                case .noEmptySlot: .noEmptySlot
                case let .moreFilesThanEmptySlots(emptySlots): .moreFilesThanEmptySlots(emptySlots: emptySlots)
                case .unavailable: .couldNotImport
                }
            return .refused(refusal)
        }
    }

    private func importIntoSlot(_ files: [URL], _ slot: Slot, of wallpaper: WallpaperID) async -> ImportEnding {
        guard files.count == 1, let file = files.first else {
            return .refused(.oneFileForASlot)
        }

        do throws(AddPictureToSlotError) {
            let addition = try await addPictureToSlot.execute(file: file, to: wallpaper, in: slot)
            return .finished(addition.summary, resultingWallpaper: addition.wallpaper)
        } catch {
            let refusal: Refusal =
                switch error {
                case .wallpaperGone: .wallpaperGone
                case let .slotHoldsRealPicture(slot): .slotHoldsRealPicture(slot)
                case .unavailable: .couldNotImport
                }
            return .refused(refusal)
        }
    }

    private func finish(with summary: ImportSummary, resultingWallpaper: Wallpaper?) async {
        if let resultingWallpaper, summary.addedPictureCount > 0 {
            await wallpaperChanged(resultingWallpaper.id)
        }
        outcome = Outcome(summary: summary, resultingWallpaper: resultingWallpaper)
        refusal = nil
    }

    private func refuse(_ reason: Refusal) {
        outcome = nil
        refusal = reason
    }
}
