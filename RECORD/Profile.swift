//
//  Profile.swift
//  RECORD
//
//  Created by Amir Rashidov on 18.07.2026.
//

import Foundation
import Supabase

func fetchUserPosts(userID: String) async -> [FeedPost] {
    print("Fetching posts for userID: \(userID)")
    do {
        let posts: [FeedPost] = try await supabase
            .from("posts")
            .select("id,user_id, track_name, artist_name, album_art_url, preview_url, apple_music_url, note, created_at, profiles(username)")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
        print("Got \(posts.count) posts")
        return posts
    } catch {
        print("User posts load failed: \(error)")
        return []
    }
}
