@testable import Domain
import Testing

struct PictureOriginTests {
    @Test func anImportedPictureIsReal() {
        #expect(PictureOrigin.imported.isReal)
    }

    @Test func aPictureMadeWithAIIsNotReal() {
        #expect(!PictureOrigin.madeWithAI.isReal)
    }
}
