//
//  TodayFeedItem.swift
//  RECORD
//
//  Created by Amir Rashidov on 12.08.2026.
//  A row from the today_feed() function.
//
//  Every track field is optional because the server sends null for them until
//  you've posted. That's not defensive coding — it's the lock itself. FeedPost
//  can't be used here: its track_name is non-optional and would fail to decode
//  a locked row outright.
//

import Foundation

struct TodayFeedItem: Identifiable, Decodable {
    let id: Int
    let user_id: String
    let username: String
    let avatar_url: String?

    // nil when locked
    let track_name: String?
    let artist_name: String?
    let album_art_url: String?
    let preview_url: String?
    let apple_music_url: String?
    let spotify_url: String?
    let note: String?

    let created_at: String
    let locked: Bool

    var isMine: Bool = false   // set after load, see Feed.swift

    enum CodingKeys: String, CodingKey {
        case id, user_id, username, avatar_url
        case track_name, artist_name, album_art_url, preview_url
        case apple_music_url, spotify_url, note, created_at, locked
    }
}
