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

@MainActor
struct ImportSummaryListTests {
    private func list(notes: [String]) -> ImportSummaryList {
        ImportSummaryList(headline: "3 pictures added", notes: notes)
    }

    @Test func rendersAHeadlineWithoutNotes() throws {
        let size = try #require(renderedSize(of: list(notes: []), proposedWidth: 300))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func isTallerWithThreeNotesThanWithOne() throws {
        let one = try #require(renderedSize(of: list(notes: ["a.jpg was skipped"]), proposedWidth: 300))
        let three = try #require(renderedSize(
            of: list(notes: ["a.jpg was skipped", "b.jpg was skipped", "c.jpg was skipped"]),
            proposedWidth: 300,
        ))
        #expect(three.height > one.height)
    }

    @Test func growsTallerNotWiderForANoteLongerThanTheWidth() throws {
        let short = try #require(renderedSize(of: list(notes: ["a.jpg was skipped"]), proposedWidth: 200))
        let long = try #require(renderedSize(
            of: list(notes: [String(repeating: "word ", count: 60)]),
            proposedWidth: 200,
        ))
        #expect(long.width <= 200)
        #expect(long.height > short.height)
    }
}
