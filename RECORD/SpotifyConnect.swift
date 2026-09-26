//
//  SpotifyConnect.swift
//  RECORD
//
//  Links a Spotify account to an already-logged-in RECORD account (this is
//  not a sign-in method — email+password stays the only way into the app).
//  Authorization Code + PKCE: the code-for-token exchange happens in the
//  spotify-connect edge function, so the refresh token never touches the
//  device. This file only carries the code + verifier that far.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

// MARK: - App-side OAuth config
//
// Client ID is a public value (safe to ship); the client secret never
// appears here — PKCE doesn't need it for either the initial exchange or
// later refreshes. Replace with the Client ID from the Spotify Developer
// Dashboard, and register `spotifyRedirectURI` there as a Redirect URI.

let spotifyClientID = "YOUR_SPOTIFY_CLIENT_ID"
let spotifyRedirectURI = "record://spotify-callback"
private let spotifyScopes = "playlist-modify-public playlist-modify-private user-read-private"

// MARK: - PKCE

private struct PKCEPair {
    let verifier: String
    let challenge: String
}

private func base64URLEncode(_ data: Data) -> String {
    Data(data)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func makePKCEPair() -> PKCEPair {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    let verifier = base64URLEncode(Data(bytes))

    let digest = SHA256.hash(data: Data(verifier.utf8))
    let challenge = base64URLEncode(Data(digest))

    return PKCEPair(verifier: verifier, challenge: challenge)
}

private func authorizeURL(challenge: String, state: String) -> URL {
    var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
    components.queryItems = [
        URLQueryItem(name: "client_id", value: spotifyClientID),
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "redirect_uri", value: spotifyRedirectURI),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
        URLQueryItem(name: "code_challenge", value: challenge),
        URLQueryItem(name: "scope", value: spotifyScopes),
        URLQueryItem(name: "state", value: state),
    ]
    return components.url!
}

enum SpotifyConnectError: Error {
    case missingCode
    case stateMismatch
}

nonisolated struct SpotifyConnectResult: Decodable {
    let ok: Bool
    let display_name: String?
    let profile_url: String?
}

/// Runs the whole PKCE dance (browser sheet → code → edge function) and
/// returns who got connected. Throws on cancellation or any failure — the
/// caller decides how to surface that.
@MainActor
func connectSpotify(using session: WebAuthenticationSession) async throws -> SpotifyConnectResult {
    let pkce = makePKCEPair()
    let state = UUID().uuidString

    let callbackURL = try await session.authenticate(
        using: authorizeURL(challenge: pkce.challenge, state: state),
        callbackURLScheme: "record"
    )

    let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
    guard let returnedState = items?.first(where: { $0.name == "state" })?.value,
          returnedState == state else {
        throw SpotifyConnectError.stateMismatch
    }
    guard let code = items?.first(where: { $0.name == "code" })?.value else {
        throw SpotifyConnectError.missingCode
    }

    let result: SpotifyConnectResult = try await supabase.functions.invoke(
        "spotify-connect",
        options: FunctionInvokeOptions(body: [
            "code": code,
            "code_verifier": pkce.verifier,
            "redirect_uri": spotifyRedirectURI,
        ])
    )
    return result
}

func disconnectSpotify() async -> Bool {
    do {
        try await supabase.functions.invoke("spotify-disconnect")
        return true
    } catch {
        print("Spotify disconnect failed: \(error)")
        return false
    }
}
