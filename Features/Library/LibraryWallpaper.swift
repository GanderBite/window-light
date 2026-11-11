import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO

public struct LibraryWallpaper: Identifiable, Equatable {
    public let id: WallpaperID
    public let name: String
    public let pictureCount: Int
    public let previews: [CGImage]

    init(showing wallpaper: Wallpaper, withPreviews previews: [CGImage]) {
        id = wallpaper.id
        name = wallpaper.name.text
        pictureCount = wallpaper.filledSlotCount
        self.previews = previews
    }

    func renamed(as renamedWallpaper: Wallpaper) -> LibraryWallpaper {
        LibraryWallpaper(showing: renamedWallpaper, withPreviews: previews)
    }

    @concurrent
    static func decodedPreviews(of entries: [WallpaperInLibrary]) async -> [[CGImage]] {
        await withTaskGroup(of: (Int, [CGImage]).self) { group in
            for (position, entry) in entries.enumerated() {
                group.addTask {
                    (position, entry.picturePreviewsInDayOrder.compactMap(decodedImage(from:)))
                }
            }
            var previewsByPosition = [[CGImage]](repeating: [], count: entries.count)
            for await (position, previews) in group {
                previewsByPosition[position] = previews
            }
            return previewsByPosition
        }
    }

    private static func decodedImage(from previewBytes: Data) -> CGImage? {
        let decodeNow = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let source = CGImageSourceCreateWithData(previewBytes as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, decodeNow)
    }
}
