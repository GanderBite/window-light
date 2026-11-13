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
        thumbnail: SlotRow.Thumbnail,
        add: (() -> Void)? = nil,
    ) -> SlotRow {
        SlotRow(slotName: name, thumbnail: thumbnail, caption: "Added today", addTitle: "Add picture", add: add)
    }

    @Test func rendersEachKindOfThumbnailAtTheSameHeightOfAtLeast44Points() throws {
        let filled = try #require(renderedSize(of: row(thumbnail: .picture(makePicture())), proposedWidth: 300))
        let borrowed = try #require(renderedSize(
            of: row(thumbnail: .borrowedPicture(makePicture())),
            proposedWidth: 300,
        ))
        let empty = try #require(renderedSize(of: row(thumbnail: .empty), proposedWidth: 300))
        #expect(filled == empty)
        #expect(borrowed == empty)
        #expect(empty.height >= 44)
    }

    @Test func staysInsideTheWidthItIsGivenWithABorrowedPicture() throws {
        let size = try #require(renderedSize(
            of: row(name: String(repeating: "N", count: 200), thumbnail: .borrowedPicture(makePicture()), add: {}),
            proposedWidth: 300,
        ))
        #expect(size.width <= 300)
        #expect(size.width > 0)
    }

    @Test func staysInsideTheWidthItIsGivenWithAVeryLongName() throws {
        let size = try #require(renderedSize(
            of: row(name: String(repeating: "N", count: 200), thumbnail: .picture(makePicture()), add: {}),
            proposedWidth: 300,
        ))
        #expect(size.width <= 300)
        #expect(size.width > 0)
    }

    @Test func rendersWithAnAddClosureAndWithoutOneNoWiderThanWithIt() throws {
        let withAdd = try #require(renderedSize(of: row(thumbnail: .empty, add: {}), proposedWidth: 300))
        let withoutAdd = try #require(renderedSize(of: row(thumbnail: .empty), proposedWidth: 300))
        #expect(withAdd.width > 0)
        #expect(withoutAdd.width <= withAdd.width)
    }

    private func pictureActions(destinationCount: Int) -> SlotRow.PictureActions {
        SlotRow.PictureActions(
            menuTitle: "Picture actions",
            moveTitle: "Move to",
            destinations: (0 ..< destinationCount).map { index in
                SlotRow.PictureActions.Destination(title: "Slot \(index + 1)", move: {})
            },
            removeTitle: "Remove picture",
            remove: {},
        )
    }

    private func rowWithPictureActions(
        thumbnail: SlotRow.Thumbnail,
        destinationCount: Int,
        add: (() -> Void)? = nil,
    ) -> SlotRow {
        SlotRow(
            slotName: "Morning",
            thumbnail: thumbnail,
            caption: "Added today",
            addTitle: "Add picture",
            add: add,
            pictureActions: pictureActions(destinationCount: destinationCount),
        )
    }

    @Test func rendersPictureActionsWithSevenDestinationsAtLeast44PointsHighInsideTheWidthForEveryThumbnail() throws {
        let thumbnails: [SlotRow.Thumbnail] = [
            .picture(makePicture()), .borrowedPicture(makePicture()), .empty,
        ]
        for thumbnail in thumbnails {
            let size = try #require(renderedSize(
                of: rowWithPictureActions(thumbnail: thumbnail, destinationCount: 7),
                proposedWidth: 300,
            ))
            #expect(size.height >= 44)
            #expect(size.width <= 300)
            #expect(size.width > 0)
        }
    }

    @Test func rendersPictureActionsWithoutDestinations() throws {
        let size = try #require(renderedSize(
            of: rowWithPictureActions(thumbnail: .picture(makePicture()), destinationCount: 0),
            proposedWidth: 300,
        ))
        #expect(size.height >= 44)
        #expect(size.width > 0)
    }

    @Test func rendersAnAddButtonTogetherWithPictureActions() throws {
        let size = try #require(renderedSize(
            of: rowWithPictureActions(thumbnail: .picture(makePicture()), destinationCount: 3, add: {}),
            proposedWidth: 300,
        ))
        #expect(size.height >= 44)
        #expect(size.width <= 300)
        #expect(size.width > 0)
    }
}
