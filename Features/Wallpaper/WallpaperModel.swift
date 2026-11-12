import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO
import Observation

@MainActor
@Observable
public final class WallpaperModel {
    public enum Phase: Equatable { case nothingOpen, opening, open, gone, unavailable }

    public struct SlotState: Identifiable, Equatable {
        public let slot: Slot
        public let preview: CGImage?
        public let isFilled: Bool
        public let canTakeAFile: Bool

        public var id: Slot {
            slot
        }
    }

    private let openWallpaper: OpenWallpaper
    private var latestRequest = 0

    public private(set) var phase: Phase = .nothingOpen
    public private(set) var wallpaperID: WallpaperID?
    public private(set) var name = ""
    public private(set) var slots: [SlotState] = []
    public private(set) var hasEmptySlot = false

    public init(openWallpaper: OpenWallpaper) {
        self.openWallpaper = openWallpaper
    }

    public func show(_ wallpaper: WallpaperID?) async {
        let request = startRequest()
        wallpaperID = wallpaper
        clearWallpaper()
        guard let wallpaper else {
            phase = .nothingOpen
            return
        }

        phase = .opening
        await open(wallpaper, asRequest: request)
    }

    public func reload() async {
        guard let wallpaperID else { return }

        await open(wallpaperID, asRequest: startRequest())
    }

    private func startRequest() -> Int {
        latestRequest += 1
        return latestRequest
    }

    private func open(_ wallpaper: WallpaperID, asRequest request: Int) async {
        do throws(OpenWallpaperError) {
            let opened = try await openWallpaper.execute(wallpaper)
            let previews = await Self.decodedPreviewsInDayOrder(of: opened)
            guard request == latestRequest else { return }

            hold(opened.wallpaper, withPreviews: previews)
            phase = .open
        } catch {
            guard request == latestRequest else { return }

            clearWallpaper()
            switch error {
            case .wallpaperGone: phase = .gone
            case .unavailable: phase = .unavailable
            }
        }
    }

    private func hold(_ wallpaper: Wallpaper, withPreviews previews: [CGImage?]) {
        name = wallpaper.name.text
        slots = zip(Slot.allCases, previews).map { slot, preview in
            SlotState(
                slot: slot,
                preview: preview,
                isFilled: wallpaper.picture(in: slot) != nil,
                canTakeAFile: wallpaper.canTakeAFile(into: slot),
            )
        }
        hasEmptySlot = !wallpaper.emptySlots.isEmpty
    }

    private func clearWallpaper() {
        name = ""
        slots = []
        hasEmptySlot = false
    }

    @concurrent
    private static func decodedPreviewsInDayOrder(of entry: WallpaperInLibrary) async -> [CGImage?] {
        Slot.allCases.map { slot in
            entry.picturePreview(in: slot).flatMap(decodedImage(from:))
        }
    }

    private nonisolated static func decodedImage(from previewBytes: Data) -> CGImage? {
        let decodeNow = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithData(previewBytes as CFData, nil) else { return nil }

        return CGImageSourceCreateImageAtIndex(source, 0, decodeNow)
    }
}
