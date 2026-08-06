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
    let username: String
    let current_streak: Int
    let last_post_date: String?
    let avatar_url: String?
}

struct ContentView: View {
    @State private var username = "..."
    @State private var posts: [FeedPost] = []
    @State private var path = NavigationPath()
    @State private var reactionCounts: [Int: [String: Int]] = [:] //[postID: [type: count]]
    @State private var myReactionsByPost: [Int: String] = [:] //[postID: myType]
    @State private var myUserID: String = ""
    @State private var expandedReactionPost: Int? = nil   // which post's reaction picker is open
    @State private var streak: Streak = Streak(count: 0, lastPostDate: nil)
    @State private var avatarURL: String?
    @State private var streakPopped = false
    @StateObject private var audio = AudioPlayer()
    
    private var todayDateline: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · dd MMM yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date()).uppercased()
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                //Full-screen dark background
                Color.recordBG
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    
                    // HEADER: wordmark + nav
                    HStack {
                        Text ("RECORD")
                            .font(.display(22, .bold))
                            .tracking(3)
                            .foregroundColor(.recordText)
                        Spacer()
                        NavigationLink(value: ProfileRoute( userID: myUserID, username: username, isMe: true)) {
                            HStack(spacing: 8) {
                                Group {
                                    if let avatarURL, let url = URL(string: avatarURL) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            AvatarView(username: username, size: 28)
                                        }
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                    } else {
                                        AvatarView(username: username, size: 28)
                                    }
                                }
                                Text(username)
                                    .font(.sans(13, .medium))
                                    .foregroundStyle(Color.recordMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        
                    }
                    
                    //DATELINE
                    HStack (spacing: 12) {
                        Text("THE DAILY EDITION")
                            .font(.sans(10, .medium))
                            .tracking(2)
                            .foregroundStyle(Color.recordDim)
                        Spacer()
                        Text(todayDateline)
                            .font(.sans(10, .medium))
                            .tracking(2)
                            .foregroundStyle(Color.recordDim)
                    }
                    Rectangle()
                        .fill(Color.recordDim.opacity(0.3))
                        .frame(height: 1)
                    
                    //THE GREEN "POST" CARD
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("YOUR RECORD · TODAY")
                                    .font(.sans(10, .medium))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.recordAccent)
                                Spacer()
                                if streak.effectiveCount > 0 || streak.state == .broken {
                                    HStack {
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
                            }
                            
                            // NUDGE LINE - own line, right-aligned
                            if let nudge = streakNudge {
                                Text(nudge)
                                    .font(.sans(10.5))
                                    .foregroundStyle(streakLabelColor)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        
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
                    Text("TODAY'S RECORDS")
                        .font(.display(16, .bold))
                        .tracking(1)
                        .foregroundStyle(Color.recordText)
                    Rectangle()
                        .fill(Color.recordDim.opacity(0.3))
                        .frame(height: 1)
                    
                    // FEED — or empty state if no posts yet
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                    if posts.isEmpty {
                        VStack(spacing: 8) {
                            Text("00")
                                .font(.display(72, .extraBold))
                                .foregroundStyle(Color.recordSurface)
                            Text("No records yet today.")
                                .font(.display(21, .bold))
                                .foregroundStyle(Color.recordText)
                            Text("The edition fills as your friends drop their song. Post yours and be the first line.")
                                .font(.sans(13))
                                .foregroundStyle(Color.recordMuted)
                                .multilineTextAlignment(.center)
                            Text("ONE SONG · ONE DAY · RESETS MIDNIGHT UTC")
                                .font(.sans(10, .medium))
                                .tracking(2)
                                .foregroundStyle(Color.recordDim)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(posts) { post in
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
                }   // closes outer VStack
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }   // closes ZStack — padding + navigationDestination attach here
            .navigationDestination(for: String.self) { value in
                if value == "search" {
                    SearchView(path: $path)
                } else if value == "settings" {
                    SettingsView()
                }
            }
            .navigationDestination(for: Song.self) { song in
                PostConfirmView(song: song, path: $path)
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                ProfileView(userID: route.userID, username: route.username, isMe: route.isMe)
            }
            
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
                .select("username, current_streak, last_post_date, avatar_url")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            username = profile.username
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
        posts = await fetchTodayFeed()
        //3. load reactions for those posts, then shape them
        let postIDs = posts.map { $0.id }
        let reactions = await fetchReactions(postIDs: postIDs)
        reactionCounts = countReactions(reactions)
        myReactionsByPost = myReactions(reactions, myUserID: myUserID)
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
            let postIDs = posts.map { $0.id }
            let reactions = await fetchReactions(postIDs: postIDs)
            reactionCounts = countReactions(reactions)
            myReactionsByPost = myReactions(reactions, myUserID: myUserID)
            
        } catch {
            print("Reaction failed: \(error)")
        }
    }
    
    func logOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Logout failed: \(error)")
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
        case .dayOne: return "new streak"
        case .atRisk: return "post before midnight"
        case .broken: return streak.effectiveCount == 0 && streak.lastPostDate != nil ? "start again" : nil
        }
    }
}

