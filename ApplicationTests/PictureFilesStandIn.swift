import Application
import Foundation

actor PictureFilesStandIn: PictureFiles {
    private let answers: [URL: Result<PictureFile, PictureFileError>]
    private let fileWhoseReadStopsTheImport: URL?
    private(set) var askedFiles: [URL] = []

    init(
        answering answers: [URL: Result<PictureFile, PictureFileError>],
        cancellingTheAskingTaskWhenAskedFor fileWhoseReadStopsTheImport: URL? = nil,
    ) {
        self.answers = answers
        self.fileWhoseReadStopsTheImport = fileWhoseReadStopsTheImport
    }

    func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        askedFiles.append(file)
        if file == fileWhoseReadStopsTheImport {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        guard let answer = answers[file] else { throw .notFound }

        return try answer.get()
    }
}
