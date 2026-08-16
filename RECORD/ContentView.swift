//
//  ContentView.swift
//  RECORD
//
//  Created by Amir Rashidov on 20.06.2026.
//

import SwiftUI
internal import Auth
import Supabase

struct ProfileWithStreak: Decodable {
    let current_streak: Int
    let last_post_date: String?
    let avatar_url: String?
}

struct ContentView: View {
    @Binding var path: NavigationPath
    
    @State private var items: [TodayFeedItem] = []
    @State private var reactionCounts: [Int: [String: Int]] = [:] //[postID: [type: count]]
    @State private var myReactionsByPost: [Int: String] = [:] //[postID: myType]
    @State private var myUserID: String = ""
    @State private var expandedReactionPost: Int? = nil   // which post's reaction picker is open
    @State private var streak: Streak = Streak(count: 0, lastPostDate: nil)
    @State private var avatarURL: String?
    @State private var streakPopped = false
    @State private var loaded = false
    @EnvironmentObject private var audio: AudioPlayer
    
    /// True when friends have posted but you haven't. The server decides this — we just read the flag it sent rather than inferring it from nil fields.
    private var isLocked: Bool {
        items.contains { $0.locked }
    }
    
    private var myRecord: TodayFeedItem? {
        items.first { $0.isMine}
    }
    
