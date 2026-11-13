import Application
import AVFoundation
import CryptoKit
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct VideoFileContents {
    let hasAVideoPicture: Bool
    let hasSound: Bool
    let isCopyProtected: Bool
}

public struct AVFoundationVideoFrames: PictureFiles {
    private static let onePicture = 1
    private static let frameLengthWhenTheVideoStatesNone = CMTime(value: 1, timescale: 30)
    private static let theReadWasStopped = PictureFileError.unexpected(
        description: "The read of the video was stopped before a frame was taken",
    )

    public init() {}

    @concurrent
    public func picture(in file: URL) async throws(PictureFileError) -> PictureFile {
        let accessIsScoped = file.startAccessingSecurityScopedResource()
        defer {
            if accessIsScoped {
                file.stopAccessingSecurityScopedResource()
            }
        }

        try Self.confirmThatTheFileOpensForReading(file)
        try Self.stopWhenTheReadIsCancelled()
        let frame = try await Self.frameShownAtTheMiddle(of: AVURLAsset(url: file))
        try Self.stopWhenTheReadIsCancelled()
        let content = try Self.pngContent(of: frame)
        try Self.stopWhenTheReadIsCancelled()
        return try PictureFile(
            content: content,
            fingerprint: Self.fingerprint(of: content),
            captureTime: nil,
            pixelSize: Self.pixelSize(of: frame),
        )
    }

    static func refusal(of contents: VideoFileContents) -> PictureFileError? {
        if contents.isCopyProtected {
            return .copyProtected
        }
        if contents.hasAVideoPicture {
            return nil
        }
        return contents.hasSound ? .soundOnly : .damaged
    }

    private static func confirmThatTheFileOpensForReading(_ file: URL) throws(PictureFileError) {
        do {
            try FileHandle(forReadingFrom: file).close()
        } catch {
            throw pictureFileError(describingReadFailure: error)
        }
    }

    private static func stopWhenTheReadIsCancelled() throws(PictureFileError) {
        if Task.isCancelled {
            throw theReadWasStopped
        }
    }

    private static func frameShownAtTheMiddle(of video: AVURLAsset) async throws(PictureFileError) -> CGImage {
        let layout = try await layout(of: video)
        if let refusal = refusal(of: layout.contents) {
            throw refusal
        }

        let search = SearchForAReadableFrame(frames: frameTaker(for: video), timeline: layout.timeline)
        guard let frame = try await search.frameNearestToTheMiddle() else {
            throw .damaged
        }

        return frame
    }

    private static func frameTaker(for video: AVURLAsset) -> AVAssetImageGenerator {
        let frames = AVAssetImageGenerator(asset: video)
        frames.requestedTimeToleranceBefore = .zero
        frames.requestedTimeToleranceAfter = .zero
        return frames
    }

    fileprivate static func frame(
        shownAt point: CMTime,
        takenFrom frames: AVAssetImageGenerator,
    ) async throws(PictureFileError) -> CGImage? {
        try stopWhenTheReadIsCancelled()
        let stopOfTheFrameBeingTaken = StopOfFrameTaking(by: frames)
        let frame = await withTaskCancellationHandler { () -> CGImage? in
            do {
                return try await frames.image(at: point).image
            } catch {
                return nil
            }
        } onCancel: {
            stopOfTheFrameBeingTaken.happen()
        }
        try stopWhenTheReadIsCancelled()
        return frame
    }

    private static func layout(of video: AVURLAsset) async throws(PictureFileError) -> VideoLayout {
        do {
            let (length, isCopyProtected) = try await video.load(.duration, .hasProtectedContent)
            let pictureTracks = try await video.loadTracks(withMediaType: .video)
            let soundTracks = try await video.loadTracks(withMediaType: .audio)
            let statedFrameLength = try await pictureTracks.first?.load(.minFrameDuration)
            return VideoLayout(
                contents: VideoFileContents(
                    hasAVideoPicture: !pictureTracks.isEmpty,
                    hasSound: !soundTracks.isEmpty,
                    isCopyProtected: isCopyProtected,
                ),
                timeline: VideoTimeline(
                    length: length,
                    frameLength: statedFrameLength.flatMap { $0.isNumeric && $0 > .zero ? $0 : nil }
                        ?? frameLengthWhenTheVideoStatesNone,
                ),
            )
        } catch {
            try stopWhenTheReadIsCancelled()
            throw pictureFileError(describingVideoFailure: error)
        }
    }

    private static func pictureFileError(describingVideoFailure failure: any Error) -> PictureFileError {
        guard let videoFailure = failure as? AVError else {
            return .unexpected(description: String(describing: failure))
        }

        return videoFailure.code == .contentIsProtected ? .copyProtected : .damaged
    }

    private static func pngContent(of frame: CGImage) throws(PictureFileError) -> Data {
        let content = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            content as CFMutableData,
            UTType.png.identifier as CFString,
            onePicture,
            nil,
        ) else {
            throw .unexpected(description: "No PNG could be started for the frame of the video")
        }

