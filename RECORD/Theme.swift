//
//  Theme.swift
//  RECORD
//
//  Created by Amir Rashidov on 22.06.2026.
//
//  Design tokens — transcribed from "RECORD — Build Spec" §1.
//  If a colour is not in this file, it does not go in the app.
//

import SwiftUI

// MARK: - Hex helper

extension Color {
    /// Color(hex: 0xFF2D95) — matches the spec's notation one-to-one.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Colour tokens

extension Color {

    // Surfaces
    static let recordBG          = Color(hex: 0x0b0b0b)  // page
    nonisolated static let recordCardTop     = Color(hex: 0x151515)  // card gradient top
    nonisolated static let recordCardBottom  = Color(hex: 0x101010)  // card gradient bottom
    static let recordCardBorder  = Color(hex: 0x232323)  // card hairline
    static let recordSeparator   = Color(hex: 0x1c1c1c)  // between list rows
    static let recordRule        = Color(hex: 0x1d1d1d)  // section header rules

    // Avatars / inert chips — never accent (spec §2)
    static let recordAvatarFill   = Color(hex: 0x141414)
    static let recordAvatarBorder = Color(hex: 0x262626)

    // Text
    static let recordText       = Color(hex: 0xf2f1ee)  // body, titles
    static let recordDisplay    = Color(hex: 0xf4f3f0)  // serif headings, numerals
    static let recordSecondary  = Color(hex: 0x9a9a9a)  // subtitles, artist names
    static let recordTertiary   = Color(hex: 0x6a6a66)  // uppercase labels
    static let recordFaint      = Color(hex: 0x55554f)  // least-important meta
    static let recordDot        = Color(hex: 0x393936)  // the · in meta lines

    // Accent — spec §2. At most TWO accent elements per screen.
    static let recordAccent       = Color(hex: 0xFF2D95)
    static let recordAccentDark   = Color(hex: 0xB00A5F)  // pressed
    static let recordInk          = Color(hex: 0x16000B)  // text on accent fills
    static let recordAccentBright = Color(hex: 0xFFEAF3)  // active streak numeral, my reaction
    static let recordAccentMid    = Color(hex: 0xFF8FBF)  // active streak label, "connected"

    // Streak — at risk
    static let recordCaution     = Color(hex: 0xF2C14E)
    static let recordCautionDim  = Color(hex: 0x9A7B33)

    // Destructive
    static let recordDestructive = Color(hex: 0xc25f5f)
    
    static let recordNote = Color( red: 0.714, green: 0.710, blue: 0.690)
    
    static let recordArtist   = Color(red: 0.604, green: 0.604, blue: 0.604)  // #9a9a9a
    static let recordNoteRule = Color(red: 0.165, green: 0.165, blue: 0.165)  // #2a2a2a
    
    static let recordDanger = Color(red: 1.0, green: 0.23, blue: 0.19)  // #FF3B30
}

// MARK: - Gradients

extension LinearGradient {
    /// Raised card fill — spec §1.
    static let recordCard = LinearGradient(
        colors: [.recordCardTop, .recordCardBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Deprecated aliases
//
// Keeps the v1 screens compiling while we rewrite them one at a time. Xcode
// shows a warning with a one-click fix-it at every call site — clear them as
// you touch each screen, then delete this section.
//
// Values are unchanged except where noted.

extension Color {
    @available(*, deprecated, renamed: "recordSeparator")
    static let recordSurface = Color.recordSeparator          // #1c1c1c — same

    @available(*, deprecated, renamed: "recordCardBorder")
    static let recordSurface2 = Color.recordCardBorder        // #242424 → #232323

    @available(*, deprecated, renamed: "recordSecondary")
    static let recordMuted = Color.recordSecondary            // #8a8a8a → #8a8a86

    @available(*, deprecated, renamed: "recordTertiary")
    static let recordDim = Color.recordTertiary               // #6f6f6f → #6a6a66

    @available(*, deprecated, renamed: "recordDestructive")
    static let recordError = Color.recordDestructive
}

// MARK: - Type

extension Font {
    /// Spectral — display / titles. Weights 700, 800.
    static func display(_ size: CGFloat, _ weight: Spectral = .bold) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: .body)
    }
    enum Spectral: String {
        case bold      = "Spectral-Bold"       // 700
        case extraBold = "Spectral-ExtraBold"  // 800
    }

    /// Geist — UI / body.
    static func sans(_ size: CGFloat, _ weight: Geist = .regular) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: .body)
    }
    enum Geist: String {
        case regular = "Geist-Regular"  // 400
        case medium  = "Geist-Medium"   // 500
        case bold    = "Geist-Bold"     // 700
    }
    
    static func displayItalic(_ size: CGFloat) -> Font {
        .custom("Spectral-Italic", size: size, relativeTo: .body)
    }
}
