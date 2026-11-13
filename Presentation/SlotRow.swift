import CoreGraphics
import SwiftUI

public struct SlotRow: View {
    public enum Thumbnail {
        case picture(CGImage)
        case borrowedPicture(CGImage)
        case empty
    }

    private static let rowMinimumHeight: CGFloat = 44
    private static let thumbnailWidth: CGFloat = 64
    private static let thumbnailHeight: CGFloat = 40
    private static let thumbnailCornerRadius: CGFloat = 4
    private static let placeholderDash: [CGFloat] = [4, 3]
    private static let textMinimumWidth: CGFloat = 80
    private static let borrowedPictureOpacity: Double = 0.5

    private let slotName: String
    private let thumbnail: Thumbnail
    private let caption: String
    private let addTitle: String
    private let add: (() -> Void)?

    public init(slotName: String, thumbnail: Thumbnail, caption: String, addTitle: String, add: (() -> Void)?) {
        self.slotName = slotName
        self.thumbnail = thumbnail
        self.caption = caption
        self.addTitle = addTitle
        self.add = add
    }

    public var body: some View {
        HStack(spacing: 10) {
            thumbnailView
            texts
            addButton
        }
        .padding(.vertical, 6)
        .frame(minHeight: Self.rowMinimumHeight)
    }

    private var thumbnailView: some View {
        Group {
            switch thumbnail {
            case let .picture(picture):
                filledFrame(of: picture)
            case let .borrowedPicture(picture):
                filledFrame(of: picture)
                    .opacity(Self.borrowedPictureOpacity)
                    .overlay { dashedBorder }
            case .empty:
                dashedBorder
            }
        }
        .accessibilityHidden(true)
    }

    private func filledFrame(of picture: CGImage) -> some View {
        Image(decorative: picture, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius))
    }

    private var dashedBorder: some View {
        RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius)
            .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: Self.placeholderDash))
            .frame(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
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
