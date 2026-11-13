import Application
import Domain
import Foundation
import UniformTypeIdentifiers

public struct ChosenPictureFiles: PictureFiles {
    private let imageReader = ImageIOPictureFiles()
    private let videoReader = AVFoundationVideoFrames()

    public init() {}

    public func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        if Self.nameSaysItIsAVideoOrSound(file) {
            try await videoReader.picture(in: file)
        } else {
            try await imageReader.picture(in: file)
        }
    }

    private static func nameSaysItIsAVideoOrSound(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .audiovisualContent) ?? false
    }
}
