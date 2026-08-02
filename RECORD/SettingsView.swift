//
//  SettingsView.swift
//  RECORD
//
//  Created by Amir Rashidov on 01.08.2026.
//

import SwiftUI
import Supabase

struct SettingsView: View {
    
    @State private var appleMusicProfile = ""
    @State private var spotifyProfile = ""
    @State private var loading = true
    @State private var saving = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    
    var body: some View {
        ZStack {
            Color.recordBG.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // LISTENING SECTION
                    sectionHeader("LISTENING")
                    
                    Text("Where friends can find you.")
                        .font(.sans(12.5))
                        .foregroundStyle(Color.recordMuted)
                        .padding(.bottom, 12)
                    
                    // Spotify field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SPOTIFY PROFILE URL")
                            .font(.sans(10, .medium))
                            .tracking(1)
                            .foregroundStyle(Color.recordDim)
                        TextField("", text: $spotifyProfile,
                                  prompt: Text("paste your Spotify profile link").foregroundColor(.recordDim))
                            .font(.sans(14))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.recordSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color.recordText)
                     }
                    .padding(.vertical, 10)
                    
                    // Apple Music field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APPLE MUSIC PROFILE URL")
                            .font(.sans(10, .medium))
                            .tracking(1)
                            .foregroundStyle(Color.recordDim)
                        TextField("", text: $appleMusicProfile,
                                  prompt: Text("paste your Apple Music profile link").foregroundColor(.recordDim))
                            .font(.sans(14))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.recordSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color.recordText)
                    }
                    .padding(.vertical, 10)
                    
                    // Save button
                    Button {
                        Task { await saveLinks() }
                    } label: {
                        Text(saving ? "Saving..." : "Save")
                            .font(.sans(14, .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.recordGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(saving)
                    .padding(.top, 8)
                    
                    // ACCOUNT SECTION
                    sectionHeader("ACCOUNT")
                    
                    // Sign Out
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
                                    .stroke(Color.recordSurface2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    
                    // DELETE account ( we" ll wire this next)
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text(deleting ? "Deleting..." : "Delete Account")
                            .font(.sans(12.5))
                            .foregroundStyle(Color.recordError)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .disabled(deleting)
                }
                .padding(24)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLinks() }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes your records, streak, and profile. This can't be undone.")
        }
    }
    
    // MARK: - Section Header
    // section header with rule line
    func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.sans(11, .medium))
                .tracking(1)
                .foregroundStyle(Color.recordDim)
            Rectangle()
                .fill(Color(red: 0.113, green: 0.113, blue: 0.113))
                .frame(height: 1)
        }
        .padding(.top, 30)
        .padding(.bottom, 6)
    }
    
    // MARK: - load Links / save Links / sign Out / delete Account
    func loadLinks() async {
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
        }
        loading = false
    }
    
    func saveLinks() async {
        saving = true
        defer { saving = false}
        do {
            let userID = try await supabase.auth.session.user.id
            try await supabase
                .from("profiles")
                .update([
                    "apple_music_profile": appleMusicProfile.isEmpty ? nil : appleMusicProfile,
                    "spotify_profile": spotifyProfile.isEmpty ? nil : spotifyProfile
                ])
                .eq("id", value: userID)
                .execute()
        } catch {
            print("Save links failed: \(error)")
        }
    }
    
    func signOut() async {
        do { try await supabase.auth.signOut() }
        catch { print("Sign out failed: \(error)") }
    }
    
    func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            print("Calling delete-account function...")   // ← ADD
            let response: DeleteResponse = try await supabase.functions
                .invoke("delete-account")
            print("Delete response: \(response)")           // ← ADD

            try? await supabase.auth.signOut()
            print("Signed out")                             // ← ADD
        } catch {
            print("Delete account failed: \(error)")        // ← already there
        }
    }
}

struct LinksRow: Decodable {
    let apple_music_profile: String?
    let spotify_profile: String?
}

struct DeleteResponse: Decodable {
    let success: Bool?
    let error: String?
}
