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
    @State private var joinedDate: String = ""
    @State private var appleMusicProfile: String?
    @State private var spotifyProfile: String?
    @StateObject private var audio = AudioPlayer()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.recordBG.ignoresSafeArea()

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
                                
                                // meta line: records · streak · since
                                Text(metaLine)
                                    .font(.sans(12, .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(Color(red: 0.416, green: 0.416, blue: 0.4))
                                
                                // service links
                                HStack(spacing: 16) {
                                    if let spotify = spotifyProfile, let url = URL(string: spotify) {
                                        Link(destination: url) {
                                            Text("SPOTIFY ↗")
                                                .font(.sans(11, .medium))
                                                .tracking(0.5)
                                                .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.525))
                                        }
                                    }
                                    if let apple = appleMusicProfile, let url = URL(string: apple) {
                                        Link(destination: url) {
                                            Text("APPLE MUSIC ↗")
                                                .font(.sans(11, .medium))
                                                .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.525))
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
                                    .foregroundStyle(Color.recordMuted)
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .padding(.top, 8)

                    Rectangle()
                        .fill(Color.recordSurface)
                        .frame(height: 1)
                        .padding(.vertical, 20)

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
        }
        .navigationBarBackButtonHidden(false)
        .task {
            await load()
        }
        .onDisappear {
            audio.stop()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task { await uploadAvatar(newItem) }
        }
        .sheet(isPresented: $showAvatarOptions) {
            avatarOptionsSheet
                .presentationDetents([.height(360)])
                .presentationBackground(Color.recordBG)
        }
    }

    // STAT LINE
    var statLine: String {
        var parts = ["\(totalRecords) record\(totalRecords == 1 ? "" : "s")"]
        if bestStreak > 1 {
            parts.append("\(bestStreak) day best")
        }
        return parts.joined(separator: " · ")
    }

    // EMPTY STATE
    var emptyState: some View {
        VStack(spacing: 10) {
            Text("00")
                .font(.display(72, .extraBold))
                .foregroundStyle(Color.recordSurface)
            if isMe {
                Text("No records yet.")
                    .font(.display(21, .bold))
                    .foregroundStyle(Color.recordText)
                Text("Your diary starts the day you post.")
                    .font(.sans(13))
                    .foregroundStyle(Color.recordMuted)
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
                    showAvatarOptions = false
                    showPhotoPicker = true
                } label: {
                    Text("Change Photo")
                        .font(.sans(15, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.recordGreen)
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
                            .foregroundStyle(Color.recordError)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                Capsule().stroke(Color.recordError.opacity(0.4), lineWidth: 1)
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
                        .foregroundStyle(Color.recordDim)
                    Rectangle()
                        .fill(Color.recordSurface)
                        .frame(height: 1)
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
                    Color.recordSurface
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.track_name)
                        .font(.display(17, .bold))
                        .foregroundStyle(Color.recordText)
                        .lineLimit(1)
                    Text(post.artist_name)
                        .font(.sans(13))
                        .foregroundStyle(Color.recordMuted)
                        .lineLimit(1)
                    if let note = post.note, !note.isEmpty {
                        Text(note)
                            .font(.sans(13))
                            .italic()
                            .foregroundStyle(Color.recordMuted)
                            .padding(.leading, 8)
                            .overlay(
                                Rectangle().fill(Color.recordSurface2).frame(width: 2),
                                alignment: .leading
                            )
                            .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12)
            
            Rectangle()
                .fill(Color.recordSurface)
                .frame(height: 1)
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
                .select("current_streak, last_post_date, longest_streak, avatar_url, created_at, apple_music_profile, spotify_profile")
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
        } catch {
            print("Profile load failed: \(error)")
        }
        loading = false
    }
    
    func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploading = true
        defer { uploading = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("Couldn't load image data")
                return
            }
             
            let path = "\(userID).jpg"
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(upsert: true))
            
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
            print("Avatar upload failed: \(error)")
        }
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
            print("Remove avatar failed: \(error)")
        }
    }

    func logOut() async {
        do { try await supabase.auth.signOut() }
        catch { print("Logout failed: \(error)") }
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
    
        var metaLine: String {
            var parts = ["\(totalRecords) RECORD\(totalRecords == 1 ? "" : "S")"]
            if streak.effectiveCount > 0 {
                parts.append("\(streak.effectiveCount) DAY STREAK")
            }
            if !joinedDate.isEmpty {
                parts.append("SINCE \(joinedDate)")
            }
            return parts.joined(separator: " · ")
        }
}

struct ProfileFullRow: Decodable {
    let current_streak: Int
    let last_post_date: String?
    let longest_streak: Int
    let avatar_url: String?
    let created_at: String?
    let apple_music_profile: String?
    let spotify_profile: String?
}