// MARK: - FeedPostRow
struct FeedPostRow: View {
    let post: FeedPost
    let myUserID: String
    let expandedReactionPost: Int?
    let reactionCounts: [String: Int]
    let myReaction: String?
    @ObservedObject var audio: AudioPlayer
    let onReactionTap: (String) -> Void
    let onExpandToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Album art with play button
            albumArtView
            
            // Text column
            VStack(alignment: .leading, spacing: 3) {
                usernameLink
                trackNameText
                artistNameText
                noteText
                musicLinksView
                reactionsRow
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var albumArtView: some View {
        ZStack {
            AsyncImage(url: URL(string: post.album_art_url)) { image in
                image.resizable()
            } placeholder: {
                Color.recordSurface
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
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
    
    private var usernameLink: some View {
        NavigationLink(value: ProfileRoute(userID: post.user_id, username: post.profiles.username, isMe: post.user_id == myUserID)) {
            Text(post.profiles.username)
                .font(.sans(11, .medium))
                .tracking(0.5)
                .foregroundStyle(Color.recordAccent)
        }
        .buttonStyle(.plain)
    }
    
    private var trackNameText: some View {
        Text(post.track_name)
            .font(.display(19, .bold))
            .foregroundStyle(Color.recordText)
            .lineLimit(1)
    }
    
    private var artistNameText: some View {
        Text(post.artist_name)
            .font(.sans(15))
            .foregroundStyle(Color.recordMuted)
            .lineLimit(1)
    }
    
    @ViewBuilder
    private var noteText: some View {
        if let note = post.note, !note.isEmpty {
            Text(note)
                .font(.sans(13))
                .foregroundStyle(Color.recordMuted)
                .padding(.top, 2)
        }
    }
    
    private var musicLinksView: some View {
        HStack(spacing: 8) {
            if let appleURL = post.apple_music_url,
               let url = URL(string: appleURL) {
                MusicLink(url: url, imageName: "apple-music-logo-white", text: "Apple Music")
            }
            
            if let spotifyURL = post.spotify_url,
               let url = URL(string: spotifyURL) {
                MusicLink(url: url, imageName: "spotify-logo-white", text: "Spotify")
            }
        }
        .padding(.top, 5)
    }
    
    private var reactionsRow: some View {
        HStack(spacing: 6) {
            if expandedReactionPost == post.id {
                expandedReactionPicker
            } else {
                collapsedReactionCounts
            }
            
            expandToggleButton
        }
        .padding(.top, 6)
    }
    
    private var expandedReactionPicker: some View {
        HStack(spacing: 6) {
            ForEach(["fire", "heart", "sleepy", "poop"], id: \.self) { type in
                Button {
                    onReactionTap(type)
                } label: {
                    Text(emoji(for: type))
                        .font(.system(size: 17))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.recordBG)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.recordSurface2, lineWidth: 1))
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
                    HStack(spacing: 3) {
                        Text(emoji(for: type))
                            .font(.system(size: 15))
                        if count >= 2 {
                            Text("\(count)")
                                .font(.sans(13, .medium))
                                .foregroundStyle(Color.recordMuted)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isMine ? Color.recordAccent.opacity(0.2) : Color.recordSurface2)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var expandToggleButton: some View {
        Button(action: onExpandToggle) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(expandedReactionPost == post.id ? Color.recordAccent : Color.recordMuted)
                .rotationEffect(.degrees(expandedReactionPost == post.id ? 45 : 0))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expandedReactionPost)
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(Color.recordSurface2)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

#Preview {
    ContentView()
}

        
                
                
                
