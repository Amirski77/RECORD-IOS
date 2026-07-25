//
//  Feed.swift
//  RECORD
//
//  Created by Amir Rashidov on 02.07.2026.
//

import Foundation
import Supabase

func fetchTodayFeed() async -> [FeedPost] {
    // Start of today, in UTC
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(identifier: "UTC")!
    let startOfDayUTC = utcCalendar.startOfDay(for: Date())
    let iso = ISO8601DateFormatter().string(from: startOfDayUTC)

    do {
        let posts: [FeedPost] = try await supabase
            .from("posts")
            .select("id, user_id, track_name, artist_name, album_art_url, preview_url, apple_music_url, spotify_url, note, created_at, profiles(username)")
            .gte("created_at", value: iso) // today only
            .order("created_at", ascending: false) // newest first
            .execute()
            .value
        return posts
    } catch {
        print("Feed load failed: \(error)")
        return []
    }
}
