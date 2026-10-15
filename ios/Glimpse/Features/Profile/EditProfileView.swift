import SwiftUI

struct EditProfileView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bio: String
    @State private var city: String
    @State private var interestedIn: Set<Gender>
    @State private var ageMin: Int
    @State private var ageMax: Int
    @State private var maxDistanceKm: Double
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        // One-time seeds: the editor owns its draft until Save.
        _name = State(initialValue: profile.displayName)
        _bio = State(initialValue: profile.bio ?? "")
        _city = State(initialValue: profile.city ?? "")
        _interestedIn = State(initialValue: Set(profile.interestedIn))
        _ageMin = State(initialValue: profile.ageMin)
        _ageMax = State(initialValue: profile.ageMax)
        _maxDistanceKm = State(initialValue: Double(profile.maxDistanceKm ?? 50))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    TextField("First name", text: $name)
                    TextField("City", text: $city)
                    TextField("One line about you", text: $bio, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Show me") {
                    ForEach(Gender.allCases) { gender in
                        Toggle(gender.pluralLabel, isOn: Binding(
                            get: { interestedIn.contains(gender) },
                            set: { isOn in
                                if isOn { interestedIn.insert(gender) } else { interestedIn.remove(gender) }
                            }
                        ))
                    }
                }

                Section {
                    Slider(value: $maxDistanceKm, in: 5...200, step: 5) {
                        Text("Maximum distance")
                    }
                    .accessibilityValue("\(Int(maxDistanceKm)) kilometres")
                } header: {
                    Text("Maximum distance: \(Int(maxDistanceKm)) km")
                } footer: {
                    Text("Distances are approximate. Your exact location is never shared.")
                }

                Section("Age range") {
                    Stepper("From \(ageMin)", value: $ageMin, in: 18...ageMax)
                    Stepper("To \(ageMax)", value: $ageMax, in: ageMin...99)
                }

                if let errorMessage {
                    Section { ErrorText(errorMessage) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || interestedIn.isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let update = ProfileUpdate(
            displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.isEmpty ? nil : bio,
            city: city.isEmpty ? nil : city,
            interestedIn: Gender.allCases.filter { interestedIn.contains($0) },
            ageMin: ageMin,
            ageMax: ageMax,
            maxDistanceKm: Int(maxDistanceKm)
        )
        do {
            try await app.backend.updateProfile(update)
            await app.refreshProfile()
            dismiss()
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
