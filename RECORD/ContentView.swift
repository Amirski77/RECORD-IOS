//
//  ContentView.swift
//  RECORD
//
//  Created by Amir Rashidov on 20.06.2026.
//

import SwiftUI
internal import Auth
import Supabase

struct ContentView: View {
    @State private var username = "..."
    @State private var posts: [FeedPost] = []
    @State private var path = NavigationPath()
    
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
                        Text(username)
                            .font(.sans(11, .medium))
                            .foregroundStyle(Color.recordMuted)
                        Button {
                            Task { await logOut() }
                        } label: {
                            Text("Log out")
                                .font(.sans(11, .medium))
                                .foregroundStyle(Color.recordGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    //DATELINE
                    HStack {
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
                        Text("YOUR RECORD · TODAY")
                            .font(.sans(10, .medium))
                            .tracking(1.5)
                            .foregroundStyle(Color.recordGreen)
                        
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
                                .background(Color.recordGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.recordSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Rectangle()
                            .fill(Color.recordGreen)
                            .frame(width: 4)
                        , alignment: .leading
                    )
                    VStack(alignment: .leading, spacing: 12) {
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
                            HStack(spacing: 12) {
                                // album art
                                AsyncImage(url: URL(string: post.album_art_url)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.recordSurface
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                // text column
                                VStack(alignment: .leading, spacing: 3) {
                                    // username — the NEW twist: comes through the nested profile
                                    Text(post.profiles.username)
                                        .font(.sans(11, .medium))
                                        .tracking(0.5)
                                        .foregroundStyle(Color.recordGreen)

                                    Text(post.track_name)
                                        .font(.sans(15, .medium))
                                        .foregroundStyle(Color.recordText)
                                        .lineLimit(1)

                                    Text(post.artist_name)
                                        .font(.sans(13))
                                        .foregroundStyle(Color.recordMuted)
                                        .lineLimit(1)

                                    // optional note — only shows if there is one
                                    if let note = post.note, !note.isEmpty {
                                        Text(note)
                                            .font(.sans(13))
                                            .foregroundStyle(Color.recordMuted)
                                            .padding(.top, 2)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                        }
                    }
                }
            }   // ← this closes the OUTER VStack
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .navigationDestination(for: String.self) { value in
                if value == "search" {
                    SearchView(path: $path)
                }
            }
            .navigationDestination(for: Song.self) { song in
                PostConfirmView(song: song, path: $path)
            }
        }
        }
        .task {
            await loadProfile()
            posts = await fetchTodayFeed()
        }
        .onChange(of: path) { _, newPath in
            // When the path goes back to empty, we've landed home - reload the feed.
            if newPath.isEmpty {
                Task {
                    posts = await fetchTodayFeed()
                }
            }
            
        }
    }

    func loadProfile() async {
        do {
            let userID = try await supabase.auth.session.user.id
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            username = profile.username
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
    
    func logOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Logout failed: \(error)")
        }
    }
}
#Preview {
    ContentView()
}

        
                
                
                
