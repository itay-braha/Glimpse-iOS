import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks, id: \.self) { block in
                        if block.hasPrefix("## ") {
                            Text(block.dropFirst(3))
                                .font(.glimpseHeadline)
                                .padding(.top, 8)
                                .accessibilityAddTraits(.isHeader)
                        } else {
                            Text(markdown(block))
                                .font(.glimpseBody)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.midnight)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Splits the text into headings and paragraphs (paragraphs are separated by blank lines).
    private var blocks: [String] {
        document.body.components(separatedBy: "\n\n").flatMap { chunk -> [String] in
            let lines = chunk
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard let first = lines.first else { return [] }
            if first.hasPrefix("## ") {
                let rest = lines.dropFirst().joined(separator: "\n")
                return rest.isEmpty ? [first] : [first, rest]
            }
            return [lines.joined(separator: "\n")]
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
