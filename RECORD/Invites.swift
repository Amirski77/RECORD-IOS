//
//  Invites.swift
//  RECORD
//
//  Invite links. Sending someone your link is the consent — redeeming it
//  connects both sides immediately, with no pending step.
//

import Foundation
import Supabase

/// Your personal invite code. Created on first call, stable after that.
func fetchMyInviteCode() async -> String? {
    do {
        return try await supabase
            .rpc("my_invite_code")
            .execute()
            .value
    } catch {
        await AppLog.loud("invite code", error, say: "Couldn't create your invite link.")
        return nil
    }
}

struct RedeemResult: nonisolated Decodable {
    let ok: Bool
    let username: String?
    let reason: String?

    /// What to tell the person who tapped the link.
    var message: String {
        if ok, let username {
            return "You and \(username) are now connected."
        }
        switch reason {
        case "self":      return "That's your own invite link."
        case "not_found": return "That invite link isn't valid anymore."
        default:          return "Couldn't open that invite. Try again."
        }
    }
}

func redeemInvite(code: String) async -> RedeemResult {
    do {
        return try await supabase
            .rpc("redeem_invite", params: ["invite_code": code])
            .execute()
            .value
    } catch {
        AppLog.quiet("invite redeem", error)
        return RedeemResult(ok: false, username: nil, reason: nil)
    }
}

func inviteURL(for code: String) -> URL? {
    URL(string: "https://recordapp.live/i/\(code)")
}
