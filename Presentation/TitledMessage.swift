import SwiftUI

public struct TitledMessage: View {
    private let title: String
    private let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420)
    }
}
