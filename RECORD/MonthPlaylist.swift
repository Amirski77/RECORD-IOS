//
//  MonthPlaylist.swift
//  RECORD
//
//  One playlist per calendar month, built from that month's posts. Synced
//  automatically after each post (PostConfirmView) and on demand from a
//  button on the diary (ProfileView) — both call the same edge function,
//  which does a full idempotent replace rather than an append.
//

import Foundation
import Supabase

/// "YYYY-MM" for a date, UTC — matches the app's UTC day boundary
/// (Streak.swift, PostConfirmView.swift) so a post always lands in the
/// month its own dateline says it does.
func monthKey(for date: Date = Date()) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let comps = cal.dateComponents([.year, .month], from: date)
    return String(format: "%04d-%02d", comps.year!, comps.month!)
}

/// Same key, parsed from a post's `created_at` (e.g. "2026-07-14T13:00:00+00:00").
func monthKey(fromCreatedAt createdAt: String) -> String? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = f.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) else {
        return nil
    }
    return monthKey(for: date)
}

private nonisolated struct PlaylistSyncResponse: Decodable {
    let playlist_url: String?
}

/// Builds/updates the playlist for `month` ("YYYY-MM"). Returns the
/// playlist URL on success. Failure (not connected, no matched tracks,
/// network) is swallowed — a playlist sync must never surface as a posting
/// error, so callers that don't care can just ignore the result.
func syncMonthPlaylist(month: String) async -> String? {
    do {
        let response: PlaylistSyncResponse = try await supabase.functions.invoke(
            "spotify-playlist",
            options: FunctionInvokeOptions(body: ["month": month])
        )
        return response.playlist_url
    } catch {
        AppLog.quiet("playlist sync", error)
        return nil
    }
}

private struct MonthPlaylistRow: Decodable {
    let month: String
    let playlist_url: String
}

/// [month: playlistURL] for the signed-in user, to drive "Open playlist"
/// vs "Create playlist" on each diary month header.
func fetchMonthPlaylists() async -> [String: String] {
    do {
        let userID = try await supabase.auth.session.user.id
        let rows: [MonthPlaylistRow] = try await supabase
            .from("month_playlists")
            .select("month, playlist_url")
            .eq("user_id", value: userID)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.month, $0.playlist_url) })
    } catch {
        AppLog.quiet("month playlists load", error)
        return [:]
    }
}
