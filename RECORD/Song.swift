//
//  Song.swift
//  RECORD
//
//  Created by Amir Rashidov on 29.06.2026.
//

import Foundation

struct Song: Identifiable, Codable, Hashable {
    let id: Int
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let previewUrl: String?
    let trackViewUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case trackName
        case artistName
        case artworkUrl100
        case previewUrl
        case trackViewUrl
    }
}

struct iTunesResponse: Codable {
    let results: [Song]
    
}
