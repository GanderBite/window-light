import Application
import Foundation

actor PictureFilesStandIn: PictureFiles {
    private let answers: [URL: Result<PictureFile, PictureFileError>]
    private(set) var askedFiles: [URL] = []

    init(answering answers: [URL: Result<PictureFile, PictureFileError>]) {
        self.answers = answers
    }

    func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        askedFiles.append(file)
        guard let answer = answers[file] else { throw .notFound }

        return try answer.get()
    }
}
