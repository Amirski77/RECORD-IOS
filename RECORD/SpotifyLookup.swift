//
//  SpotifyLookup.swift
//  RECORD
//
//  Created by Amir Rashidov on 25.07.2026.
//

import Foundation
import Supabase

struct SpotifyResponse: Decodable {
    let spotify_url: String?
}

func fetchSpotifyURL(track: String, artist: String) async -> String? {
    do {
        let response: SpotifyResponse = try await supabase.functions
            .invoke("spotify-lookup", options: FunctionInvokeOptions(
                body: ["track": track, "artist": artist]
                ))
        return response.spotify_url
    } catch {
        print("Spotify lookup failed: \(error)")
        return nil
    }
}
