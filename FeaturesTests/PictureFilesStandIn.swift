import Application
import Foundation

actor PictureFilesStandIn: PictureFiles {
    private let answers: [URL: Result<PictureFile, PictureFileError>]
    private let fileWhoseReadStopsTheImport: URL?
    private let fileWhoseReadWaits: URL?
    private var waitingRead: CheckedContinuation<Void, Never>?
    private var hasLetTheWaitingReadGoOn = false
    private var waitersForTheWaitingRead: [CheckedContinuation<Void, Never>] = []
    private(set) var askedFiles: [URL] = []

    init(
        answering answers: [URL: Result<PictureFile, PictureFileError>],
        cancellingTheAskingTaskWhenAskedFor fileWhoseReadStopsTheImport: URL? = nil,
        waitingWhenAskedFor fileWhoseReadWaits: URL? = nil,
    ) {
        self.answers = answers
        self.fileWhoseReadStopsTheImport = fileWhoseReadStopsTheImport
        self.fileWhoseReadWaits = fileWhoseReadWaits
    }

    func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        askedFiles.append(file)
        if file == fileWhoseReadStopsTheImport {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        if file == fileWhoseReadWaits {
            await waitUntilTheTestLetsTheReadGoOn()
        }
        guard let answer = answers[file] else { throw .notFound }

        return try answer.get()
    }

    func untilTheWaitingReadHasStarted() async {
        guard waitingRead == nil, !hasLetTheWaitingReadGoOn else { return }

        await withCheckedContinuation { waiter in
            waitersForTheWaitingRead.append(waiter)
        }
    }

    func letTheWaitingReadGoOn() {
        hasLetTheWaitingReadGoOn = true
        waitingRead?.resume()
        waitingRead = nil
    }

    private func waitUntilTheTestLetsTheReadGoOn() async {
        guard !hasLetTheWaitingReadGoOn else { return }

        await withCheckedContinuation { read in
            waitingRead = read
            for waiter in waitersForTheWaitingRead {
                waiter.resume()
            }
            waitersForTheWaitingRead = []
        }
    }
}
