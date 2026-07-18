//
//  FeedPost.swift
//  RECORD
//

import Foundation

struct FeedPost: Identifiable, Decodable {
    let id: Int              // the post's own id (bigint)
    let user_id: String
    let track_name: String
    let artist_name: String
    let album_art_url: String
    let preview_url: String?
    let apple_music_url: String?
    let note: String?
    let created_at: String
    let profiles: Poster     // ← the "who posted it" — explained below

    // This is the one twist. Because posts has a foreign key to profiles,
    // Supabase can hand us the poster's profile *nested inside* each post.
    // So we make a tiny box for just the part we need: their username.
    struct Poster: Decodable {
        let username: String
    }
}