        CGImageDestinationAddImage(destination, frame, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .unexpected(description: "The frame of the video could not be written as PNG")
        }

        return content as Data
    }

    private static func pixelSize(of frame: CGImage) throws(PictureFileError) -> PixelSize {
        do {
            return try PixelSize(width: frame.width, height: frame.height)
        } catch {
            throw .damaged
        }
    }

    private static func fingerprint(of content: Data) throws(PictureFileError) -> ContentFingerprint {
        let hexadecimalDigest = SHA256.hash(data: content)
            .map { String(format: "%02x", $0) }
            .joined()
        do {
            return try ContentFingerprint(hexadecimalDigest)
        } catch {
            throw .unexpected(description: "The SHA-256 of the frame gave no fingerprint: \(error)")
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

private struct VideoLayout {
    let contents: VideoFileContents
    let timeline: VideoTimeline
}

private enum SideOfTheMiddle: CaseIterable {
    case earlier
    case later
}

private struct VideoTimeline {
    private static let farthestDistanceThatCanBeCounted = Int(Int32.max)

    private let middle: CMTime
    private let end: CMTime
    private let frameLength: CMTime

    init(length: CMTime, frameLength: CMTime) {
        let lengthIsKnown = length.isNumeric && length > .zero
        end = lengthIsKnown ? length : .zero
        middle = lengthIsKnown ? CMTimeMultiplyByRatio(length, multiplier: 1, divisor: 2) : .zero
        self.frameLength = frameLength
    }

    func framesBetweenTheMiddleAndTheEdge(_ side: SideOfTheMiddle) -> Int {
        let frames =
            switch side {
            case .earlier: (middle.seconds / frameLength.seconds).rounded(.down)
            case .later: ((end - middle).seconds / frameLength.seconds).rounded(.up) - 1
            }
        return min(max(Int(exactly: frames) ?? 0, 0), Self.farthestDistanceThatCanBeCounted)
    }

    func point(_ frames: Int, framesFromTheMiddleOnThe side: SideOfTheMiddle) -> CMTime {
        let distance = CMTimeMultiply(frameLength, multiplier: Int32(clamping: frames))
        return switch side {
        case .earlier: middle - distance
        case .later: middle + distance
        }
    }
}

private struct SearchForAReadableFrame {
    private struct ReadableFrame {
        let image: CGImage
        let framesFromTheMiddle: Int
        let side: SideOfTheMiddle
    }

    let frames: AVAssetImageGenerator
    let timeline: VideoTimeline

    func frameNearestToTheMiddle() async throws(PictureFileError) -> CGImage? {
        if let frameAtTheMiddle = try await frame(0, framesFromTheMiddleOnThe: .earlier) {
            return frameAtTheMiddle.image
        }

        let farthestDistance = SideOfTheMiddle.allCases.map(timeline.framesBetweenTheMiddleAndTheEdge).max() ?? 0
        var unreadableDistance = 0
        var distance = 1
        while unreadableDistance < farthestDistance {
            var nearestOnEachSide: [ReadableFrame] = []
            for side in SideOfTheMiddle.allCases {
                let reach = min(distance, timeline.framesBetweenTheMiddleAndTheEdge(side))
                if reach > unreadableDistance, let readable = try await frame(reach, framesFromTheMiddleOnThe: side) {
                    try await nearestOnEachSide.append(nearest(to: readable, beyond: unreadableDistance))
                }
            }
            if let nearest = nearestOnEachSide.min(by: { $0.framesFromTheMiddle < $1.framesFromTheMiddle }) {
                return nearest.image
            }
            unreadableDistance = distance
            distance *= 2
        }
        return nil
    }

    private func nearest(
        to readable: ReadableFrame,
        beyond unreadableDistance: Int,
    ) async throws(PictureFileError) -> ReadableFrame {
        var nearestReadable = readable
        var farthestUnreadable = unreadableDistance
        while nearestReadable.framesFromTheMiddle - farthestUnreadable > 1 {
            let between = (nearestReadable.framesFromTheMiddle + farthestUnreadable) / 2
            if let readableBetween = try await frame(between, framesFromTheMiddleOnThe: readable.side) {
                nearestReadable = readableBetween
            } else {
                farthestUnreadable = between
            }
        }
        return nearestReadable
    }

    private func frame(
        _ distance: Int,
        framesFromTheMiddleOnThe side: SideOfTheMiddle,
    ) async throws(PictureFileError) -> ReadableFrame? {
        let point = timeline.point(distance, framesFromTheMiddleOnThe: side)
        return try await AVFoundationVideoFrames.frame(shownAt: point, takenFrom: frames)
            .map { ReadableFrame(image: $0, framesFromTheMiddle: distance, side: side) }
    }
}

private struct StopOfFrameTaking: @unchecked Sendable {
    private let frames: AVAssetImageGenerator

    init(by frames: AVAssetImageGenerator) {
        self.frames = frames
    }

    func happen() {
        frames.cancelAllCGImageGeneration()
    }
}
