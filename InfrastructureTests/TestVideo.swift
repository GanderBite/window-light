import AVFoundation
import CoreGraphics
import Foundation
import VideoToolbox

struct TestVideo {
    enum Container: CaseIterable {
        case mov
        case mp4
        case m4v

        var fileType: AVFileType {
            switch self {
            case .mov: .mov
            case .mp4: .mp4
            case .m4v: .m4v
            }
        }

        var fileExtension: String {
            switch self {
            case .mov: "mov"
            case .mp4: "mp4"
            case .m4v: "m4v"
            }
        }
    }

    enum Tracks {
        case runningCounter
        case soundOnly
    }

    enum Damage {
        case cutOffSoThatTheLastWholeFrameIs(Int)
        case cutOffSoThatNoFrameIsWhole
        case bytesThatAreNotAVideo
    }

    enum MakingFailure: Error {
        case drawingFailed
        case writingFailed(description: String)
        case counterCannotBeShown(frameNumber: Int)
        case counterCannotBeRead
        case frameIsNotStoredInOnePiece(frameNumber: Int)
    }

    var width = 640
    var height = 360
    var frameCount = 10
    var framesPerSecond = 30
    var container = Container.mov
    var tracks = Tracks.runningCounter
    var damage: Damage?

    private static let counterStripeCount = 12
    private static let noKeyFrameAfterTheFirst = 100_000
    private static let brightnessThatSeparatesLitFromDark = 128
    private static let soundSampleRate = 44100
    private static let soundSamplesPerBuffer = 4410
    private static let soundBufferCount = 10
    private static let bytesPerSoundSample = 2
    private static let waitForTheWriter = Duration.milliseconds(2)

    static var canBeEncodedOnThisMac: Bool {
        var encoders: CFArray?
        guard VTCopyVideoEncoderList(nil, &encoders) == noErr,
              let encoders = encoders as? [[CFString: Any]]
        else {
            return false
        }

        return encoders.contains { encoder in
            (encoder[kVTVideoEncoderList_CodecType] as? NSNumber)?.uint32Value == kCMVideoCodecType_H264
        }
    }

    func written(into folder: URL, named name: String = "video") async throws -> URL {
        let file = folder.appending(path: "\(name).\(container.fileExtension)")
        if case .bytesThatAreNotAVideo = damage {
            try Data("Buy milk and film".utf8).write(to: file)
            return file
        }

        let workshop = FileManager.default.temporaryDirectory
            .appending(path: "TestVideo-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workshop, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workshop) }
        let fileBeingMade = workshop.appending(path: file.lastPathComponent)

        switch tracks {
        case .runningCounter: try await writeRunningCounter(to: fileBeingMade)
        case .soundOnly: try await writeSound(to: fileBeingMade)
        }
        switch damage {
        case let .cutOffSoThatTheLastWholeFrameIs(frameNumber):
            try await Self.cutOff(fileBeingMade, afterFrame: frameNumber)
        case .cutOffSoThatNoFrameIsWhole:
            try await Self.cutOff(fileBeingMade, afterFrame: nil)
        case .bytesThatAreNotAVideo, nil:
            break
        }
        try FileManager.default.moveItem(at: fileBeingMade, to: file)
        return file
    }

    static func counter(shownIn image: CGImage) throws -> Int {
        var counter = 0
        for stripe in 0 ..< counterStripeCount where try isLit(stripe, in: image) {
            counter |= 1 << stripe
        }
        return counter
    }

    static func keyFrameNumbers(in file: URL) async throws -> [Int] {
        let cursor = try await cursorAtTheFirstFrame(of: file)
        var keyFrameNumbers: [Int] = []
        var frameNumber = 0
        repeat {
            if cursor.currentSampleSyncInfo.sampleIsFullSync.boolValue {
                keyFrameNumbers.append(frameNumber)
            }
            frameNumber += 1
        } while cursor.stepInDecodeOrder(byCount: 1) == 1
        return keyFrameNumbers
    }

    private func writeRunningCounter(to file: URL) async throws {
        let writer = try AVAssetWriter(outputURL: file, fileType: container.fileType)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoMaxKeyFrameIntervalKey: Self.noKeyFrameAfterTheFirst,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        try Self.start(writer)

        for frameNumber in 0 ..< frameCount {
            try await Self.waitUntilReady(input)
            let frame = try drawnFrame(showing: frameNumber)
            guard adaptor.append(frame, withPresentationTime: time(ofFrame: frameNumber)) else {
                throw Self.failure(of: writer)
            }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: time(ofFrame: frameCount))
        try await Self.finish(writer)
    }

    private func time(ofFrame frameNumber: Int) -> CMTime {
        CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(framesPerSecond))
    }

