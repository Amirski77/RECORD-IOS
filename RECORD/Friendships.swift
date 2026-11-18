//
//  Friendships.swift
//  RECORD
//
// //  Created by Amir Rashidov on 10.08.2026.

//  Everything the Friends tab needs to talk to Supabase.
//
//  Reads go through the three database functions (friends_list,
//  friend_requests, search_users) — they do the joins server-side.
//  Writes go straight at the friendships table; RLS decides what's allowed.
//

import Foundation
import Supabase

// MARK: - Models
//
// One struct per function, matching its returns table exactly. Names must match the SQL column names — that's how Decodable finds them.

struct Friend: Identifiable, Decodable {
    let id: String
    let username: String
    let avatar_url: String?
    let current_streak: Int
    let posted_today: Bool
}

struct FriendRequest: Identifiable, Decodable {
    let id: String
    let username: String
    let avatar_url: String?
    let record_count: Int
}

struct UserSearchResult: Identifiable, Decodable {
    let id: String
    let username: String
    let avatar_url: String?
    let status: String       // none | pending_out | pending_in | friends

    /// What the button on this row should say and do.
    enum Relation {
        case none           // "Add"
        case sentByMe       // "Requested" — inert
        case sentToMe       // "Accept"
        case friends        // no button
    }

    var relation: Relation {
        switch status {
        case "pending_out": .sentByMe
        case "pending_in":  .sentToMe
        case "friends":     .friends
        default:            .none
        }
    }
}

// MARK: - Reads

func fetchFriends() async -> [Friend] {
    do {
        return try await supabase
            .rpc("friends_list")
            .execute()
            .value
    } catch {
        await AppLog.loud("friends load", error, say: "Couldn't load your friends. Pull to retry.")
        return []
    }
}

func fetchFriendRequests() async -> [FriendRequest] {
    do {
        return try await supabase
            .rpc("friend_requests")
            .execute()
            .value
    } catch {
        await AppLog.loud("friend requests load", error, say: "Couldn't load friend requests.")
        return []
    }
}

func searchUsers(_ query: String) async -> [UserSearchResult] {
    let q = query.trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return [] }

    do {
        return try await supabase
            .rpc("search_users", params: ["q": q])
            .execute()
            .value
    } catch {
        await AppLog.loud("user search", error, say: "Couldn't search right now.")
        return []
    }
}

// MARK: - Writes
//
// Each returns true on success. The database is the one enforcing the rules
// here — if a write is rejected it's RLS or a constraint doing its job, and
// the printed error tells you which.

private struct NewFriendship: Encodable {
    let requester_id: String
    let addressee_id: String
    let status: String
}

/// Send a friend request. Fails if a row already exists in either direction.
func sendFriendRequest(to userID: String) async -> Bool {
    do {
        let me = try await supabase.auth.session.user.id.uuidString.lowercased()
        try await supabase
            .from("friendships")
            .insert(NewFriendship(requester_id: me,
                                  addressee_id: userID,
                                  status: "pending"))
            .execute()
        return true
    } catch {
        await AppLog.loud("send friend request", error, say: "Couldn't send that request.")
        return false
    }
}

/// Accept a request someone sent me. Only works if I'm the addressee —
/// that's the friendships_update policy, not something checked here.
func acceptFriendRequest(from userID: String) async -> Bool {
    do {
        let me = try await supabase.auth.session.user.id.uuidString.lowercased()
        try await supabase
            .from("friendships")
            .update(["status": "accepted"])
            .eq("requester_id", value: userID)
            .eq("addressee_id", value: me)
            .execute()
        return true
    } catch {
        await AppLog.loud("accept friend request", error, say: "Couldn't accept that request.")
        return false
    }
}

/// Decline, cancel, or unfriend — all the same delete. The other person is
/// never told, because there's no row left to tell them about.
func removeFriendship(with userID: String) async -> Bool {
    do {
        let me = try await supabase.auth.session.user.id.uuidString.lowercased()
        try await supabase
            .from("friendships")
            .delete()
            .or("and(requester_id.eq.\(me),addressee_id.eq.\(userID)),"
              + "and(requester_id.eq.\(userID),addressee_id.eq.\(me))")
            .execute()
        return true
    } catch {
        await AppLog.loud("remove friendship", error, say: "Couldn't remove that friend.")
        return false
    }
}
