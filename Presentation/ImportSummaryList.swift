import SwiftUI

public struct ImportSummaryList: View {
    private static let noteSpacing: CGFloat = 4

    private let headline: String
    private let notes: [String]

    public init(headline: String, notes: [String]) {
        self.headline = headline
        self.notes = notes
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.noteSpacing) {
                Text(verbatim: headline)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(notes.indices, id: \.self) { index in
                    Text(verbatim: notes[index])
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
