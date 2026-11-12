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

    public enum Refusal: Equatable {
        case tooFewFiles(fewest: Int)
        case tooManyFiles(most: Int)
        case noEmptySlot
        case moreFilesThanEmptySlots(emptySlots: Int)
        case oneFileForASlot
        case slotHoldsRealPicture(Slot)
        case wallpaperGone
        case couldNotImport
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

        switch destination {
        case .newWallpaper:
            await importIntoNewWallpaper(files)
        case let .wallpaper(wallpaper):
            await importIntoEmptySlots(files, of: wallpaper)
        case let .slot(slot, wallpaper):
            await importIntoSlot(files, slot, of: wallpaper)
        }
    }

    private func importIntoNewWallpaper(_ files: [URL]) async {
        do throws(CreateWallpaperError) {
            let creation = try await createWallpaper.execute(files: files, defaultNameStem: defaultWallpaperNameStem)
            await finish(with: creation.summary, resultingWallpaper: creation.wallpaper)
        } catch {
            switch error {
            case let .tooFewFiles(fewest): refuse(.tooFewFiles(fewest: fewest))
            case let .tooManyFiles(most): refuse(.tooManyFiles(most: most))
            case .defaultNameTooLong, .unavailable: refuse(.couldNotImport)
            }
        }
    }

    private func importIntoEmptySlots(_ files: [URL], of wallpaper: WallpaperID) async {
        do throws(AddPicturesError) {
            let addition = try await addPictures.execute(files: files, to: wallpaper)
            await finish(with: addition.summary, resultingWallpaper: addition.wallpaper)
        } catch {
            switch error {
            case .wallpaperGone: refuse(.wallpaperGone)
            case .noEmptySlot: refuse(.noEmptySlot)
            case let .moreFilesThanEmptySlots(emptySlots): refuse(.moreFilesThanEmptySlots(emptySlots: emptySlots))
            case .unavailable: refuse(.couldNotImport)
            }
        }
    }

    private func importIntoSlot(_ files: [URL], _ slot: Slot, of wallpaper: WallpaperID) async {
        guard files.count == 1, let file = files.first else {
            refuse(.oneFileForASlot)
            return
        }

        do throws(AddPictureToSlotError) {
            let addition = try await addPictureToSlot.execute(file: file, to: wallpaper, in: slot)
            await finish(with: addition.summary, resultingWallpaper: addition.wallpaper)
        } catch {
            switch error {
            case .wallpaperGone: refuse(.wallpaperGone)
            case let .slotHoldsRealPicture(slot): refuse(.slotHoldsRealPicture(slot))
            case .unavailable: refuse(.couldNotImport)
            }
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
