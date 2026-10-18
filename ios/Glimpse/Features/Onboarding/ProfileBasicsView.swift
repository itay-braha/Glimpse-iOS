import SwiftUI

struct ProfileBasicsView: View {
    @Environment(AppModel.self) private var app

    @State private var name = ""
    @State private var birthdate = Calendar.current.date(byAdding: .year, value: -24, to: .now) ?? .now
    @State private var gender: Gender?
    @State private var interestedIn: Set<Gender> = []
    @State private var city = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var latestAllowedBirthdate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && gender != nil && !interestedIn.isEmpty
            && birthdate <= latestAllowedBirthdate
    }

    var body: some View {
        OnboardingScaffold(
            title: "The basics",
            subtitle: "Just enough for the right people to find you. Your videos do the rest."
        ) {
            FieldLabel("First name")
            TextField("Your first name", text: $name)
                .textContentType(.givenName)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))

            FieldLabel("Birthday")
            DatePicker("Birthday", selection: $birthdate, in: ...latestAllowedBirthdate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))

            FieldLabel("I am")
            ChipRow {
                ForEach(Gender.allCases) { option in
                    SelectableChip(title: option.label, isSelected: gender == option) {
                        gender = option
                    }
                }
            }

            FieldLabel("Show me")
            ChipRow {
                ForEach(Gender.allCases) { option in
                    SelectableChip(title: option.pluralLabel, isSelected: interestedIn.contains(option)) {
                        if interestedIn.contains(option) {
                            interestedIn.remove(option)
                        } else {
                            interestedIn.insert(option)
                        }
                    }
                }
            }

            FieldLabel("City")
            TextField("Where you're based", text: $city)
                .textContentType(.addressCity)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))

            FieldLabel("One line about you")
            TextField("Optional", text: $bio, axis: .vertical)
                .lineLimit(2...4)
                .padding(16)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))
                .onChange(of: bio) { _, newValue in
                    if newValue.count > 300 { bio = String(newValue.prefix(300)) }
                }

            if let errorMessage {
                ErrorText(errorMessage)
            }
        } footer: {
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView().tint(Palette.onMint)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.glimpse)
            .disabled(!isValid || isSaving)
        }
    }

    private func save() async {
        guard let gender else { return }
        isSaving = true
        defer { isSaving = false }
        let draft = ProfileDraft(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthdate: birthdate,
            gender: gender,
            interestedIn: interestedIn,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            let profile = try await app.backend.createProfile(draft)
            app.profileCreated(profile)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.glimpseCaption)
            .textCase(.uppercase)
            .foregroundStyle(Palette.textTertiary)
            .padding(.top, 6)
    }
}

/// Wraps chips onto multiple lines.
struct ChipRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: 8) {
            content
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.indices.isEmpty, row.width + spacing + size.width > maxWidth {
                let nextY = row.y + row.height + spacing
                rows.append(Row(y: nextY))
                row = rows[rows.count - 1]
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
