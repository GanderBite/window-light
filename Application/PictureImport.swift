import Domain
import Foundation

struct PictureImport {
    private let files: any PictureFiles
    private let previews: any PicturePreviews

    init(files: any PictureFiles, previews: any PicturePreviews) {
        self.files = files
        self.previews = previews
    }

    func read(
        _ chosenFiles: [URL],
        besidesPicturesIdenticalTo fingerprintsInWallpaper: Set<ContentFingerprint>,
    ) async -> ImportedFiles {
        var outcomes: [ImportedFiles.Outcome] = []
        var fingerprintsOfTakenFiles = Set<ContentFingerprint>()
        for file in chosenFiles.sorted(by: Self.comesFirstInTheFinder) {
            guard !Task.isCancelled else {
                outcomes.append(.skipped(SkippedFile(name: file.lastPathComponent, reason: .importStopped)))
                continue
            }

            let outcome = await outcome(
                ofReading: file,
                besidesPicturesIdenticalTo: fingerprintsInWallpaper,
                recordingFingerprintIn: &fingerprintsOfTakenFiles,
            )
            outcomes.append(outcome)
        }
        return ImportedFiles(outcomes: outcomes)
    }

    func read(_ chosenFiles: [URL], besidesPicturesIn wallpaper: Wallpaper) async -> ImportedFiles {
        await read(chosenFiles, besidesPicturesIdenticalTo: Set(wallpaper.picturesInDayOrder.map(\.fingerprint)))
    }

    private func outcome(
        ofReading file: URL,
        besidesPicturesIdenticalTo fingerprintsInWallpaper: Set<ContentFingerprint>,
        recordingFingerprintIn fingerprintsOfTakenFiles: inout Set<ContentFingerprint>,
    ) async -> ImportedFiles.Outcome {
        let name = file.lastPathComponent
        let pictureFile: PictureFile
        do throws(PictureFileError) {
            pictureFile = try await files.picture(in: file)
        } catch {
            return .skipped(SkippedFile(name: name, reason: Self.reasonForSkippingAFileWhoseReadFailed(with: error)))
        }
        guard !fingerprintsInWallpaper.contains(pictureFile.fingerprint) else {
            return .skipped(SkippedFile(name: name, reason: .alreadyInWallpaper))
        }
        guard fingerprintsOfTakenFiles.insert(pictureFile.fingerprint).inserted else {
            return .skipped(SkippedFile(name: name, reason: .sameAsAnotherChosenFile))
        }

        let preview: Data
        do throws(PicturePreviewError) {
            preview = try await previews.preview(ofPictureWith: pictureFile.content)
        } catch {
            return .skipped(SkippedFile(name: name, reason: Self.reason(forSkipping: error)))
        }
        return .readable(ImportedPicture(name: name, file: pictureFile, preview: preview))
    }

    private static func comesFirstInTheFinder(_ file: URL, before otherFile: URL) -> Bool {
        file.lastPathComponent.localizedStandardCompare(otherFile.lastPathComponent) == .orderedAscending
    }

    private static func reasonForSkippingAFileWhoseReadFailed(with error: PictureFileError) -> SkippedFile.Reason {
        guard !Task.isCancelled else { return .importStopped }

        return reason(forSkipping: error)
    }

    private static func reason(forSkipping error: PictureFileError) -> SkippedFile.Reason {
        switch error {
        case .notAPicture: .notAPicture
        case .damaged: .damaged
        case .soundOnly: .soundOnly
        case .copyProtected: .copyProtected
        case .notFound, .notPermitted, .unexpected: .cannotBeRead
        }
    }

    private static func reason(forSkipping error: PicturePreviewError) -> SkippedFile.Reason {
        switch error {
        case .unreadable: .damaged
        case .unexpected: .cannotBeRead
        }
    }
}

struct ImportedPicture {
    let name: String
    let picture: Picture
    let content: Data
    let preview: Data
    let mayLookBlurry: Bool

