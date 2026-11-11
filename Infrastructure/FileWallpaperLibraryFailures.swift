import Application
import Foundation

extension FileWallpaperLibrary {
    static func libraryError(describing failure: any Error) -> WallpaperLibraryError {
        if let libraryError = failure as? WallpaperLibraryError {
            return libraryError
        }
        if let cocoaError = failure as? CocoaError {
            return libraryError(describingCocoaError: cocoaError)
        }
        if let posixError = failure as? POSIXError {
            return libraryError(describingPOSIXError: posixError)
        }
        return .unexpected(description: String(describing: failure))
    }

    private static func libraryError(describingCocoaError cocoaError: CocoaError) -> WallpaperLibraryError {
        switch cocoaError.code {
        case .fileNoSuchFile, .fileReadNoSuchFile: return .notFound
        case .fileReadNoPermission, .fileWriteNoPermission: return .notPermitted
        case .fileWriteOutOfSpace: return .noSpaceLeft
        case .fileWriteVolumeReadOnly: return .unavailable
        default:
            guard let underlyingFailure = cocoaError.underlying else {
                return .unexpected(description: String(describing: cocoaError))
            }

            return libraryError(describing: underlyingFailure, otherwiseUnexpected: cocoaError)
        }
    }

    private static func libraryError(describingPOSIXError posixError: POSIXError) -> WallpaperLibraryError {
        switch posixError.code {
        case .ENOENT: .notFound
        case .EACCES, .EPERM: .notPermitted
        case .ENOSPC, .EDQUOT: .noSpaceLeft
        case .EROFS: .unavailable
        default: .unexpected(description: String(describing: posixError))
        }
    }

    private static func libraryError(
        describing underlyingFailure: any Error,
        otherwiseUnexpected failure: any Error,
    ) -> WallpaperLibraryError {
        let recognised = libraryError(describing: underlyingFailure)
        if case .unexpected = recognised {
            return .unexpected(description: String(describing: failure))
        }
        return recognised
    }

    static func translatingFailures<Result>(_ work: () throws -> Result) throws(WallpaperLibraryError)
        -> Result
    {
        do {
            return try work()
        } catch {
            throw libraryError(describing: error)
        }
    }

    static func readingWhatMustBeThere<Result>(
        _ work: () throws(WallpaperLibraryError) -> Result,
    ) throws(WallpaperLibraryError) -> Result {
        do {
            return try work()
        } catch .notFound {
            throw .unreadable
        } catch {
            throw error
        }
    }

    static func removeUnlessAlreadyGone(_ item: URL) throws(WallpaperLibraryError) {
        do {
            try translatingFailures { try FileManager.default.removeItem(at: item) }
        } catch .notFound {
            return
        } catch {
            throw error
        }
    }
}
