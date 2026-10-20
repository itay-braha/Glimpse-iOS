import SwiftUI

/// "Close it kindly": a short, editable note instead of silence. Offered now and then by
/// the server (never after a report, never twice in a chat). Sending closes the chat and
/// the other person gets the note as a private alert.
struct KindGoodbyeSheet: View {
    let name: String
    let trigger: GoodbyeTrigger
    /// The note went out (template, text, whether they edited it).
    let onSend: (GoodbyeTemplate, String, Bool) -> Void
    /// They closed it without sending (dismissed, kept chatting, or unmatched anyway).
    let onDecline: (GoodbyeAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var template: GoodbyeTemplate
    @State private var note: String
    @FocusState private var editing: Bool

    private static let limit = 280

    init(name: String, trigger: GoodbyeTrigger,
         onSend: @escaping (GoodbyeTemplate, String, Bool) -> Void,
         onDecline: @escaping (GoodbyeAction) -> Void) {
        self.name = name
        self.trigger = trigger
        self.onSend = onSend
        self.onDecline = onDecline
        let first = GoodbyeTemplate.choices(for: trigger)[0]
        _template = State(initialValue: first)
        _note = State(initialValue: first.text(to: name))
    }

    private var isUnmatching: Bool { trigger == .unmatchAfterTheirMessage }

    private var subtitle: String {
        switch trigger {
        case .vibeNoSpark:
            String(localized: "No spark on the Vibe Check? A few kind words beat silence.")
        case .stoppedReplying:
            String(localized: "It's been a few days. If you're not feeling it, a kind note is better than disappearing.")
        case .unmatchAfterTheirMessage:
            String(localized: "\(name) wrote last. Leave a kind note before you go?")
        }
    }

    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                templates
                editor
                Text("\(name) gets this as a private note, and the chat closes. No one else sees it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textTertiary)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.midnight)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(editing)
        .accessibilityIdentifier("goodbye.sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.wave.fill")
                .font(.title2)
                .foregroundStyle(Palette.onMint)
                .frame(width: 52, height: 52)
                .background(Palette.mint.gradient, in: .circle)
                .accessibilityHidden(true)
            Text("Close it kindly?")
                .font(.glimpseTitle)
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var templates: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GoodbyeTemplate.choices(for: trigger)) { option in
                    SelectableChip(title: option.title, isSelected: template == option) {
                        template = option
                        note = option.text(to: name)
                    }
                    .accessibilityIdentifier("goodbye.template.\(option.rawValue)")
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("Your note", text: $note, axis: .vertical)
                .lineLimit(4...8)
                .focused($editing)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .padding(16)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.mint.opacity(editing ? 0.6 : 0.15)))
                .onChange(of: note) { _, newValue in
                    if newValue.count > Self.limit { note = String(newValue.prefix(Self.limit)) }
                }
                .accessibilityIdentifier("goodbye.note")
            Text("\(note.count)/\(Self.limit)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Send and close the chat", systemImage: "paperplane.fill") {
                onSend(template, trimmed, trimmed != template.text(to: name))
                dismiss()
            }
            .buttonStyle(GlimpseButtonStyle(kind: .primary))
            .disabled(trimmed.isEmpty)
            .accessibilityIdentifier("goodbye.send")

            if isUnmatching {
                Button("Unmatch without a note") {
                    onDecline(.unmatchedWithoutNote)
                    dismiss()
                }
                .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                .accessibilityIdentifier("goodbye.skip")
                Button("Keep the chat") {
                    onDecline(.keptChatting)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 4)
            } else {
                Button("Keep chatting") {
                    onDecline(.keptChatting)
                    dismiss()
                }
                .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                Button("Not now") {
                    onDecline(.dismissed)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 4)
                .accessibilityIdentifier("goodbye.notNow")
            }
        }
    }
}
