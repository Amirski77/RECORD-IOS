//
//  ProfileView.swift
//  RECORD
//
//  Created by Amir Rashidov on 18.07.2026.
//

import Foundation
import SwiftUI
import Supabase

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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.recordBG.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ===== PROFILE HEADER =====
                    HStack(alignment: .top, spacing: 14) {
                        AvatarView(username: username, size: 64)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(username)
                                .font(.display(30, .bold))
                                .foregroundStyle(Color.recordText)

                            // stat line: "12 records · 5 day best"
                            Text(statLine)
                                .font(.sans(13))
                                .foregroundStyle(Color.recordMuted)
                        }
                        Spacer()

                        // streak (neutral tone on others' profiles)
                        if streak.effectiveCount > 0 {
                            HStack(spacing: 4) {
                                Text("\(streak.effectiveCount)")
                                    .font(.display(17, .extraBold))
                                    .foregroundStyle(isMe ? streakNumberColor : Color.recordText)
                                Text("DAY STREAK")
                                    .font(.sans(9.5, .medium))
                                    .tracking(1)
                                    .foregroundStyle(Color.recordMuted)
                            }
                        }
                    }
                    .padding(.top, 8)

                    // SETTINGS / LOG OUT (my profile only)
                    if isMe {
                        HStack(spacing: 20) {
                            Text("SETTINGS")
                                .font(.sans(11, .medium))
                                .tracking(1)
                                .foregroundStyle(Color.recordDim)
                            Button {
                                Task { await logOut() }
                            } label: {
                                Text("LOG OUT")
                                    .font(.sans(11, .medium))
                                    .tracking(1)
                                    .foregroundStyle(Color.recordDim)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 10)
                    }

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
                
                // cover art
                AsyncImage(url: URL(string: post.album_art_url)) { image in
                    image.resizable()
                } placeholder: {
                    Color.recordSurface
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                
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
                .select("current_streak, last_post_date, longest_streak")
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
        } catch {
            print("Profile load failed: \(error)")
        }
        loading = false
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
}

struct ProfileFullRow: Decodable {
    let current_streak: Int
    let last_post_date: String?
    let longest_streak: Int
}
