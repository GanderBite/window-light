import CoreGraphics
import SwiftUI

public struct SlotRow: View {
    private static let rowMinimumHeight: CGFloat = 44
    private static let thumbnailWidth: CGFloat = 64
    private static let thumbnailHeight: CGFloat = 40
    private static let thumbnailCornerRadius: CGFloat = 4
    private static let placeholderDash: [CGFloat] = [4, 3]
    private static let textMinimumWidth: CGFloat = 80

    private let slotName: String
    private let picture: CGImage?
    private let caption: String
    private let addTitle: String
    private let add: (() -> Void)?

    public init(slotName: String, picture: CGImage?, caption: String, addTitle: String, add: (() -> Void)?) {
        self.slotName = slotName
        self.picture = picture
        self.caption = caption
        self.addTitle = addTitle
        self.add = add
    }

    public var body: some View {
        HStack(spacing: 10) {
            thumbnail
            texts
            addButton
        }
        .padding(.vertical, 6)
        .frame(minHeight: Self.rowMinimumHeight)
    }

    private var thumbnail: some View {
        Group {
            if let picture {
                Image(decorative: picture, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius))
            } else {
                RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius)
                    .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: Self.placeholderDash))
                    .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
            }
        }
        .accessibilityHidden(true)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: slotName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(verbatim: caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(minWidth: Self.textMinimumWidth, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: slotName))
        .accessibilityValue(Text(verbatim: caption))
    }

    @ViewBuilder
    private var addButton: some View {
        if let add {
            Button(action: add) {
                Text(verbatim: addTitle)
            }
            .accessibilityLabel(Text(verbatim: addTitle))
        }
    }
}
