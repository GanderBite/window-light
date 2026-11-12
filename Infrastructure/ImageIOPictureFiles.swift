import Application
import CryptoKit
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageIOPictureFiles: PictureFiles {
    private static let firstFrame = 0
    private static let orientationsTurnedAQuarter: Set<Int> = [5, 6, 7, 8]

    public init() {}

    public func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        let content = try Self.contentReadOnce(from: file)
        let firstFrame = try Self.decodedFirstFrame(of: content, namedLike: file)
        return try PictureFile(
            content: content,
            fingerprint: Self.fingerprint(of: content),
            captureTime: Self.captureTime(in: firstFrame.properties),
            pixelSize: Self.uprightPixelSize(of: firstFrame),
        )
    }

    private static func contentReadOnce(from file: URL) throws(PictureFileError) -> Data {
        let accessIsScoped = file.startAccessingSecurityScopedResource()
        defer {
            if accessIsScoped {
                file.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try Data(contentsOf: file)
        } catch {
            throw pictureFileError(describingReadFailure: error)
        }
    }

    private static func decodedFirstFrame(
        of content: Data,
        namedLike file: URL,
    ) throws(PictureFileError) -> DecodedFrame {
        guard let source = CGImageSourceCreateWithData(content as CFData, nil),
              CGImageSourceGetType(source) != nil
        else {
            throw nameSaysItIsAnImage(file) ? .damaged : .notAPicture
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, firstFrame, nil) else {
            throw .damaged
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, firstFrame, nil) as? [CFString: Any] ?? [:]
        return DecodedFrame(image: image, properties: properties)
    }

    private static func nameSaysItIsAnImage(_ file: URL) -> Bool {
        UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) ?? false
    }

    private static func uprightPixelSize(of frame: DecodedFrame) throws(PictureFileError) -> PixelSize {
        let isTurnedAQuarter = frame.orientation.map { orientationsTurnedAQuarter.contains($0) } ?? false
        do {
            return isTurnedAQuarter
                ? try PixelSize(width: frame.image.height, height: frame.image.width)
                : try PixelSize(width: frame.image.width, height: frame.image.height)
        } catch {
            throw .damaged
        }
    }

    private static func captureTime(in properties: [CFString: Any]) -> CaptureTime? {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        guard let writtenTime = exif?[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return nil
        }

        return ExifDateTime(writtenTime)?.captureTimeIfItIsARealDateAndTime
    }

    private static func fingerprint(of content: Data) throws(PictureFileError) -> ContentFingerprint {
        let hexadecimalDigest = SHA256.hash(data: content)
            .map { String(format: "%02x", $0) }
            .joined()
        do {
            return try ContentFingerprint(hexadecimalDigest)
        } catch {
            throw .unexpected(description: "The SHA-256 of the file gave no fingerprint: \(error)")
        }
    }

    private static func pictureFileError(describingReadFailure failure: any Error) -> PictureFileError {
        if let cocoaError = failure as? CocoaError {
            switch cocoaError.code {
            case .fileNoSuchFile, .fileReadNoSuchFile: return .notFound
            case .fileReadNoPermission: return .notPermitted
            default: break
            }
            if let underlyingFailure = cocoaError.underlying as? POSIXError {
                return pictureFileError(describingPOSIXError: underlyingFailure, otherwiseUnexpected: cocoaError)
            }
            return .unexpected(description: String(describing: cocoaError))
        }
        if let posixError = failure as? POSIXError {
            return pictureFileError(describingPOSIXError: posixError, otherwiseUnexpected: posixError)
        }
        return .unexpected(description: String(describing: failure))
    }

    private static func pictureFileError(
        describingPOSIXError posixError: POSIXError,
        otherwiseUnexpected failure: any Error,
    ) -> PictureFileError {
        switch posixError.code {
        case .ENOENT: .notFound
        case .EACCES, .EPERM: .notPermitted
        default: .unexpected(description: String(describing: failure))
        }
    }
}

private struct DecodedFrame {
    let image: CGImage
    let properties: [CFString: Any]

    var orientation: Int? {
        properties[kCGImagePropertyOrientation] as? Int
    }
}

private struct ExifDateTime {
    private static let writtenForm = Array("yyyy:MM:dd HH:mm:ss")
    private static let yearDigits = 0 ..< 4
    private static let monthDigits = 5 ..< 7
    private static let dayDigits = 8 ..< 10
    private static let hourDigits = 11 ..< 13
    private static let minuteDigits = 14 ..< 16
    private static let secondDigits = 17 ..< 19

    private let year: Int
    private let month: Int
    private let day: Int
    private let hour: Int
    private let minute: Int
    private let second: Int

    init?(_ written: String) {
        let characters = Array(written)
        guard Self.hasTheWrittenForm(characters) else { return nil }

        func number(in digits: Range<Int>) -> Int {
            characters[digits].reduce(0) { $0 * 10 + ($1.wholeNumberValue ?? 0) }
        }
        year = number(in: Self.yearDigits)
        month = number(in: Self.monthDigits)
        day = number(in: Self.dayDigits)
        hour = number(in: Self.hourDigits)
        minute = number(in: Self.minuteDigits)
        second = number(in: Self.secondDigits)
    }

    private static func hasTheWrittenForm(_ characters: [Character]) -> Bool {
        guard characters.count == writtenForm.count else { return false }

        return zip(characters, writtenForm).allSatisfy { character, expected in
            expected.isLetter ? character.isASCII && character.isNumber : character == expected
        }
    }

    var captureTimeIfItIsARealDateAndTime: CaptureTime? {
        do {
            return try CaptureTime(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        } catch {
            return nil
        }
    }
}