    private func drawnFrame(showing frameNumber: Int) throws -> CVPixelBuffer {
        guard frameNumber < 1 << Self.counterStripeCount else {
            throw MakingFailure.counterCannotBeShown(frameNumber: frameNumber)
        }

        var createdBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &createdBuffer)
        guard let buffer = createdBuffer else {
            throw MakingFailure.drawingFailed
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue,
        ) else {
            throw MakingFailure.drawingFailed
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 1, alpha: 1)
        for stripe in 0 ..< Self.counterStripeCount where frameNumber & (1 << stripe) != 0 {
            context.fill(Self.area(ofStripe: stripe, inPictureOfWidth: width, height: height))
        }
        return buffer
    }

    private static func area(ofStripe stripe: Int, inPictureOfWidth width: Int, height: Int) -> CGRect {
        let left = width * stripe / counterStripeCount
        let right = width * (stripe + 1) / counterStripeCount
        return CGRect(x: left, y: 0, width: right - left, height: height)
    }

    private static func isLit(_ stripe: Int, in image: CGImage) throws -> Bool {
        let stripeArea = area(ofStripe: stripe, inPictureOfWidth: image.width, height: image.height)
        let middlePixel = CGRect(x: Int(stripeArea.midX), y: Int(stripeArea.midY), width: 1, height: 1)
        var brightness: UInt8 = 0
        guard let pixel = image.cropping(to: middlePixel),
              let context = CGContext(
                  data: &brightness,
                  width: 1,
                  height: 1,
                  bitsPerComponent: 8,
                  bytesPerRow: 1,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGImageAlphaInfo.none.rawValue,
              )
        else {
            throw MakingFailure.counterCannotBeRead
        }

        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return brightness >= brightnessThatSeparatesLitFromDark
    }

    private func writeSound(to file: URL) async throws {
        let writer = try AVAssetWriter(outputURL: file, fileType: container.fileType)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Self.soundSampleRate,
            AVNumberOfChannelsKey: 1,
        ])
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        try Self.start(writer)

        for bufferNumber in 0 ..< Self.soundBufferCount {
            try await Self.waitUntilReady(input)
            guard try input.append(Self.silence(inBuffer: bufferNumber)) else {
                throw Self.failure(of: writer)
            }
        }
        input.markAsFinished()
        try await Self.finish(writer)
    }

    private static func descriptionOfUncompressedSound() -> CMAudioFormatDescription? {
        var soundFormat = AudioStreamBasicDescription(
            mSampleRate: Float64(soundSampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: UInt32(bytesPerSoundSample),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSoundSample),
            mChannelsPerFrame: 1,
            mBitsPerChannel: UInt32(bytesPerSoundSample * 8),
            mReserved: 0,
        )
        var createdDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil,
            asbd: &soundFormat,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &createdDescription,
        )
        return createdDescription
    }

    private static func silence(inBuffer bufferNumber: Int) throws -> CMSampleBuffer {
        let byteCount = soundSamplesPerBuffer * bytesPerSoundSample
        var createdBytes: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: byteCount,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: byteCount,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &createdBytes,
        )
        guard let description = descriptionOfUncompressedSound(), let bytes = createdBytes else {
            throw MakingFailure.writingFailed(description: "The silence could not be laid out")
        }

        CMBlockBufferFillDataBytes(with: 0, blockBuffer: bytes, offsetIntoDestination: 0, dataLength: byteCount)
        var createdBuffer: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil,
            dataBuffer: bytes,
            formatDescription: description,
            sampleCount: soundSamplesPerBuffer,
            presentationTimeStamp: CMTime(
                value: CMTimeValue(bufferNumber * soundSamplesPerBuffer),
                timescale: CMTimeScale(soundSampleRate),
            ),
            packetDescriptions: nil,
            sampleBufferOut: &createdBuffer,
        )
        guard let buffer = createdBuffer else {
            throw MakingFailure.writingFailed(description: "The silence could not be put in a buffer")
        }

        return buffer
    }

    private static func start(_ writer: AVAssetWriter) throws {
        guard writer.startWriting() else {
            throw failure(of: writer)
        }

        writer.startSession(atSourceTime: .zero)
    }

    private static func waitUntilReady(_ input: AVAssetWriterInput) async throws {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(for: waitForTheWriter)
        }
    }

    private static func finish(_ writer: AVAssetWriter) async throws {
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw failure(of: writer)
        }
    }

    private static func failure(of writer: AVAssetWriter) -> MakingFailure {
        .writingFailed(description: writer.error.map { String(describing: $0) } ?? "The writer gave no reason")
    }

    private static func cursorAtTheFirstFrame(of file: URL) async throws -> AVSampleCursor {
        let videoTracks = try await AVURLAsset(url: file).loadTracks(withMediaType: .video)
        guard let cursor = videoTracks.first?.makeSampleCursorAtFirstSampleInDecodeOrder() else {
            throw MakingFailure.writingFailed(description: "The video gives no way to walk through its frames")
        }

        return cursor
    }

    private static func cutOff(_ file: URL, afterFrame lastWholeFrame: Int?) async throws {
        let cursor = try await cursorAtTheFirstFrame(of: file)
        var frameNumber = 0
        if let lastWholeFrame {
            frameNumber = Int(cursor.stepInDecodeOrder(byCount: Int64(lastWholeFrame)))
        }
        let storage = cursor.currentSampleStorageRange
        guard storage.offset >= 0, frameNumber == lastWholeFrame ?? 0 else {
            throw MakingFailure.frameIsNotStoredInOnePiece(frameNumber: frameNumber)
        }

        let firstByteCutOff = lastWholeFrame == nil ? storage.offset : storage.offset + storage.length
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(firstByteCutOff))
    }
}
