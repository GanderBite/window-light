import CoreGraphics
import Presentation
import SwiftUI
import Testing

@MainActor
private func renderedSize(of view: some View, proposedWidth: CGFloat? = nil) -> CGSize? {
    let renderer = ImageRenderer(content: view)
    if let proposedWidth {
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
    }
    return renderer.nsImage?.size
}

private func makePicture() -> CGImage {
    let context = CGContext(
        data: nil,
        width: 60,
        height: 60,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )
    guard let context else {
        preconditionFailure("A test picture needs a drawing context")
    }

    context.setFillColor(CGColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
    guard let picture = context.makeImage() else {
        preconditionFailure("A test picture needs an image")
    }

    return picture
}

@MainActor
struct SlotRowTests {
    private func row(
        name: String = "Morning",
        picture: CGImage?,
        add: (() -> Void)? = nil,
    ) -> SlotRow {
        SlotRow(slotName: name, picture: picture, caption: "Added today", addTitle: "Add picture", add: add)
    }

    @Test func rendersWithAndWithoutAPictureAtTheSameHeightOfAtLeast44Points() throws {
        let filled = try #require(renderedSize(of: row(picture: makePicture()), proposedWidth: 300))
        let empty = try #require(renderedSize(of: row(picture: nil), proposedWidth: 300))
        #expect(filled.height == empty.height)
        #expect(empty.height >= 44)
    }

    @Test func staysInsideTheWidthItIsGivenWithAVeryLongName() throws {
        let size = try #require(renderedSize(
            of: row(name: String(repeating: "N", count: 200), picture: makePicture(), add: {}),
            proposedWidth: 300,
        ))
        #expect(size.width <= 300)
        #expect(size.width > 0)
    }

    @Test func rendersWithAnAddClosureAndWithoutOneNoWiderThanWithIt() throws {
        let withAdd = try #require(renderedSize(of: row(picture: nil, add: {}), proposedWidth: 300))
        let withoutAdd = try #require(renderedSize(of: row(picture: nil), proposedWidth: 300))
        #expect(withAdd.width > 0)
        #expect(withoutAdd.width <= withAdd.width)
    }
}