    init(name: String, file: PictureFile, preview: Data) {
        self.name = name
        picture = Picture(
            id: PictureID(UUID()),
            origin: .imported,
            captureTime: file.captureTime,
            fingerprint: file.fingerprint,
        )
        content = file.content
        self.preview = preview
        mayLookBlurry = file.pixelSize.mayLookBlurryOnTheDesktop
    }

    var contentByPicture: [PictureID: Data] {
        [picture.id: content]
    }

    var previewByPicture: [PictureID: Data] {
        [picture.id: preview]
    }
}

enum PictureStoringOutcome {
    case stored
    case noSpaceLeft
}

struct ImportedFiles {
    enum Outcome {
        case readable(ImportedPicture)
        case skipped(SkippedFile)
    }

    private let outcomes: [Outcome]

    fileprivate init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    var pictures: [Picture] {
        readablePictures.map(\.picture)
    }

    var holdsAPicture: Bool {
        !readablePictures.isEmpty
    }

    var summaryWithNothingStored: ImportSummary {
        summary(afterStoring: 0, stoppedForLackOfSpace: false)
    }

    func storePictureByPicture<Failure: Error>(
        placedAs placements: [PlacedPicture],
        _ store: (ImportedPicture, Slot) async throws(Failure) -> PictureStoringOutcome,
    ) async throws(Failure) -> ImportSummary {
        try await storePictureByPicture(into: placements.map(\.slot), store)
    }

    func storePictureByPicture<Failure: Error>(
        into slots: [Slot],
        _ store: (ImportedPicture, Slot) async throws(Failure) -> PictureStoringOutcome,
    ) async throws(Failure) -> ImportSummary {
        var storedCount = 0
        for (imported, slot) in zip(readablePictures, slots) {
            guard try await store(imported, slot) == .stored else {
                return summary(afterStoring: storedCount, stoppedForLackOfSpace: true)
            }

            storedCount += 1
        }
        return summary(afterStoring: storedCount, stoppedForLackOfSpace: false)
    }

    private var readablePictures: [ImportedPicture] {
        outcomes.compactMap { outcome in
            guard case let .readable(imported) = outcome else { return nil }

            return imported
        }
    }

    private func summary(afterStoring storedCount: Int, stoppedForLackOfSpace: Bool) -> ImportSummary {
        var readableSoFar = 0
        var skippedFiles: [SkippedFile] = []
        var filesThatMayLookBlurry: [String] = []
        for outcome in outcomes {
            switch outcome {
            case let .skipped(skipped):
                skippedFiles.append(skipped)
            case let .readable(imported) where readableSoFar < storedCount:
                readableSoFar += 1
                if imported.mayLookBlurry {
                    filesThatMayLookBlurry.append(imported.name)
                }
            case let .readable(imported):
                readableSoFar += 1
                skippedFiles.append(SkippedFile(name: imported.name, reason: .noSpaceLeft))
            }
        }
        return ImportSummary(
            addedPictureCount: storedCount,
            skippedFiles: skippedFiles,
            filesThatMayLookBlurry: filesThatMayLookBlurry,
            stoppedForLackOfSpace: stoppedForLackOfSpace,
            wasStopped: wasStopped,
        )
    }

    private var wasStopped: Bool {
        outcomes.contains { outcome in
            guard case let .skipped(skipped) = outcome else { return false }

            return skipped.reason == .importStopped
        }
    }
}

extension WallpaperError {
    var descriptionOfTheBrokenRule: String {
        switch self {
        case .noPictures: "A wallpaper was left without pictures."
        case .pictureInTwoSlots: "A picture was given to two slots."
        case .tooFewFilesToCreate: "Too few files were given to create a wallpaper."
        case .tooManyFilesToCreate: "Too many files were given to create a wallpaper."
        case .noEmptySlot: "A picture was given to a wallpaper with no empty slot."
        case .moreFilesThanEmptySlots: "More pictures were given than the wallpaper has empty slots."
        case .slotHoldsRealPicture: "A picture was given to a slot that holds a real picture."
        case .identicalPictureAlreadyInWallpaper: "Two identical pictures were given to one wallpaper."
        }
    }
}
