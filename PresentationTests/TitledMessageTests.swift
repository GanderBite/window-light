import Presentation
import SwiftUI
import Testing

@MainActor
private func renderedSize(
    of view: some View,
    proposedWidth: CGFloat? = nil,
) -> CGSize? {
    let renderer = ImageRenderer(content: view)
    if let proposedWidth {
        renderer.proposedSize = ProposedViewSize(width: proposedWidth, height: nil)
    }
    return renderer.nsImage?.size
}

@MainActor
struct TitledMessageTests {
    @Test func rendersInTheLightAppearance() throws {
        let view = TitledMessage(title: "Window Light", message: "Wallpapers that follow the day")
            .environment(\.colorScheme, .light)
        let size = try #require(renderedSize(of: view))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func rendersInTheDarkAppearance() throws {
        let view = TitledMessage(title: "Window Light", message: "Wallpapers that follow the day")
            .environment(\.colorScheme, .dark)
        let size = try #require(renderedSize(of: view))
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func wrapsALongMessageWithinAComfortableWidth() throws {
        let longMessage = String(repeating: "word ", count: 120)
        let long = try #require(renderedSize(
            of: TitledMessage(title: "Title", message: longMessage),
            proposedWidth: 500,
        ))
        let short = try #require(renderedSize(
            of: TitledMessage(title: "Title", message: "Word"),
            proposedWidth: 500,
        ))
        #expect(long.height > short.height)
        #expect(long.width <= 500)
    }
}
