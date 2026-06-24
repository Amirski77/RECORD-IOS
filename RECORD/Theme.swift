//
//  Theme.swift
//  RECORD
//
//  Created by Amir Rashidov on 22.06.2026.
//

import SwiftUI

extension Color {
    static let recordBG = Color(red: 0.043, green: 0.043, blue: 0.043)   // #0b0b0b
    static let recordSurface = Color(red: 0.11, green: 0.11, blue: 0.11) // #1c1c1c
    static let recordSurface2 = Color(red: 0.14, green: 0.14, blue: 0.14)// #242424
    static let recordGreen = Color(red: 0.12, green: 0.84, blue: 0.38)   // #1ed760
    static let recordText = Color(red: 0.957, green: 0.953, blue: 0.941) // #f4f3f0
    static let recordMuted = Color(red: 0.54, green: 0.54, blue: 0.54)   // #8a8a8a
    static let recordDim = Color(red: 0.435, green: 0.435, blue: 0.435)  // #6f6f6f
}

extension Font {
    // Display — Spectral (serif): titles, names, numbers, headings, wordmark
    static func display(_ size: CGFloat, _ weight: Spectral = .bold) -> Font {
        .custom(weight.rawValue, size: size)
    }
    enum Spectral: String {
        case bold      = "Spectral-Bold"
        case extraBold = "Spectral-ExtraBold"
    }

    // Body — Geist (sans): notes, artists, labels, buttons, meta
    static func body(_ size: CGFloat, _ weight: Geist = .regular) -> Font {
        .custom(weight.rawValue, size: size)
    }
    enum Geist: String {
        case regular = "Geist-Regular"
        case medium  = "Geist-Medium"
        case bold    = "Geist-Bold"
    }
}
