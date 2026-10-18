import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showEditor = false
    @State private var showVerification = false
    @State private var legal: LegalDocument?
    @State private var confirmDelete = false
    @State private var deleteConfirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var quota: LikeQuota?
    @State private var showPaywall = false
    @State private var pausedUntil: Date?
    @AppStorage(PlaybackPreferences.clipSecondsKey) private var clipSeconds = PlaybackPreferences.defaultClipSeconds

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Button("Edit profile & discovery", systemImage: "slider.horizontal.3") { showEditor = true }
                    verificationRow
                }

                Section("Membership") {
                    if quota?.isPlus == true {
                        Label("You're a Glimpse+ member", systemImage: "sparkles")
                            .foregroundStyle(Palette.mint)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Get Glimpse+")
                                    if let quota {
                                        Text("\(quota.remaining) of \(quota.allowance) free likes left today")
                                            .font(.caption)
                                            .foregroundStyle(Palette.textSecondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                        }
                    }
                    NavigationLink {
                        GoldView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Glimpse Gold")
                                Text("Spotlight, clip insights, Travel mode, Rewind")
                                    .font(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "crown.fill").foregroundStyle(Palette.amber)
                        }
                    }
                    .accessibilityIdentifier("settings.gold")
                }

                Section {
                    if let pausedUntil, pausedUntil > .now {
                        Label("On a break until \(pausedUntil.formatted(date: .abbreviated, time: .omitted))", systemImage: "sun.horizon.fill")
                            .foregroundStyle(Palette.amber)
                        Button("Resume now", systemImage: "play.fill") { Task { await setPause(0) } }
                    } else {
                        Menu {
                            ForEach([3, 7, 14, 30], id: \.self) { days in
                                Button("\(days) days") { Task { await setPause(days) } }
                            }
                        } label: {
                            Label("Take a break", systemImage: "sun.horizon")
                        }
                    }
                } header: {
                    Text("Vacation mode")
                } footer: {
                    Text("While you're away you're hidden from discovery, your matches see you're away, nothing counts against you, and auto-release won't touch you.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Each clip plays for \(Int(clipSeconds)) seconds")
                        Slider(value: $clipSeconds, in: PlaybackPreferences.clipSecondsRange, step: 1) {
                            Text("Clip time")
                        } minimumValueLabel: {
                            Text("5s").font(.caption)
                        } maximumValueLabel: {
                            Text("15s").font(.caption)
                        }
                        .tint(Palette.mint)
                        .accessibilityValue("\(Int(clipSeconds)) seconds")
                        .accessibilityIdentifier("settings.clipSeconds")
                    }
                } header: {
                    Text("Playback")
                } footer: {
                    Text("Then the next clip starts. Longer clips show a +more button so you can watch the rest.")
                }

                Section {
                    Picker("Alert me about", selection: Binding(
                        get: { app.profile?.pushScope ?? .all },
                        set: { scope in Task { await app.setPushScope(scope) } }
                    )) {
                        ForEach(PushScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .accessibilityIdentifier("settings.pushScope")
                    if app.profile?.pushScope == .messages {
                        ForEach(AlertExtra.allCases) { extra in
                            Toggle("Also: \(extra.title)", isOn: Binding(
                                get: { app.profile?.pushExtras?.contains(extra) ?? false },
                                set: { on in
                                    var extras = (app.profile?.pushExtras ?? []).filter { $0 != extra }
                                    if on { extras.append(extra) }
                                    Task { await app.setPushExtras(extras) }
                                }
                            ))
                            .accessibilityIdentifier("settings.extra.\(extra.rawValue)")
                        }
                    }
                    Button("iPhone notification settings", systemImage: "bell.badge") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text((app.profile?.pushScope ?? .all).detail)
                }

                Section {
                    Toggle("Video calls after a great Vibe Check", isOn: Binding(
                        get: { app.profile?.videoCallsEnabled ?? false },
                        set: { on in Task { await app.setVideoCallsEnabled(on) } }
                    ))
                    .tint(Palette.mint)
                    .accessibilityIdentifier("settings.videoCalls")
                } header: {
                    Text("Video calls")
                } footer: {
                    Text("Off unless you turn it on. Then, only with someone you both felt good about in a Vibe Check, and only once you allow it in that chat (in a woman–man match, it's her choice). Calls last up to 15 minutes, can't be screenshotted or recorded, and either of you can block them at any time.")
                }

                Section {
                    Toggle("Help improve matching", isOn: Binding(
                        get: { app.profile?.consentAiTraining ?? false },
                        set: { on in
                            Task { await app.setDataConsent(aiTraining: on, sharing: app.profile?.consentDataSharing ?? false) }
                        }
                    ))
                    .accessibilityIdentifier("settings.consentTraining")
                    Toggle("Share anonymous trends", isOn: Binding(
                        get: { app.profile?.consentDataSharing ?? false },
                        set: { on in
                            Task { await app.setDataConsent(aiTraining: app.profile?.consentAiTraining ?? false, sharing: on) }
                        }
                    ))
                    .accessibilityIdentifier("settings.consentSharing")
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Both are off unless you turn them on. Matching models learn from your activity under a random code, never your messages, videos, name or exact location. Trends are only shared as totals for groups of 20 or more people.")
                }

                Section("About") {
                    ForEach(LegalDocument.allCases) { document in
                        Button(document.title, systemImage: "doc.text") { legal = document }
                    }
                }

                Section {
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task {
                            dismiss()
                            await app.signOut()
                        }
                    }
                    Button("Delete account", systemImage: "trash", role: .destructive) {
                        deleteConfirmation = ""
                        confirmDelete = true
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Deleting your account removes your profile, videos, matches and messages. This can't be undone.")
                }

                if let errorMessage {
                    Section { ErrorText(errorMessage) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isDeleting { ProgressView().controlSize(.large) }
            }
        }
        .task {
            quota = try? await app.backend.likeQuota()
            pausedUntil = try? await app.backend.accountState().pausedUntil
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            Task { quota = try? await app.backend.likeQuota() }
        }) {
            PaywallView(reason: .settings)
        }
        .sheet(isPresented: $showEditor) {
            if let profile = app.profile {
                EditProfileView(profile: profile)
            }
        }
        .sheet(isPresented: $showVerification) {
            VerificationView()
        }
        .sheet(item: $legal) { document in
            LegalDocumentView(document: document)
        }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            TextField("Type DELETE to confirm", text: $deleteConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(deleteConfirmation != "DELETE")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your profile, videos, matches and messages will be permanently removed.")
        }
    }

    @ViewBuilder
    private var verificationRow: some View {
        switch app.profile?.verificationStatus {
        case "verified":
            Label("Verified profile", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Palette.mint)
        case "pending":
            Label("Verification under review", systemImage: "hourglass")
                .foregroundStyle(Palette.textSecondary)
        default:
            Button("Get verified", systemImage: "checkmark.seal") { showVerification = true }
        }
    }

    private func setPause(_ days: Int) async {
        do {
            pausedUntil = try await app.backend.setPause(days: days)
            app.track(days > 0 ? "pause_started" : "pause_ended", ["days": "\(days)"])
            app.matchesDidChange()
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    private func deleteAccount() async {
        guard deleteConfirmation == "DELETE" else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await app.deleteAccount()
            dismiss()
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
