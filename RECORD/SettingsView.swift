//
//  SettingsView.swift
//  RECORD
//
//  Created by Amir Rashidov on 01.08.2026.
//
//  Connect rows rather than a form: each service is a row showing its state,
//  and tapping opens a sheet to change it. Today the sheet holds a text field.
//  When Spotify OAuth lands, only the sheet's contents change — the row, the
//  state, and the save path stay as they are.
//

import SwiftUI
import Supabase

// MARK: - Which service

enum MusicService: String, Identifiable {
    case spotify, appleMusic

    var id: String { rawValue }

    var name: String {
        switch self {
        case .spotify:    "Spotify"
        case .appleMusic: "Apple Music"
        }
    }

    var logo: String {
        switch self {
        case .spotify:    "spotify-logo-white"
        case .appleMusic: "apple-music-logo-white"
        }
    }

    var hint: String {
        switch self {
        case .spotify:
            "In Spotify: your profile → ⋯ → Share → Copy link to profile."
        case .appleMusic:
            "In Apple Music: Listen Now → your photo → Edit → Share Profile."
        }
    }
}

// MARK: - Settings

struct SettingsView: View {

    @State private var spotifyProfile = ""
    @State private var appleMusicProfile = ""


    @State private var editing: MusicService?
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.recordBG.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // LISTENING
                    sectionHeader("LISTENING")

                    Text("Where friends can find you.")
                        .font(.sans(12.5))
                        .foregroundStyle(Color.recordSecondary)
                        .padding(.bottom, 14)

                    connectRow(.spotify, value: spotifyProfile)
                    divider
                    connectRow(.appleMusic, value: appleMusicProfile)

                    // ACCOUNT
                    sectionHeader("ACCOUNT")

                    Button {
                        Task { await signOut() }
                    } label: {
                        Text("Sign Out")
                            .font(.sans(14))
                            .foregroundStyle(Color.recordText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.recordCardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text(deleting ? "Deleting…" : "Delete Account")
                            .font(.sans(12.5))
                            .foregroundStyle(Color.recordDanger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    .padding(.top, 4)
                }
                .padding(24)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLinks() }
        .sheet(item: $editing) { service in
            ConnectSheet(
                service: service,
                current: service == .spotify ? spotifyProfile : appleMusicProfile,
                onSave: { newValue in
                    if service == .spotify { spotifyProfile = newValue }
                    else                   { appleMusicProfile = newValue }

                    // Chain onto any save still in flight so two rapid saves
                    // can't interleave and overwrite each other.
                    let previous = saveTask
                    saveTask = Task {
                        await previous?.value
                        await saveLink(service, value: newValue)
                    }
                }
            )
            .presentationDetents([.height(340), .large])
            .presentationBackground(Color.recordBG)
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes your records, streak, and profile. This can't be undone.")
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Rows

    private func connectRow(_ service: MusicService, value: String) -> some View {
        let connected = !value.isEmpty

        return Button {
            editing = service
        } label: {
            HStack(spacing: 12) {
                Image(service.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.sans(14))
                        .foregroundStyle(Color.recordText)
                    Text(connected ? "Connected" : "Not connected")
                        .font(.sans(11.5))
                        .foregroundStyle(connected ? Color.recordAccentMid : Color.recordTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.recordDot)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.recordSeparator)
            .frame(height: 1)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.sans(11, .medium))
                .tracking(1)
                .foregroundStyle(Color.recordTertiary)
            Rectangle()
                .fill(Color.recordRule)
                .frame(height: 1)
        }
        .padding(.top, 30)
        .padding(.bottom, 6)
    }

    // MARK: - Data

    private func loadLinks() async {
        do {
            let userID = try await supabase.auth.session.user.id
            let row: LinksRow = try await supabase
                .from("profiles")
                .select("apple_music_profile, spotify_profile")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            appleMusicProfile = row.apple_music_profile ?? ""
            spotifyProfile = row.spotify_profile ?? ""
        } catch {
            print("Load links failed: \(error)")
            errorMessage = "Couldn't load your settings. Pull to try again."
        }
    }

    private func saveLink(_ service: MusicService, value: String) async {
        let stored: String? = value.isEmpty ? nil : value

        do {
            let userID = try await supabase.auth.session.user.id

            struct ProfileLinks: Encodable {
                let id: String
                let apple_music_profile: String?
                let spotify_profile: String?
            }

            try await supabase
                .from("profiles")
                .upsert(ProfileLinks(
                    id: userID.uuidString.lowercased(),
                    apple_music_profile: service == .appleMusic ? stored : (appleMusicProfile.isEmpty ? nil : appleMusicProfile),
                    spotify_profile:     service == .spotify    ? stored : (spotifyProfile.isEmpty ? nil : spotifyProfile)
                ))
                .execute()
        } catch {
            print("Save link failed: \(error)")
            errorMessage = "Couldn't save that link. Check your connection and try again."
        }
    }

    private func signOut() async {
        do { try await supabase.auth.signOut() }
        catch {
            print("Sign out failed: \(error)")
            errorMessage = "Couldn't sign out. Try again."
        }
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await supabase.functions.invoke("delete-account")

            do { try await supabase.auth.signOut() }
            catch { print("Sign out after delete failed (session will expire): \(error)") }
        } catch {
            print("Delete account failed: \(error)")
            errorMessage = "Couldn't delete your account. Try again, or contact support if this keeps happening."
        }
    }
}

// MARK: - Connect sheet
//
// When OAuth arrives, this is the only thing that changes: the field becomes a
// "Connect with Spotify" button and the callback writes the same value.

struct ConnectSheet: View {
    let service: MusicService
    let current: String
    let onSave: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(service: MusicService, current: String, onSave: @escaping (String) -> Void) {
        self.service = service
        self.current = current
        self.onSave = onSave
        _text = State(initialValue: current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 10) {
                Image(service.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(service.name)
                    .font(.display(20, .bold))
                    .foregroundStyle(Color.recordText)
                Spacer()
            }
            .padding(.top, 26)

            Text(service.hint)
                .font(.sans(12.5))
                .foregroundStyle(Color.recordSecondary)
                .padding(.top, 8)

            TextField("", text: $text,
                      prompt: Text("paste your profile link")
                        .foregroundColor(.recordTertiary))
                .font(.sans(14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .foregroundStyle(Color.recordText)
                .padding()
                .background(Color.recordAvatarFill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.recordCardBorder, lineWidth: 1)
                )
                .padding(.top, 18)

            HStack(spacing: 10) {
                if !current.isEmpty {
                    Button {
                        onSave("")
                        dismiss()
                    } label: {
                        Text("Disconnect")
                            .font(.sans(14, .medium))
                            .foregroundStyle(Color.recordDestructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                Capsule().stroke(Color.recordDestructive.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onSave(text.trimmingCharacters(in: .whitespaces))
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.sans(14, .bold))
                        .foregroundStyle(Color.recordInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.recordAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct LinksRow: Decodable {
    let apple_music_profile: String?
    let spotify_profile: String?
}
