//
//  Profile.swift
//  RECORD
//
//  Created by Amir Rashidov on 18.07.2026.
//

import Foundation
import Supabase

func fetchUserPosts(userID: String) async -> [FeedPost] {
    do {
        let posts: [FeedPost] = try await supabase
            .from("posts")
            .select("id,user_id, track_name, artist_name, album_art_url, preview_url, apple_music_url, note, created_at, profiles(username)")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
        return posts
    } catch {
        await AppLog.loud("user posts load", error, say: "Couldn't load records. Pull to retry.")
        return []
    }
}
