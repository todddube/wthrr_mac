// RetroPalette.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Retro palette

/// A fixed, NES-flavoured colour set. Every retro renderer draws only from these
/// entries (plus the user's AI Storm palette), which is what keeps the scenes
/// reading as one console rather than seven unrelated pixel styles.
enum RetroPalette {
    static let white      = Color(red: 0.99, green: 0.99, blue: 0.99)
    static let ice        = Color(red: 0.74, green: 0.91, blue: 0.99)
    static let sky        = Color(red: 0.24, green: 0.74, blue: 0.99)
    static let blue       = Color(red: 0.00, green: 0.47, blue: 0.97)
    static let navy       = Color(red: 0.00, green: 0.25, blue: 0.53)
    static let lightGray  = Color(red: 0.74, green: 0.74, blue: 0.74)
    static let gray       = Color(red: 0.47, green: 0.47, blue: 0.47)
    static let darkGray   = Color(red: 0.27, green: 0.27, blue: 0.30)
    static let yellow     = Color(red: 0.97, green: 0.85, blue: 0.47)
    static let gold       = Color(red: 0.97, green: 0.72, blue: 0.00)
    static let orange     = Color(red: 0.97, green: 0.47, blue: 0.09)
    static let red        = Color(red: 0.85, green: 0.16, blue: 0.00)
    static let green      = Color(red: 0.36, green: 0.86, blue: 0.29)
    static let mint       = Color(red: 0.35, green: 0.97, blue: 0.60)
    static let teal       = Color(red: 0.00, green: 0.66, blue: 0.66)
    static let purple     = Color(red: 0.53, green: 0.24, blue: 0.97)
    static let magenta    = Color(red: 0.97, green: 0.47, blue: 0.97)
    static let black      = Color(red: 0.05, green: 0.05, blue: 0.08)

    /// Pixel sizes offered in Settings, in points per retro pixel.
    static let pixelSizeOptions = [3, 4, 6, 8]

    /// Friendly name for a pixel size.
    static func pixelSizeLabel(_ size: Int) -> String {
        switch size {
        case ..<4: return "Fine"
        case 4:    return "Classic"
        case ..<8: return "Chunky"
        default:   return "Huge"
        }
    }

    /// The palette's chromatic entries in hue order, for `nearest(hue:fallback:)`.
    private static let ring: [Color] = [red, orange, gold, yellow, green, mint, teal, sky, blue, purple, magenta]

    /// Snaps a user hue (0–1, or -1 for default) to the nearest palette entry so
    /// tinted retro scenes stay inside the console's colour budget.
    static func nearest(hue: Double, fallback: Color) -> Color {
        guard hue >= 0 else { return fallback }
        let idx = Int((hue * Double(ring.count)).rounded()) % ring.count
        return ring[idx]
    }
}

// MARK: - Sprite sheet

/// All retro bitmaps live here. Digits are ink slots; `.` is transparent.
enum RetroSprites {

    // Snow — three sizes mirroring the dot / star / dendrite crystal shapes.
    static let flakeSmall = PixelSprite([
        "1",
    ])
    static let flakeStar = PixelSprite([
        ".1.",
        "121",
        ".1.",
    ])
    static let flakeDendrite = PixelSprite([
        "1.1.1",
        ".121.",
        "12221",
        ".121.",
        "1.1.1",
    ])

    // Birds — two-frame flap, the classic "M" and "V" pair.
    static let birdUp = PixelSprite([
        "1.....1",
        ".1...1.",
        "..1.1..",
        "...1...",
    ])
    static let birdDown = PixelSprite([
        "...1...",
        "..1.1..",
        ".1...1.",
        "1.....1",
    ])

    // AI Storm — space invaders, two animation frames each.
    static let invaderA1 = PixelSprite([
        "..1.....1..",
        "...1...1...",
        "..1111111..",
        ".11.111.11.",
        "11111111111",
        "1.1111111.1",
        "1.1.....1.1",
        "...11.11...",
    ])
    static let invaderA2 = PixelSprite([
        "..1.....1..",
        "1..1...1..1",
        "1.1111111.1",
        "111.111.111",
        "11111111111",
        ".111111111.",
        "..1.....1..",
        ".1.......1.",
    ])
    static let invaderB1 = PixelSprite([
        "...11...",
        "..1111..",
        ".111111.",
        "11.11.11",
        "11111111",
        "..1..1..",
        ".1.11.1.",
        "1.1..1.1",
    ])
    static let invaderB2 = PixelSprite([
        "...11...",
        "..1111..",
        ".111111.",
        "11.11.11",
        "11111111",
        ".1.11.1.",
        "1......1",
        ".1....1.",
    ])

    // AI Storm glitch fragments.
    static let bracket = PixelSprite([
        "1..",
        ".1.",
        "..1",
        ".1.",
        "1..",
    ])
    static let slash = PixelSprite([
        "..1",
        ".1.",
        "1..",
    ])

    // Clear Skies — a twinkling four-point star, in two frames.
    static let starBig = PixelSprite([
        ".1.",
        "121",
        ".1.",
    ])
    static let starSmall = PixelSprite([
        "1",
    ])
}
