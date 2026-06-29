//
//  SongSearch.swift
//  RECORD
//
//  Created by Amir Rashidov on 29.06.2026.
//

import Foundation

func searchSongs(query: String) async -> [Song] {
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
        return []
    }
    
    var components = URLComponents(string: "https://itunes.apple.com/search")!
    components.queryItems = [
        URLQueryItem(name: "term", value: query),
        URLQueryItem(name: "media", value: "music"),
        URLQueryItem(name: "entity", value: "song"),
        URLQueryItem(name: "limit", value: "25")
    ]
    
    guard let url = components.url else { return [] }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return response.results
    } catch {
        print("Search failed: \(error)")
        return []
    }
}
