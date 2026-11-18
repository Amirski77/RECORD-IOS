//
//  Reaction.swift
//  RECORD
//
//  Created by Amir Rashidov on 08.07.2026.
//

import Foundation
import Supabase

struct Reaction: Decodable {
    let post_id: Int
    let user_id: String
    let type: String
}

// Payload for inserting a new reaction (Encodable for Supabase insert).
struct NewReaction: Encodable {
    let post_id: Int
    let user_id: String
    let type: String
}

func fetchReactions(postIDs: [Int]) async -> [Reaction] {
    // No posts> No reaction to fetch
    guard !postIDs.isEmpty else { return [] }
    
    do {
        let reactions: [Reaction] = try await supabase
            .from("reactions")
            .select("post_id, user_id, type")
            .in("post_id", values: postIDs)
            .execute()
            .value
        return reactions
    } catch is CancellationError {
        return []
    } catch {
        AppLog.quiet("reactions load", error)
        return []
    }
}

// Turn a flat list of reactions into: counts per post per type.
// Shape: [postID: [type: count]]  e.g. [42: ["fire": 3, "heart": 1]]
func countReactions(_ reactions: [Reaction]) -> [Int: [String: Int]] {
    var counts: [Int: [String: Int]] = [:]
    for r in reactions {
        counts[r.post_id, default: [:]][r.type, default: 0] += 1
    }
    return counts
}

// Map a reaction type to the emoji shown in the UI.
func emoji(for type: String) -> String {
    switch type {
    case "fire": return "🔥"
    case "heart": return "❤️"
    case "sleepy": return "😴"
    case "poop": return "💩"
    default: return "❓"
    }
}

// Find MY reaction on each post: [postID: myType]  e.g. [42: "fire"]
func myReactions(_ reactions: [Reaction], myUserID: String) -> [Int: String] {
    var mine: [Int: String] = [:]
    for r in reactions where r.user_id == myUserID {
        mine[r.post_id] = r.type
    }
    return mine
}
