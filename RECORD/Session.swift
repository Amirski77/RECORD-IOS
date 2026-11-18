//
//  Session.swift
//  RECORD
//
//  Who is logged in. Created once in RootView, shared by every tab.
//
//  Deliberately small: identity only. Streaks live in ContentView, posts live
//  in ProfileView. This holds the things more than one tab needs.
//

import Foundation
import SwiftUI
import Supabase
import Combine

@MainActor
final class Session: ObservableObject {
    @Published var userID: String = ""
    @Published var username: String = ""
    @Published var avatarURL: String?

    private nonisolated struct Row: Decodable {
        let username: String
        let avatar_url: String?
    }

    // Reads the signed-in user's id from the local auth session, then their
    // profile row. Safe to call more than once.
    func refresh() async {
        do {
            let uid = try await supabase.auth.session.user.id
            userID = uid.uuidString.lowercased()

            let row: Row = try await supabase
                .from("profiles")
                .select("username, avatar_url")
                .eq("id", value: uid)
                .single()
                .execute()
                .value

            username = row.username
            avatarURL = row.avatar_url
        } catch {
            AppLog.loud("session refresh", error, say: "Couldn't load your account. Pull to retry.")
        }
    }

    func clear() {
        userID = ""
        username = ""
        avatarURL = nil
    }
}
