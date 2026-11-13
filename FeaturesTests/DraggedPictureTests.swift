import Domain
@testable import Features
import Foundation
import Testing

struct DraggedPictureTests {
    @Test(arguments: Slot.allCases)
    func namesTheSameSlotAndWallpaperAfterItWasEncodedAndDecoded(slot: Slot) throws {
        let dragged = DraggedPicture(slot: slot, wallpaper: WallpaperID(UUID()))
        let encoded = try JSONEncoder().encode(dragged)
        let decoded = try JSONDecoder().decode(DraggedPicture.self, from: encoded)
        #expect(decoded == dragged)
    }
}
