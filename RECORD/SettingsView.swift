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

import AuthenticationServices
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
}

// MARK: - Settings

struct SettingsView: View {

    @State private var spotifyProfile = ""
    @State private var appleMusicProfile = ""
    @State private var spotifyConnected = false

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

                    connectRow(.spotify, connected: spotifyConnected,
                               detail: spotifyConnected ? spotifyProfile : nil)
                    divider
                    connectRow(.appleMusic, connected: !appleMusicProfile.isEmpty)

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
                current: appleMusicProfile,
                spotifyConnected: spotifyConnected,
                onSaveAppleMusic: { newValue in
                    appleMusicProfile = newValue

                    // Chain onto any save still in flight so two rapid saves
                    // can't interleave and overwrite each other.
                    let previous = saveTask
                    saveTask = Task {
                        await previous?.value
                        await saveAppleMusicLink(newValue)
                    }
                },
                onSpotifyConnected: { profileURL in
                    spotifyConnected = true
                    spotifyProfile = profileURL ?? ""
                },
                onSpotifyDisconnected: {
                    spotifyConnected = false
                    spotifyProfile = ""
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

    private func connectRow(_ service: MusicService, connected: Bool, detail: String? = nil) -> some View {
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
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.sans(10.5))
                            .foregroundStyle(Color.recordTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
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
                .select("apple_music_profile, spotify_profile, spotify_connected")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            appleMusicProfile = row.apple_music_profile ?? ""
            spotifyProfile = row.spotify_profile ?? ""
            spotifyConnected = row.spotify_connected
        } catch {
            print("Load links failed: \(error)")
            errorMessage = "Couldn't load your settings. Pull to try again."
        }
    }

    /// Spotify is written directly by the spotify-connect / spotify-disconnect
    /// edge functions, since that's where the OAuth tokens live — this is
    /// Apple Music only.
    private func saveAppleMusicLink(_ value: String) async {
        let stored: String? = value.isEmpty ? nil : value

        do {
            let userID = try await supabase.auth.session.user.id
            try await supabase
                .from("profiles")
                .update(["apple_music_profile": stored])
                .eq("id", value: userID)
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
// Apple Music keeps the original paste-a-link flow. Spotify is real OAuth:
// the sheet becomes a single Connect/Disconnect button, and the callback
// updates local state only — the edge functions already wrote the profile
// row themselves.

struct ConnectSheet: View {
    let service: MusicService
    let current: String              // Apple Music profile URL only
    let spotifyConnected: Bool
    let onSaveAppleMusic: (String) -> Void
    let onSpotifyConnected: (String?) -> Void   // profile URL
    let onSpotifyDisconnected: () -> Void

    @State private var text: String
    @State private var isWorking = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    init(service: MusicService,
         current: String,
         spotifyConnected: Bool,
         onSaveAppleMusic: @escaping (String) -> Void,
         onSpotifyConnected: @escaping (String?) -> Void,
         onSpotifyDisconnected: @escaping () -> Void) {
        self.service = service
        self.current = current
        self.spotifyConnected = spotifyConnected
        self.onSaveAppleMusic = onSaveAppleMusic
        self.onSpotifyConnected = onSpotifyConnected
        self.onSpotifyDisconnected = onSpotifyDisconnected
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

            if service == .spotify {
                spotifyBody
            } else {
                appleMusicBody
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: Apple Music

    private var appleMusicBody: some View {
        Group {
            Text("In Apple Music: Listen Now → your photo → Edit → Share Profile.")
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
                        onSaveAppleMusic("")
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
                    onSaveAppleMusic(text.trimmingCharacters(in: .whitespaces))
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
        }
    }

    // MARK: Spotify

    private var spotifyBody: some View {
        Group {
            Text(spotifyConnected
                 ? "Connected. Every record you post is added to that month's Spotify playlist automatically."
                 : "Connect your Spotify account to attach real track links automatically and build a monthly playlist from your records.")
                .font(.sans(12.5))
                .foregroundStyle(Color.recordSecondary)
                .padding(.top, 8)

            if let errorMessage {
                Text(errorMessage)
                    .font(.sans(12))
                    .foregroundStyle(Color.recordDestructive)
                    .padding(.top, 12)
            }

            Button {
                Task { await handleSpotifyTap() }
            } label: {
                Text(isWorking ? "…" : (spotifyConnected ? "Disconnect" : "Connect with Spotify"))
                    .font(.sans(14, spotifyConnected ? .medium : .bold))
                    .foregroundStyle(spotifyConnected ? Color.recordDestructive : Color.recordInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(spotifyConnected ? Color.clear : Color.recordAccent)
                    .overlay(
                        Capsule().stroke(Color.recordDestructive.opacity(spotifyConnected ? 0.4 : 0), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .padding(.top, 20)
        }
    }

    private func handleSpotifyTap() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        if spotifyConnected {
            if await disconnectSpotify() {
                onSpotifyDisconnected()
                dismiss()
            } else {
                errorMessage = "Couldn't disconnect. Try again."
            }
            return
        }

        do {
            let result = try await connectSpotify(using: webAuthenticationSession)
            onSpotifyConnected(result.profile_url)
            dismiss()
        } catch {
            errorMessage = "Couldn't connect Spotify. Try again."
        }
    }
}

nonisolated struct LinksRow: Decodable {
    let apple_music_profile: String?
    let spotify_profile: String?
    let spotify_connected: Bool
}
