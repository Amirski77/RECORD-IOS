//
//  Feed.swift
//  RECORD
//
//  Created by Amir Rashidov on 02.07.2026.
//

import Foundation
import Supabase

func fetchTodayFeed() async -> [TodayFeedItem] {
    do {
        var items: [TodayFeedItem] = try await supabase
            .rpc("today_feed")
            .execute()
            .value

        // Mark which row is yours so the UI can tell them apart.
        if let me = try? await supabase.auth.session.user.id.uuidString.lowercased() {
            for i in items.indices {
                items[i].isMine = (items[i].user_id == me)
            }
        }

        return items
    } catch is CancellationError {
        return []
    } catch {
        await AppLog.loud("today feed load", error, say: "Couldn't load today's edition. Pull to retry.")
        return []
    }
}
