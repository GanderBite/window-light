import CoreGraphics
import SwiftUI

public struct WallpaperRow: View {
    private static let rowMinimumHeight: CGFloat = 44
    private static let thumbnailSide: CGFloat = 32
    private static let thumbnailSpacing: CGFloat = 2
    private static let thumbnailCornerRadius: CGFloat = 4
    private static let textMinimumWidth: CGFloat = 80

    private let name: String
    private let pictures: [CGImage]
    private let caption: String

    public init(name: String, pictures: [CGImage], caption: String) {
        self.name = name
        self.pictures = pictures
        self.caption = caption
    }

    public var body: some View {
        HStack(spacing: 10) {
            thumbnails
            texts
        }
        .padding(.vertical, 6)
        .frame(minHeight: Self.rowMinimumHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: caption))
    }

    private var thumbnails: some View {
        HStack(spacing: Self.thumbnailSpacing) {
            ForEach(pictures.indices, id: \.self) { index in
                Image(decorative: pictures[index], scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: Self.thumbnailSide)
                    .frame(height: Self.thumbnailSide)
                    .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius))
            }
        }
        .accessibilityHidden(true)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name)
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
    }
}
