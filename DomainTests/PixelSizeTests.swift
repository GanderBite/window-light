@testable import Domain
import Testing

struct PixelSizeTests {
    @Test func aPixelSizeKeepsItsWidthAndHeight() throws {
        let size = try PixelSize(width: 4000, height: 3000)
        #expect(size.width == 4000)
        #expect(size.height == 3000)
    }

    @Test(arguments: [(0, 100), (100, 0), (-1, 100), (100, -5), (0, 0)])
    func aWidthOrHeightBelowOneIsRefused(width: Int, height: Int) {
        #expect(throws: PixelSizeError.notPositive(width: width, height: height)) {
            try PixelSize(width: width, height: height)
        }
    }

    @Test(arguments: [(1920, 1080), (4000, 3000)])
    func largeEnoughPicturesMayNotLookBlurry(width: Int, height: Int) throws {
        #expect(try !PixelSize(width: width, height: height).mayLookBlurryOnTheDesktop)
    }

    @Test(arguments: [(1919, 1080), (1920, 1079), (1080, 1920), (800, 800)])
    func smallPicturesMayLookBlurry(width: Int, height: Int) throws {
        #expect(try PixelSize(width: width, height: height).mayLookBlurryOnTheDesktop)
    }
}
