import SwiftUI

/// Keeps a text field's purpose visible after its placeholder disappears.
/// The original field and its binding are supplied unchanged by the caller.
struct StudioLabeledTextField<Input: View>: View {
    let title: String
    private let input: Input

    init(_ title: String, @ViewBuilder input: () -> Input) {
        self.title = title
        self.input = input()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 30, alignment: .topLeading)
                .accessibilityHidden(true)
            input
                .accessibilityLabel(Text(title))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func studioFieldLabel(_ title: String) -> some View {
        StudioLabeledTextField(title) { self }
    }
}
