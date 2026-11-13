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
        case sceneWithItsTopLeftCornerMarked
        case midGreyWithColourPatches(DynamicRange)
        case soundOnly

        fileprivate var leavesHardwareEncodingToTheCounter: Bool {
            switch self {
            case .sceneWithItsTopLeftCornerMarked, .midGreyWithColourPatches: true
            case .runningCounter, .soundOnly: false
            }
        }
    }

    enum DynamicRange {
        case standard
        case hybridLogGamma

        fileprivate var colourProperties: [String: String] {
            let standardColours = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
            let hybridLogGammaColours = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ]
            return self == .standard ? standardColours : hybridLogGammaColours
        }

        private static let hybridLogGammaA = 0.17883277
        private static let hybridLogGammaB = 0.28466892
        private static let hybridLogGammaC = 0.55991073
        private static let bt709LightInBT2020Primaries = [
            [0.6274, 0.3293, 0.0433],
            [0.0691, 0.9195, 0.0114],
            [0.0164, 0.0880, 0.8956],
        ]

        fileprivate func signal(recording light: Colour) -> [CGFloat] {
            let channels = [light.red, light.green, light.blue]
            let signals: [Double] =
                switch self {
                case .standard:
                    channels.map(Self.highDefinitionSignal)
                case .hybridLogGamma:
                    Self.inUltraHighDefinitionPrimaries(channels).map { channel in
                        Self.hybridLogGammaSignal(ofSceneLight: channel)
                    }
                }
            let opaque: CGFloat = 1
            return signals.map { CGFloat($0) } + [opaque]
        }

        private static func inUltraHighDefinitionPrimaries(_ channels: [Double]) -> [Double] {
            bt709LightInBT2020Primaries.map { row in
                zip(row, channels).reduce(0) { sum, factorAndChannel in
                    sum + factorAndChannel.0 * factorAndChannel.1
                }
            }
        }

        private static func highDefinitionSignal(ofSceneLight light: Double) -> Double {
            light < 0.018 ? 4.5 * light : 1.099 * pow(light, 0.45) - 0.099
        }

        private static func hybridLogGammaSignal(ofSceneLight light: Double) -> Double {
            if light <= 1.0 / 12 {
                return (3 * light).squareRoot()
            }
            return hybridLogGammaA * log(12 * light - hybridLogGammaB) + hybridLogGammaC
        }

        fileprivate var pictureFormat: PictureFormat {
            switch self {
            case .standard: .eightBitsInHighDefinitionColours
            case .hybridLogGamma: .halfFloatsInHybridLogGamma
            }
        }
    }

    enum Turn: CaseIterable {
        case notTurned
        case quarterToTheRight
        case quarterToTheLeft
        case upsideDown
        case mirrored

        fileprivate var storedCornerThatIsShownAtTheTopLeft: Corner {
            switch self {
            case .notTurned: .topLeft
            case .quarterToTheRight: .bottomLeft
            case .quarterToTheLeft, .mirrored: .topRight
            case .upsideDown: .bottomRight
            }
        }

        fileprivate func transform(ofPictureStoredAsWidth width: Int, height: Int) -> CGAffineTransform {
            let width = CGFloat(width)
            let height = CGFloat(height)
            return switch self {
            case .notTurned: .identity
            case .quarterToTheRight: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
            case .quarterToTheLeft: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
            case .upsideDown: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
            case .mirrored: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
            }
        }
    }

    enum Corner: CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var isAtTheLeft: Bool {
            self == .topLeft || self == .bottomLeft
        }

        var isAtTheTop: Bool {
            self == .topLeft || self == .topRight
        }
    }

    struct Colour: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        var brightness: Double {
            (red + green + blue) / 3
        }

        func largestChannelDifference(from other: Self) -> Double {
            max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
        }
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
        case frameCannotBeRead
        case frameIsNotStoredInOnePiece(frameNumber: Int)
    }

    var width = 640
    var height = 360
    var frameCount = 10
    var framesPerSecond = 30
    var container = Container.mov
    var tracks = Tracks.runningCounter
    var turn = Turn.notTurned
    var damage: Damage?

    private static let counterStripeCount = 12
    private static let noKeyFrameAfterTheFirst = 100_000
    private static let brightnessThatSeparatesLitFromDark = 128
    private static let soundSampleRate = 44100
    private static let soundSamplesPerBuffer = 4410
    private static let soundBufferCount = 10
    private static let bytesPerSoundSample = 2
    private static let waitForTheWriter = Duration.milliseconds(2)
    private static let cornerMarkPartOfTheShorterSide = 4
    private static let sceneBackground = Colour(red: 0.2, green: 0.2, blue: 0.2)
    private static let cornerMark = Colour(red: 1, green: 0, blue: 0)
    private static let lightOfTheMidGrey = Colour(red: 0.2, green: 0.2, blue: 0.2)
    private static let lightOfThePatches = [
        Colour(red: 0.6, green: 0.05, blue: 0.05),
        Colour(red: 0.05, green: 0.45, blue: 0.08),
        Colour(red: 0.05, green: 0.08, blue: 0.6),
    ]
    private static let partOfTheMarkThatIsMeasured = 0.5
    private static let mostAMarkedCornerDiffersFromTheMark = 0.25
    private static let middlePartOfThePicture = 0.25
    private static let brightestStandardRGBValue = 255.0

    private static var softwareEncoder: [CFString: Bool] {
        [kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: false]
    }

    static var hybridLogGammaCanBeEncodedOnThisMac: Bool {
        var supportedProperties: CFDictionary?
        let status = VTCopySupportedPropertyDictionaryForEncoder(
            width: 1920,
            height: 1080,
            codecType: kCMVideoCodecType_HEVC,
            encoderSpecification: softwareEncoder as CFDictionary,
            encoderIDOut: nil,
            supportedPropertiesOut: &supportedProperties,
        )
        guard status == noErr,
              let properties = supportedProperties as? [CFString: Any],
              let profileLevel = properties[kVTCompressionPropertyKey_ProfileLevel] as? [CFString: Any],
              let profileLevels = profileLevel[kVTPropertySupportedValueListKey] as? [String]
        else {
            return false
        }

        return profileLevels.contains(kVTProfileLevel_HEVC_Main10_AutoLevel as String)
    }

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
        case .runningCounter, .sceneWithItsTopLeftCornerMarked, .midGreyWithColourPatches:
            try await writePictures(to: fileBeingMade)
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

    static func cornersShowingTheMark(in image: CGImage) throws -> Set<Corner> {
        let side = Double(sideOfTheCornerMark(inPictureOfWidth: image.width, height: image.height))
        let measuredSide = side * partOfTheMarkThatIsMeasured
        let inset = (side - measuredSide) / 2
        var corners: Set<Corner> = []
        for corner in Corner.allCases {
            let area = CGRect(
                x: corner.isAtTheLeft ? inset : Double(image.width) - side + inset,
                y: corner.isAtTheTop ? inset : Double(image.height) - side + inset,
                width: measuredSide,
                height: measuredSide,
            )
            if try averageColour(of: area, in: image).largestChannelDifference(from: cornerMark)
                < mostAMarkedCornerDiffersFromTheMark
            {
                corners.insert(corner)
            }
        }
        return corners
    }

    static func colourOfTheMidGreyArea(in image: CGImage) throws -> Colour {
        let width = Double(image.width) * middlePartOfThePicture
        let height = Double(image.height) * middlePartOfThePicture
        let area = CGRect(
            x: (Double(image.width) - width) / 2,
            y: (Double(image.height) - height) / 2,
            width: width,
            height: height,
        )
        return try averageColour(of: area, in: image)
    }

    static func standardRGBValues(of image: CGImage) throws -> [UInt8] {
        let bytesPerPixel = 4
        var values = [UInt8](repeating: 0, count: image.width * image.height * bytesPerPixel)
        let drawn = values.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * bytesPerPixel,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
            ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            throw MakingFailure.frameCannotBeRead
        }

        return values
    }

    static func frame(_ frameNumber: Int, decodedFrom file: URL) async throws -> CGImage {
        let video = AVURLAsset(url: file)
        guard let track = try await video.loadTracks(withMediaType: .video).first else {
            throw MakingFailure.frameCannotBeRead
        }

        let reader = try AVAssetReader(asset: video)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        reader.add(output)
        guard reader.startReading() else {
            throw MakingFailure.frameCannotBeRead
        }

        defer { reader.cancelReading() }
        var framesLeft = frameNumber
        while let sample = output.copyNextSampleBuffer() {
            if framesLeft == 0, let buffer = sample.imageBuffer {
                return try image(of: buffer)
            }
            framesLeft -= 1
        }
        throw MakingFailure.frameCannotBeRead
    }

    private static func image(of buffer: CVImageBuffer) throws -> CGImage {
        let colourSpace = CVImageBufferCreateColorSpaceFromAttachments(
            CVBufferCopyAttachments(buffer, .shouldPropagate) ?? [:] as CFDictionary,
        )?.takeRetainedValue() ?? CGColorSpace(name: CGColorSpace.itur_709)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let colourSpace,
              let context = CGContext(
                  data: CVPixelBufferGetBaseAddress(buffer),
                  width: CVPixelBufferGetWidth(buffer),
                  height: CVPixelBufferGetHeight(buffer),
                  bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                  space: colourSpace,
                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue,
              ),
              let image = context.makeImage()
        else {
            throw MakingFailure.frameCannotBeRead
        }

        return image
    }

    private static func averageColour(of area: CGRect, in image: CGImage) throws -> Colour {
        let values = try standardRGBValues(of: image)
        let bytesPerPixel = 4
        var sums = [0.0, 0.0, 0.0]
        var pixelCount = 0.0
        for row in Int(area.minY) ..< Int(area.maxY) {
            for column in Int(area.minX) ..< Int(area.maxX) {
                let first = (row * image.width + column) * bytesPerPixel
                for channel in 0 ..< 3 {
                    sums[channel] += Double(values[first + channel])
                }
                pixelCount += 1
            }
        }
        guard pixelCount > 0 else {
            throw MakingFailure.frameCannotBeRead
        }

        let scale = pixelCount * brightestStandardRGBValue
        return Colour(red: sums[0] / scale, green: sums[1] / scale, blue: sums[2] / scale)
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

    private func writePictures(to file: URL) async throws {
        let writer = try AVAssetWriter(outputURL: file, fileType: container.fileType)
        writer.shouldOptimizeForNetworkUse = true
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: pictureSettings)
        input.expectsMediaDataInRealTime = false
        input.transform = turn.transform(ofPictureStoredAsWidth: width, height: height)
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

    private var pictureSettings: [String: Any] {
        var settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        var compression: [String: Any] = [
            AVVideoMaxKeyFrameIntervalKey: Self.noKeyFrameAfterTheFirst,
            AVVideoAllowFrameReorderingKey: false,
        ]
        if tracks.leavesHardwareEncodingToTheCounter {
            settings[AVVideoEncoderSpecificationKey] = Self.softwareEncoder
        }
        if case let .midGreyWithColourPatches(range) = tracks {
            settings[AVVideoColorPropertiesKey] = range.colourProperties
            if range == .hybridLogGamma {
                settings[AVVideoCodecKey] = AVVideoCodecType.hevc
                compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
            }
        }
        settings[AVVideoCompressionPropertiesKey] = compression
        return settings
    }

    private func time(ofFrame frameNumber: Int) -> CMTime {
        CMTime(value: CMTimeValue(frameNumber), timescale: CMTimeScale(framesPerSecond))
    }

    private func drawnFrame(showing frameNumber: Int) throws -> CVPixelBuffer {
        switch tracks {
        case .runningCounter:
            try drawnPicture(in: .eightBitsInStandardRGB) { context in
                try drawRunningCounter(showing: frameNumber, in: context)
            }
        case .sceneWithItsTopLeftCornerMarked:
            try drawnPicture(in: .eightBitsInStandardRGB, drawing: drawSceneWithItsTopLeftCornerMarked)
        case let .midGreyWithColourPatches(range):
            try drawnPicture(in: range.pictureFormat) { context in
                try drawMidGreyWithColourPatches(recordedIn: range, in: context)
            }
        case .soundOnly:
            throw MakingFailure.drawingFailed
        }
    }

    private func drawnPicture(
        in format: PictureFormat,
        drawing draw: (CGContext) throws -> Void,
    ) throws -> CVPixelBuffer {
        var createdBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, format.pixelFormat, nil, &createdBuffer)
        guard let buffer = createdBuffer, let colourSpace = CGColorSpace(name: format.colourSpaceName) else {
            throw MakingFailure.drawingFailed
        }

        for (key, value) in format.colourAttachments {
            CVBufferSetAttachment(buffer, key, value, .shouldPropagate)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: format.bitsPerComponent,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colourSpace,
            bitmapInfo: format.bitmapInfo,
        ) else {
            throw MakingFailure.drawingFailed
        }

        try draw(context)
        return buffer
    }

    private func drawRunningCounter(showing frameNumber: Int, in context: CGContext) throws {
        guard frameNumber < 1 << Self.counterStripeCount else {
            throw MakingFailure.counterCannotBeShown(frameNumber: frameNumber)
        }

        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 1, alpha: 1)
        for stripe in 0 ..< Self.counterStripeCount where frameNumber & (1 << stripe) != 0 {
            context.fill(Self.area(ofStripe: stripe, inPictureOfWidth: width, height: height))
        }
    }

    private func drawSceneWithItsTopLeftCornerMarked(in context: CGContext) {
        context.setFillColor(Self.standardRGB(Self.sceneBackground))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let side = Self.sideOfTheCornerMark(inPictureOfWidth: width, height: height)
        let corner = turn.storedCornerThatIsShownAtTheTopLeft
        let markArea = CGRect(
            x: corner.isAtTheLeft ? 0 : width - side,
            y: corner.isAtTheTop ? height - side : 0,
            width: side,
            height: side,
        )
        context.setFillColor(Self.standardRGB(Self.cornerMark))
        context.fill(markArea)
    }

    private func drawMidGreyWithColourPatches(recordedIn range: DynamicRange, in context: CGContext) throws {
        guard let colourSpace = context.colorSpace else {
            throw MakingFailure.drawingFailed
        }

        func fill(_ area: CGRect, withTheSignalOf light: Colour) throws {
            guard let colour = CGColor(colorSpace: colourSpace, components: range.signal(recording: light)) else {
                throw MakingFailure.drawingFailed
            }

            context.setFillColor(colour)
            context.fill(area)
        }

        try fill(CGRect(x: 0, y: 0, width: width, height: height), withTheSignalOf: Self.lightOfTheMidGrey)
        let side = Self.sideOfTheCornerMark(inPictureOfWidth: width, height: height)
        for (place, light) in Self.lightOfThePatches.enumerated() {
            try fill(CGRect(x: place * side, y: 0, width: side, height: side), withTheSignalOf: light)
        }
    }

    private static func standardRGB(_ colour: Colour) -> CGColor {
        CGColor(srgbRed: colour.red, green: colour.green, blue: colour.blue, alpha: 1)
    }

    private static func sideOfTheCornerMark(inPictureOfWidth width: Int, height: Int) -> Int {
        min(width, height) / cornerMarkPartOfTheShorterSide
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

private struct PictureFormat {
    static var eightBitsInStandardRGB: Self {
        Self(
            pixelFormat: kCVPixelFormatType_32BGRA,
            bitsPerComponent: 8,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue,
            colourSpaceName: CGColorSpace.sRGB,
            colourAttachments: [:],
        )
    }

    static var eightBitsInHighDefinitionColours: Self {
        Self(
            pixelFormat: kCVPixelFormatType_32BGRA,
            bitsPerComponent: 8,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue,
            colourSpaceName: CGColorSpace.itur_709,
            colourAttachments: [
                kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
                kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_ITU_R_709_2,
                kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            ],
        )
    }

    static var halfFloatsInHybridLogGamma: Self {
        Self(
            pixelFormat: kCVPixelFormatType_64RGBAHalf,
            bitsPerComponent: 16,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder16Little.rawValue,
            colourSpaceName: CGColorSpace.itur_2100_HLG,
            colourAttachments: [
                kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_2020,
                kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_ITU_R_2100_HLG,
                kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_2020,
            ],
        )
    }

    let pixelFormat: OSType
    let bitsPerComponent: Int
    let bitmapInfo: UInt32
    let colourSpaceName: CFString
    let colourAttachments: [CFString: CFString]
}