    private var todayDateline: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · dd MMM yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date()).uppercased()
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MASTHEAD
                    Text("RECORD")
                        .font(.display(22, .bold))
                        .tracking(3)
                        .foregroundColor(.recordText)
                    
                    //DATELINE
                    HStack (spacing: 12) {
                        Text("THE DAILY EDITION")
                            .font(.sans(10, .medium))
                            .tracking(2)
                            .foregroundStyle(Color.recordTertiary)
                        Spacer()
                        Text(todayDateline)
                            .font(.sans(10, .medium))
                            .tracking(2)
                            .foregroundStyle(Color.recordTertiary)
                    }
                    Rectangle()
                        .fill(Color.recordTertiary.opacity(0.3))
                        .frame(height: 1)
                    
                    //THE GREEN "POST" CARD
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("YOUR RECORD · TODAY")
                                .font(.sans(10, .medium))
                                .tracking(1.5)
                                .foregroundStyle(Color.recordAccent)

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 1) {                                if streak.effectiveCount > 0 || streak.state == .broken {
                                    HStack(spacing: 5) {
                                        Text("\(streak.effectiveCount)")
                                            .font(.display(17, .extraBold))
                                            .foregroundStyle(streakNumberColor)
                                            .scaleEffect(streakPopped ? 1.3 : 1.0)
                                        Text("DAY STREAK")
                                            .font(.sans(9.5, .medium))
                                            .tracking(1)
                                            .foregroundStyle(streakLabelColor)
                                    }
                                }
                                if let nudge = streakNudge {
                                    Text(nudge)
                                        .font(.sans(10))
                                        .foregroundStyle(streakLabelColor)
                                }
                            }
                            .fixedSize()
                        }
                        
                        if let mine = myRecord {
                            // Posted — the card becomes your record.
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    AsyncImage(url: URL(string: mine.album_art_url ?? "")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.recordSeparator
                                    }
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    
                                    if let preview = mine.preview_url {
                                        let isPlaying = audio.currentlyPlayingURL == preview
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .opacity(isPlaying ? 1.0 : 0.4)
                                            .shadow(radius: 3)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let preview = mine.preview_url {
                                        audio.toggle(urlString: preview)
                                    }
                                }
                                
                                RecordDetails(track: mine.track_name ?? "",
                                              artist: mine.artist_name ?? "",
                                              note: mine.note)

                                Spacer(minLength: 0)
                            }
                        
                            
                            HStack(spacing: 8) {
                                if let spotifyURL = mine.spotify_url,
                                   let url = URL(string: spotifyURL) {
                                    MusicLink(url: url, imageName: "spotify-logo-white", text: "Spotify")
                                }
                                if let appleURL = mine.apple_music_url,
                                   let url = URL(string: appleURL) {
                                    MusicLink(url: url, imageName: "apple-music-logo-white", text: "Apple Music")
                                }
                            }
                            .padding(.top, 12)
                            
                        } else {
                            Text("What are you playing today?")
                                .font(.display(24, .bold))
                                .foregroundStyle(Color.recordText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            NavigationLink(value: "search") {
                                Text("Choose a song  →")
                                    .font(.sans(13.5, .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.recordAccent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.082, green: 0.082, blue: 0.082),   // #151515
                                Color(red: 0.063, green: 0.063, blue: 0.063)    // #101010
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.recordAccent)
                            .frame(width: 4)
                    }
                    
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.137, green: 0.137, blue: 0.137), lineWidth: 1) // #232323
                    )
                    
                    //TODAY'S RECORDS heading
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TODAY'S RECORDS")
                            .font(.display(16, .bold))
                            .tracking(1)
                            .foregroundStyle(Color.recordText)
                        Rectangle()
                            .fill(Color.recordTertiary.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // FEED — or empty state if no posts yet
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !loaded {
                                Color.clear.frame(height: 220)
                            } else if items.isEmpty {
                                VStack(spacing: 8) {
                            Text("00")
                                .font(.display(72, .extraBold))
                                .foregroundStyle(Color.recordSeparator)
                            Text("No records yet today.")
                                .font(.display(21, .bold))
                                .foregroundStyle(Color.recordText)
                            Text("The edition fills as your friends drop their song. Post yours and be the first line.")
                                .font(.sans(13))
                                .foregroundStyle(Color.recordSecondary)
                                .multilineTextAlignment(.center)
                            Text("ONE SONG · ONE DAY · RESETS MIDNIGHT UTC")
                                .font(.sans(10, .medium))
                                .tracking(2)
                                .foregroundStyle(Color.recordTertiary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if isLocked {
                        LockedEditionView(
                            count: items.count,
                            seeds: items.map { $0.id }
                        )
                    } else {
                        ForEach(items.filter { !$0.isMine }) { post in
                            FeedPostRow(
                                post: post,
                                myUserID: myUserID,
                                expandedReactionPost: expandedReactionPost,
                                reactionCounts: reactionCounts[post.id] ?? [:],
                                myReaction: myReactionsByPost[post.id],
                                audio: audio,
                                onReactionTap: { type in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                                        expandedReactionPost = nil
                                    }
                                    Task { await tapReaction(postID: post.id, type: type) }
                                },
                                onExpandToggle: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        expandedReactionPost = (expandedReactionPost == post.id) ? nil : post.id
                                    }
                                }
                            )
                        }
                    }   // closes else
                        }   // closes inner VStack (ScrollView content)
                    }   // closes ScrollView
                    .scrollIndicators(.hidden)
                    .padding(.top, -20)
                    .refreshable { await loadFeedAndReactions() }
                }   // closes outer VStack
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }   // closes ZStack
            .background(Color.recordBG.ignoresSafeArea())
            .recordDestinations(path: $path)
            
        }
        .task {
            await loadProfile()
            await loadFeedAndReactions()
        }
        .onChange(of: path) { _, newPath in
            // When the path goes back to empty, we've landed home - reload the feed.
            if newPath.isEmpty {
                Task {
                    await loadProfile()
                    await loadFeedAndReactions()
                }
            }
        }
        .onChange(of: streak.effectiveCount) { oldValue, newValue in
            if newValue > oldValue {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { 
                    streakPopped = true 
                } // grow
                Task {
                    try? await Task.sleep(for: .milliseconds(220)) // wait
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { 
                        streakPopped = false 
                    }
                }
            }
        }
    }

    func loadProfile() async {
        do {
            let userID = try await supabase.auth.session.user.id
            
            myUserID = userID.uuidString.lowercased()
            
            let profile: ProfileWithStreak = try await supabase
                .from("profiles")
                .select("current_streak, last_post_date, avatar_url")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            avatarURL = profile.avatar_url
            
            var lastDate: Date? = nil
            if let lastStr = profile.last_post_date {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                fmt.timeZone = TimeZone(identifier: "UTC")!
                lastDate = fmt.date(from: lastStr)
            }
            streak = Streak(count: profile.current_streak, lastPostDate: lastDate)
            
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
    
    func loadFeedAndReactions() async {
        //1. get my user id
        if myUserID.isEmpty {
            if let uid = try? await supabase.auth.session.user.id {
                myUserID = uid.uuidString.lowercased()
            }
        }
        //2. load today's posts
        items = await fetchTodayFeed()
        guard !Task.isCancelled else { return }
        //3. load reactions for those posts, then shape them
        let postIDs = items.map { $0.id }
        let reactions = await fetchReactions(postIDs: postIDs)
        guard !Task.isCancelled else { return }
        reactionCounts = countReactions(reactions)
        myReactionsByPost = myReactions(reactions, myUserID: myUserID)

        loaded = true
    }
    
    func tapReaction(postID: Int, type: String) async {
        guard !myUserID.isEmpty else { return }
        
        do {
            let existing = myReactionsByPost[postID]
            
            if existing == type {
                // tapped the same one → remove it
                try await supabase
                    .from("reactions")
                    .delete()
                    .eq("post_id", value: postID)
                    .eq("user_id", value: myUserID)
                    .execute()
            } else if existing != nil {
                // tapped a different one → switch it
                try await supabase
                    .from("reactions")
                    .update(["type": type])
                    .eq("post_id", value: postID)
                    .eq("user_id", value: myUserID)
                    .execute()
            } else {
                // no reaction yet → add it
                let newReaction = NewReaction(post_id: postID, user_id: myUserID, type: type)
                try await supabase
                    .from("reactions")
                    .insert(newReaction)
                    .execute()
            }
            
            //reload reactions so counts + my-pick refresh
            let postIDs = items.map { $0.id }
            let reactions = await fetchReactions(postIDs: postIDs)
            reactionCounts = countReactions(reactions)
            myReactionsByPost = myReactions(reactions, myUserID: myUserID)
            
        } catch {
            print("Reaction failed: \(error)")
        }
    }
    
    var streakNumberColor: Color {
        switch streak.state {
        case .active: return Color(red: 1.0, green: 0.918, blue: 0.953)
        case .dayOne: return Color(red: 0.949, green: 0.945, blue: 0.933)
        case .atRisk: return Color(red: 0.949, green: 0.757, blue: 0.306)
        case .broken: return Color(red: 0.49, green: 0.486, blue: 0.471)
        }
    }

    var streakLabelColor: Color {
        switch streak.state {
        case .active: return Color(red: 1.0, green: 0.561, blue: 0.749)
        case .dayOne: return Color(red: 0.541, green: 0.541, blue: 0.541)
        case .atRisk: return Color(red: 0.604, green: 0.482, blue: 0.2)
        case .broken: return Color(red: 0.353, green: 0.353, blue: 0.353)
        }
    }
    
    var streakNudge: String? {
        switch streak.state {
        case .active: return nil
        case .dayOne: return nil
        case .atRisk: return "post before midnight"
        case .broken: return streak.effectiveCount == 0 && streak.lastPostDate != nil ? "start over" : nil
        }
    }
}

// MARK: - FeedPostRow
struct FeedPostRow: View {
    let post: TodayFeedItem
    let myUserID: String
    let expandedReactionPost: Int?
    let reactionCounts: [String: Int]
    let myReaction: String?
    @ObservedObject var audio: AudioPlayer
    let onReactionTap: (String) -> Void
    let onExpandToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // WHO — avatar, name, time
            HStack(spacing: 9) {
                NavigationLink(value: ProfileRoute(userID: post.user_id,
                                                   username: post.username,
                                                   isMe: post.user_id == myUserID)) {
                    HStack(spacing: 9) {
                        FriendAvatar(username: post.username, url: post.avatar_url)
                        Text(post.username)
                            .font(.sans(13, .medium))
                            .foregroundStyle(Color.recordText)
                    }
                }
                .buttonStyle(.plain)

                Text(timeAgo)
                    .font(.sans(12))
                    .foregroundStyle(Color.recordTertiary)

                Spacer()
            }

            // WHAT — art, record, actions
            HStack(alignment: .top, spacing: 14) {
                albumArtView

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(post.track_name ?? "")
                            .font(.display(19, .bold))
                            .foregroundStyle(Color.recordText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Spacer(minLength: 4)
                        if let spotifyURL = post.spotify_url,
                           let url = URL(string: spotifyURL) {
                            IconLink(url: url, imageName: "spotify-logo-white")
                        }
                        if let appleURL = post.apple_music_url,
                           let url = URL(string: appleURL) {
                            IconLink(url: url, imageName: "apple-music-logo-white")
                        }
                    }

                    Text(post.artist_name ?? "")
                        .font(.sans(13))
                        .foregroundStyle(Color.recordArtist)
                        .lineLimit(1)
                        .padding(.top, -2)

                    if let note = post.note, !note.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle()
                                .fill(Color.recordNoteRule)
                                .frame(width: 2)
                            Text(note)
                                .font(.sans(12.5))
                                .italic()
                                .foregroundStyle(Color.recordNote)
                                .padding(.top, 2)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    }

                    reactionsRow
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 14)

        Rectangle()
            .fill(Color.recordTertiary.opacity(0.3))
            .frame(height: 1)
    }

    private var albumArtView: some View {
        ZStack {
            AsyncImage(url: URL(string: post.album_art_url ?? "")) { image in
                image.resizable()
            } placeholder: {
                Color.recordSeparator
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            
            if let preview = post.preview_url {
                let isPlaying = audio.currentlyPlayingURL == preview
                Image(systemName: isPlaying ? "pause.fill": "play.fill")
                    .font(.system(size: 16))
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
    }
    
    private var reactionsRow: some View {
        HStack(spacing: 8) {
            if expandedReactionPost == post.id {
                expandedReactionPicker
            } else {
                collapsedReactionCounts
            }
            expandToggleButton
        }
    }
    
    private var expandedReactionPicker: some View {
        HStack(spacing: 2) {
            ForEach(["fire", "heart", "sleepy", "poop"], id: \.self) { type in
                Button {
                    onReactionTap(type)
                } label: {
                    Text(emoji(for: type))
                        .font(.system(size: 16))
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .overlay(Capsule().stroke(Color.recordCardBorder, lineWidth: 1))
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    @ViewBuilder
    private var collapsedReactionCounts: some View {
        ForEach(["fire", "heart", "sleepy", "poop"], id: \.self) { type in
            let count = reactionCounts[type] ?? 0
            if count > 0 {
                let isMine = myReaction == type
                Button {
                    onReactionTap(type)
                } label: {
                    HStack(spacing: 5) {
                        Text(emoji(for: type))
                            .font(.system(size: 14))
                        Text("\(count)")
                            .font(.sans(12, .medium))
                            .foregroundStyle(isMine ? Color.recordText : Color.recordSecondary)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .overlay(
                        Capsule().stroke(
                            isMine ? Color.recordAccent : Color.recordCardBorder,
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var expandToggleButton: some View {
        Button(action: onExpandToggle) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.recordSecondary)
                .rotationEffect(.degrees(expandedReactionPost == post.id ? 45 : 0))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expandedReactionPost)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.recordCardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// "now" / "45m" / "7h" — posts are same-day, so hours is the ceiling.
    private var timeAgo: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: post.created_at)
                ?? ISO8601DateFormatter().date(from: post.created_at) else { return "" }

        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1  { return "now" }
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h"
    }
}

// MARK: - IconLink (feed rows — icon only)
struct IconLink: View {
    let url: URL
    let imageName: String

    var body: some View {
        Link(destination: url) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.recordCardBorder, lineWidth: 1))
        }
    }
}

// MARK: - MusicLink
struct MusicLink: View {
    let url: URL
    let imageName: String
    let text: String
    
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 5) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(text)
                    .font(.sans(13, .medium))
            }
            .foregroundStyle(Color.recordText)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .overlay(
                Capsule().stroke(Color.recordAccent.opacity(0.5), lineWidth: 1)
            )
        }
    }
}
        
                
                
                
