import Domain
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DraggedPicture: Equatable {
    let slot: Slot
    let wallpaper: WallpaperID
}

extension DraggedPicture: Transferable {
    private static let contentType = UTType(exportedAs: "com.ganderbite.WindowLight.dragged-picture")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: contentType)
    }
}

extension DraggedPicture: Codable {
    private enum CodingKeys: String, CodingKey {
        case slot, wallpaper
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slotName = try container.decode(String.self, forKey: .slot)
        guard let slot = Slot.allCases.first(where: { $0.nameWhileDragged == slotName }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .slot,
                in: container,
                debugDescription: "No slot is named \(slotName)",
            )
        }

        self.slot = slot
        wallpaper = try WallpaperID(container.decode(UUID.self, forKey: .wallpaper))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slot.nameWhileDragged, forKey: .slot)
        try container.encode(wallpaper.value, forKey: .wallpaper)
    }
}

private extension Slot {
    var nameWhileDragged: String {
        switch self {
        case .dawn: "dawn"
        case .sunrise: "sunrise"
        case .morning: "morning"
        case .midday: "midday"
        case .afternoon: "afternoon"
        case .sunset: "sunset"
        case .dusk: "dusk"
        case .night: "night"
        }
    }
}

enum SlotRowDrop: Transferable {
    case picture(DraggedPicture)
    case file(URL)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(importing: { (picture: DraggedPicture) in Self.picture(picture) })
        ProxyRepresentation(importing: { (file: URL) in Self.file(file) })
    }

    var picture: DraggedPicture? {
        guard case let .picture(picture) = self else { return nil }

        return picture
    }

    var file: URL? {
        guard case let .file(file) = self else { return nil }

        return file
    }
}

struct DraggingThePicture: ViewModifier {
    private static let previewWidth: CGFloat = 120

    let picture: DraggedPicture?
    let preview: CGImage?

    func body(content: Content) -> some View {
        if let picture, let preview {
            content.draggable(picture) {
                Image(decorative: preview, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.previewWidth)
            }
        } else if let picture {
            content.draggable(picture)
        } else {
            content
        }
    }
}
