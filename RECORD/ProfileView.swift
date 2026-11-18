//
//  ProfileView.swift
//  RECORD
//
//  Created by Amir Rashidov on 18.07.2026.
//

import Foundation
import SwiftUI
import Supabase
import PhotosUI
import UIKit

struct ProfileRoute: Hashable {
    let userID: String
    let username: String
    let isMe: Bool
}

struct ProfileView: View {
    let userID: String
    let username: String
    let isMe: Bool          // my profile vs someone else's
    

    @State private var posts: [FeedPost] = []
    @State private var streak: Streak = Streak(count: 0, lastPostDate: nil)
    @State private var totalRecords = 0
    @State private var bestStreak = 0
    @State private var loading = true
    @State private var selectedItem: PhotosPickerItem? // what the user picked
    @State private var avatarURL: String? // their current photo URL
    @State private var uploading = false // upload in progress
    @State private var showAvatarOptions = false
    @State private var showPhotoPicker = false
    @State private var pickPhotoAfterDismiss = false   // open the picker once the options sheet is gone
    @State private var joinedDate: String = ""
    @State private var appleMusicProfile: String?
    @State private var spotifyProfile: String?
    @State private var spotifyConnected = false
    @State private var monthPlaylists: [String: String] = [:]   // "YYYY-MM": playlist URL
    @State private var syncingMonths: Set<String> = []
    @EnvironmentObject private var audio: AudioPlayer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ===== PROFILE HEADER =====
                    HStack(alignment: .top) {
                        // avatar + identity
                        HStack(alignment: .top, spacing: 14) {
                            // avatar ( tappable if mine - opens photo sheet)
                            Group {
                                if isMe {
                                    Button { showAvatarOptions = true } label: { avatarImage }
                                        .buttonStyle(.plain)
                                } else {
                                    avatarImage
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(username)
                                    .font(.display(30, .bold))
                                    .foregroundStyle(Color.recordText)
                                
                                // meta line — bright numerals, dim rest
                                Text(metaLineAttributed)
                                .font(.sans(12, .medium))
                                .tracking(0.5)
                                .opacity(loading ? 0 : 1)
                                
                                // service links
                                HStack(spacing: 10) {
                                    if let spotify = spotifyProfile, let url = URL(string: spotify) {
                                        Link(destination: url) {
                                            HStack(spacing: 5) {
                                                Image("spotify-logo-white")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 13, height: 13)
                                                Text("SPOTIFY")
                                                    .font(.sans(11, .medium))
                                                    .tracking(0.5)
                                                    .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.525))
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .overlay(
                                                Capsule().stroke(Color(red: 0.16, green: 0.16, blue: 0.16), lineWidth: 1)
                                            )
                                        }
                                    }
                                    if let apple = appleMusicProfile, let url = URL(string: apple) {
                                        Link(destination: url) {
                                            HStack(spacing: 5) {
                                                Image("apple-music-logo-white")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 13, height: 13)
                                                Text("APPLE MUSIC")
                                                    .font(.sans(11, .medium))
                                                    .tracking(0.5)
                                                    .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.525))
                                            }
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .overlay(
                                                Capsule().stroke(Color(red: 0.16, green: 0.16, blue: 0.16), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        Spacer()
                        
                        // ⋯ overflow menu (mine only)
                        if isMe {
                            Menu {
                                NavigationLink(value: "settings") {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                Button(role: .destructive) {
                                    Task { await logOut() }
                                } label: {
                                    Label("Log Out", systemImage: "arrow.right.square")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.recordSecondary)
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .padding(.top, 8)

                    Rectangle()
                        .fill(Color.recordSeparator)
                        .frame(height: 1)
                        .padding(.top, 20)
                    
                    // THE DIARY header
                    Text("THE DIARY")
                        .font(.display(20, .bold))
                        .foregroundStyle(Color.recordText)
                        .padding(.top, 22)
                        .padding(.bottom, 4)

                    Rectangle()
                        .fill(Color.recordSeparator)
                        .frame(height: 1)
                        .padding(.bottom, 4)

                    // DIARY LIST
                    if loading {
                        // simple loading — quiet
                        Text("")
                    } else if posts.isEmpty {
                        emptyState
                    } else {
                        diaryList
                    }
                }
                .padding(20)
            }
            .refreshable { await load() }
        }
        .background(Color.recordBG.ignoresSafeArea())
        .navigationBarBackButtonHidden(false)
        .task {
            await load()
        }
        
        .onChange(of: selectedItem) { _, newItem in
            Task { await uploadAvatar(newItem) }
        }
        // Presenting the picker while the sheet is still animating out can be
        // silently dropped, so wait for the sheet's dismissal to finish.
        .sheet(isPresented: $showAvatarOptions, onDismiss: {
            if pickPhotoAfterDismiss {
                pickPhotoAfterDismiss = false
                showPhotoPicker = true
            }
        }) {
            avatarOptionsSheet
                .presentationDetents([.height(360)])
                .presentationBackground(Color.recordBG)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
    }

    // EMPTY STATE
    var emptyState: some View {
        VStack(spacing: 10) {
            Text("00")
                .font(.display(72, .extraBold))
                .foregroundStyle(Color.recordSeparator)
            if isMe {
                Text("No records yet.")
                    .font(.display(21, .bold))
                    .foregroundStyle(Color.recordText)
                Text("Your diary starts the day you post.")
                    .font(.sans(13))
                    .foregroundStyle(Color.recordSecondary)
            } else {
                Text("\(username) hasn't posted yet.")
                    .font(.display(21, .bold))
                    .foregroundStyle(Color.recordText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    // avatarImage
    var avatarImage: some View {
        Group {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AvatarView(username: username, size: 64)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                AvatarView(username: username, size: 64)
            }
        }
    }
    
    var avatarOptionsSheet: some View {
        VStack(spacing: 24) {
            // enlarged photo (or letter-circle) at top
            Group {
                if let avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        AvatarView(username: username, size: 120)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    AvatarView(username: username, size: 120)
                }
            }
            .padding(.top, 32)

            // buttons
            VStack(spacing: 12) {
                Button {
                    pickPhotoAfterDismiss = true
                    showAvatarOptions = false
                } label: {
                    Text("Change Photo")
                        .font(.sans(15, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.recordAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if avatarURL != nil {
                    Button {
                        showAvatarOptions = false
                        Task { await removeAvatar() }
                    } label: {
                        Text("Delete Photo")
                            .font(.sans(15, .medium))
                            .foregroundStyle(Color.recordDestructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                Capsule().stroke(Color.recordDestructive.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // DIARY LIST (grouped by month)
    var diaryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupedByMonth, id: \.month) { group in
                // month header
                HStack(spacing: 12) {
                    Text(group.month.uppercased())
                        .font(.sans(11, .medium))
                        .tracking(1.5)
                        .foregroundStyle(Color.recordTertiary)
                    Rectangle()
                        .fill(Color.recordSeparator)
                        .frame(height: 1)
                    if isMe, spotifyConnected,
                       let key = group.posts.first.flatMap({ monthKey(fromCreatedAt: $0.created_at) }) {
                        monthPlaylistButton(monthKey: key)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)

                ForEach(group.posts) { post in
                    diaryRow(post)
                }
            }
        }
    }

    // one diary row
    func diaryRow(_ post: FeedPost) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // day number
                Text(dayNumber(post.created_at))
                    .font(.display(22, .bold))
                    .foregroundStyle(Color.recordText)
                    .frame(width: 32, alignment: .leading)
                
                // cover art - tappable to play
                ZStack {
                    AsyncImage(url: URL(string: post.album_art_url)) { image in
                    image.resizable()
                } placeholder: {
                    Color.recordSeparator
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    if let preview = post.preview_url {
                        let isPlaying = audio.currentlyPlayingURL == preview
                        Image ( systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .opacity(isPlaying ? 1.0 : 0.4)
                            .shadow(radius: 3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let preview = post.preview_url {
                        audio.toggle(urlString: preview)
                    }
                }
                
                // track + artist + note
                RecordDetails(track: post.track_name,
                              artist: post.artist_name,
                              note: post.note,
                              trackSize: 17)
                Spacer()
            }
            .padding(.vertical, 12)
            
            Rectangle()
                .fill(Color.recordSeparator)
                .frame(height: 1)
        }
    }

    // month playlist button — "Create" if not synced yet, "Open ↗" + resync once it is
    private func monthPlaylistButton(monthKey: String) -> some View {
        let syncing = syncingMonths.contains(monthKey)

        return HStack(spacing: 6) {
            if let urlString = monthPlaylists[monthKey], let url = URL(string: urlString) {
                Link(destination: url) {
                    playlistCapsuleLabel(syncing ? "SYNCING…" : "PLAYLIST")
                }
                Button {
                    Task { await syncMonth(monthKey) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.recordTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(syncing)
            } else {
                Button {
                    Task { await syncMonth(monthKey) }
                } label: {
                    playlistCapsuleLabel(syncing ? "SYNCING…" : "CREATE PLAYLIST")
                }
                .buttonStyle(.plain)
                .disabled(syncing)
            }
        }
    }

    private func playlistCapsuleLabel(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image("spotify-logo-white")
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
            Text(text)
                .font(.sans(10, .medium))
                .tracking(0.5)
        }
        .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.525))
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .overlay(
            Capsule().stroke(Color(red: 0.16, green: 0.16, blue: 0.16), lineWidth: 1)
        )
    }

    private func syncMonth(_ key: String) async {
        guard !syncingMonths.contains(key) else { return }
        syncingMonths.insert(key)
        defer { syncingMonths.remove(key) }
        if let url = await syncMonthPlaylist(month: key) {
            monthPlaylists[key] = url
        }
    }

    //  DATA LOADING
    func load() async {
        posts = await fetchUserPosts(userID: userID)
        totalRecords = posts.count

        // streak + best from the profile row
        do {
            let row: ProfileFullRow = try await supabase
                .from("profiles")
                .select("current_streak, last_post_date, longest_streak, avatar_url, created_at, apple_music_profile, spotify_profile, spotify_connected")
                .eq("id", value: userID)
                .single()
                .execute()
                .value

            var lastDate: Date? = nil
            if let lastStr = row.last_post_date {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                fmt.timeZone = TimeZone(identifier: "UTC")!
                lastDate = fmt.date(from: lastStr)
            }
            streak = Streak(count: row.current_streak, lastPostDate: lastDate)
            bestStreak = row.longest_streak
            
            avatarURL = row.avatar_url
            
            // joined date -> 'JUL 2026"
            if let created = row.created_at {
                let inFmt = ISO8601DateFormatter()
                inFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = inFmt.date(from: created) ?? ISO8601DateFormatter().date(from: created)
                if let date {
                    let outFmt = DateFormatter()
                    outFmt.dateFormat = "MMM yyyy"
                    joinedDate = outFmt.string(from: date).uppercased()
                }
            }
            appleMusicProfile = row.apple_music_profile
            spotifyProfile = row.spotify_profile
            spotifyConnected = row.spotify_connected
        } catch {
            AppLog.loud("profile load", error, say: "Couldn't load this diary. Pull to retry.")
        }

        if isMe && spotifyConnected {
            monthPlaylists = await fetchMonthPlaylists()
        }

        loading = false
    }
    
    func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploading = true
        defer { uploading = false }
        
        do {
            guard let picked = try await item.loadTransferable(type: Data.self) else {
                AppLog.tell("Couldn't read that photo. Try another.")
                return
            }

            // The picker hands back the original file — usually HEIC off an
            // iPhone camera, and often several megabytes. The bucket now
            // accepts image/jpeg under 2 MiB only, and a 512px square is all
            // the UI ever draws, so normalise before uploading instead of
            // shipping whatever the camera produced under a .jpg name.
            guard let data = Self.jpegSquare(from: picked) else {
                AppLog.tell("That photo couldn't be used. Try another.")
                return
            }

            let path = "\(userID).jpg"
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data,
                        options: FileOptions(contentType: "image/jpeg", upsert: true))
            
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: path)

            let urlString = publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"

            let updateData: [String: String] = ["avatar_url": urlString]
            try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userID)
                .execute()

            avatarURL = urlString

        } catch {
            AppLog.loud("avatar upload", error, say: "Couldn't save your photo.")
        }
    }
    
    /// Centre-crops to a square, scales down to `maxSide` points at 1x, and
    /// encodes as JPEG. Returns nil if the data isn't a decodable image.
    nonisolated static func jpegSquare(from data: Data, maxSide: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let side  = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }

        let scale  = min(1, maxSide / side)
        let target = CGSize(width: side * scale, height: side * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                      // target is already in pixels
        format.opaque = true

        let square = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            // Draw the whole image scaled, offset so the centre square lands
            // in the canvas; the overflow is the crop.
            let drawn = CGSize(width: image.size.width * scale,
                               height: image.size.height * scale)
            image.draw(in: CGRect(x: (target.width  - drawn.width)  / 2,
                                  y: (target.height - drawn.height) / 2,
                                  width: drawn.width,
                                  height: drawn.height))
        }

        return square.jpegData(compressionQuality: 0.85)
    }

    func removeAvatar() async {
        do {
            // clear the URL in the profile
            try await supabase
                .from("profiles")
                .update(["avatar_url": nil as String?])
                .eq("id", value: userID)
                .execute()

            // delete the file from storage
            let _ = try? await supabase.storage
                .from("avatars")
                .remove(paths: ["\(userID).jpg"])

            avatarURL = nil   // back to letter-circle
        } catch {
            AppLog.loud("avatar remove", error, say: "Couldn't remove your photo.")
        }
    }

    func logOut() async {
        audio.stop()
        do { try await supabase.auth.signOut() }
        catch { AppLog.loud("sign out", error, say: "Couldn't sign out. Try again.") }
    }

    // HELPERS: date parsing + month grouping
    // created_at looks like "2026-07-14T13:00:00+00:00"
    func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        return f2.date(from: s)
    }

    func dayNumber(_ createdAt: String) -> String {
        guard let d = parseDate(createdAt) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = TimeZone(identifier: "UTC")!
        return f.string(from: d)
    }

    // group posts by "Month Year"
    var groupedByMonth: [(month: String, posts: [FeedPost])] {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone = TimeZone(identifier: "UTC")!

        var order: [String] = []
        var map: [String: [FeedPost]] = [:]
        for post in posts {   // already newest-first
            let key = parseDate(post.created_at).map { f.string(from: $0) } ?? "—"
            if map[key] == nil { order.append(key); map[key] = [] }
            map[key]?.append(post)
        }
        return order.map { (month: $0, posts: map[$0]!) }
    }

    // streak colors (my profile uses state color)
    var streakNumberColor: Color {
        switch streak.state {
        case .active: return Color(red: 0.918, green: 1.0, blue: 0.945)
        case .dayOne: return Color(red: 0.949, green: 0.945, blue: 0.933)
        case .atRisk: return Color(red: 1.0, green: 0.706, blue: 0.329)
        case .broken: return Color(red: 0.49, green: 0.486, blue: 0.471)
        }
    }
    
    var metaGray: Color {
        Color(red: 0.416, green: 0.416, blue: 0.4)   // #6a6a66
    }
    
    var metaLineAttributed: AttributedString {
        var result = AttributedString()
        
        // Total records number
        var recordsNum = AttributedString("\(totalRecords)")
        recordsNum.foregroundColor = Color.recordText
        result.append(recordsNum)
        
        // Records label - using metaGray (#6a6a66)
        var recordsLabel = AttributedString(" RECORD\(totalRecords == 1 ? "" : "S")")
        recordsLabel.foregroundColor = metaGray
        result.append(recordsLabel)
        
        // Streak (if active)
        if streak.effectiveCount > 0 {
            var separator1 = AttributedString("  ·  ")
            separator1.foregroundColor = metaGray
            result.append(separator1)
            
            var streakNum = AttributedString("\(streak.effectiveCount)")
            streakNum.foregroundColor = Color.recordText
            result.append(streakNum)
            
            // Day streak label - using metaGray (#6a6a66)
            var streakLabel = AttributedString(" DAY STREAK")
            streakLabel.foregroundColor = metaGray
            result.append(streakLabel)
        }

        // Best streak — only when it's a different (higher) number than the
        // current one, so an active record doesn't repeat itself twice.
        if bestStreak > streak.effectiveCount {
            var separator3 = AttributedString("  ·  ")
            separator3.foregroundColor = metaGray
            result.append(separator3)

            var bestNum = AttributedString("\(bestStreak)")
            bestNum.foregroundColor = Color.recordText
            result.append(bestNum)

            var bestLabel = AttributedString(" BEST")
            bestLabel.foregroundColor = metaGray
            result.append(bestLabel)
        }

        // Joined date
        if !joinedDate.isEmpty {
            var separator2 = AttributedString("  ·  SINCE \(joinedDate)")
            separator2.foregroundColor = metaGray
            result.append(separator2)
        }
        
        return result
    }
    
}

nonisolated struct ProfileFullRow: Decodable {
    let current_streak: Int
    let last_post_date: String?
    let longest_streak: Int
    let avatar_url: String?
    let created_at: String?
    let apple_music_profile: String?
    let spotify_profile: String?
    let spotify_connected: Bool
}
