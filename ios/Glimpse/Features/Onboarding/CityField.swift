import SwiftUI

/// Pick a city from Apple Maps suggestions or from where you are now. Free text is
/// never saved, so "TLV", "tel aviv" and "Tel-Aviv" all become the same city.
struct CityField: View {
    @Binding var city: String
    /// Called with the phone's approximate position after "Use my current location".
    var onLocated: (LocationService.Coordinate) -> Void = { _ in }

    @State private var search = CitySearch()
    @State private var text = ""
    @State private var isLocating = false
    @State private var note: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if city.isEmpty {
                searchField
                if !search.suggestions.isEmpty {
                    suggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if text.trimmingCharacters(in: .whitespaces).count >= 2 && !search.isSearching {
                    Text("No city by that name. Try another spelling.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                }
                locateButton
            } else {
                chosenCity
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if let note {
                Label(LocalizedStringKey(note), systemImage: "location.slash")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.snappy, value: search.suggestions)
        .animation(.snappy, value: city)
        .onChange(of: text) { _, newValue in search.update(newValue) }
        .sensoryFeedback(.selection, trigger: city)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
            TextField("Search for your city", text: $text)
                .textContentType(.addressCity)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .accessibilityIdentifier("city.search")
            if search.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(focused ? Palette.mint.opacity(0.6) : Palette.stroke, lineWidth: focused ? 1.5 : 1)
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(search.suggestions) { suggestion in
                Button {
                    choose(suggestion.title)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.mint)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Palette.textPrimary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("city.suggestion")

                if suggestion != search.suggestions.last {
                    Divider().overlay(Palette.stroke).padding(.leading, 48)
                }
            }
        }
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.stroke))
    }

    private var locateButton: some View {
        Button {
            Task { await locate() }
        } label: {
            HStack(spacing: 8) {
                if isLocating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Palette.mint)
                    Text("Finding you…")
                } else {
                    Image(systemName: "location.fill")
                    Text("Use my current location")
                }
            }
            .font(.glimpseHeadline)
            .foregroundStyle(Palette.mint)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Palette.mint.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(isLocating)
        .accessibilityIdentifier("city.locate")
    }

    private var chosenCity: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(Palette.mint)
                .accessibilityHidden(true)
            Text(city)
                .font(.glimpseHeadline)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
            Button("Change city", systemImage: "xmark.circle.fill") {
                city = ""
                text = ""
                note = nil
                focused = true
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Palette.mint.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.mint.opacity(0.4)))
    }

    private func choose(_ name: String) {
        city = name
        text = ""
        note = nil
        focused = false
        search.clear()
    }

    private func locate() async {
        isLocating = true
        note = nil
        defer { isLocating = false }
        guard let spot = await LocationService.approximateCoordinate(timeout: .seconds(10)) else {
            note = "We couldn't get your location. Turn on Location for Glimpse in Settings, or search for your city."
            return
        }
        onLocated(spot)
        if let name = await LocationService.cityName(at: spot) {
            choose(name)
        } else {
            note = "We found you, but not your city's name. Search for it instead."
        }
    }
}

/// Edit Profile's city row opens this.
struct CityPickerScreen: View {
    @Binding var city: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            CityField(city: $city)
                .padding(20)
        }
        .background(Palette.midnight)
        .navigationTitle("City")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: city) { _, newValue in
            if !newValue.isEmpty { dismiss() }
        }
    }
}
