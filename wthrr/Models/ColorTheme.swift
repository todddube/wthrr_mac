// ColorTheme.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Color theme

/// Resolves user color preferences into concrete SwiftUI colors for renderers.
enum ColorTheme {

    // MARK: Snow colors

    /// Returns the snow particle color based on the user's tint hue and color scheme.
    static func snowColor(tint: Double, isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            // Default: white with subtle blue tint modulation
            if isDark {
                return Color(red: 1.0, green: 1.0 - tint * 0.05, blue: 1.0)
            } else {
                return Color(red: 0.88, green: 0.92 - tint * 0.04, blue: 0.98)
            }
        }
        // Custom hue: tinted snowflakes
        let saturation = isDark ? 0.15 + tint * 0.1 : 0.2 + tint * 0.1
        let brightness = isDark ? 0.95 : 0.85
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Returns the snow drift fill color.
    static func snowDriftColor(isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            return isDark ? Color(white: 0.95) : Color(red: 0.82, green: 0.87, blue: 0.95)
        }
        let saturation = isDark ? 0.08 : 0.12
        let brightness = isDark ? 0.95 : 0.88
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // MARK: Rain colors

    /// Returns the rain streak color.
    static func rainStreakColor(isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            return isDark
                ? Color(red: 0.78, green: 0.88, blue: 1.0)
                : Color(red: 0.55, green: 0.65, blue: 0.80)
        }
        let saturation = isDark ? 0.35 : 0.4
        let brightness = isDark ? 0.92 : 0.72
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Returns the splash ring color.
    static func rainSplashColor(isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            return isDark
                ? Color(red: 0.75, green: 0.88, blue: 1.0)
                : Color(red: 0.50, green: 0.62, blue: 0.78)
        }
        let saturation = isDark ? 0.3 : 0.35
        let brightness = isDark ? 0.9 : 0.7
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Returns the puddle body color.
    static func rainPuddleColor(isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            return isDark
                ? Color(red: 0.30, green: 0.52, blue: 0.82)
                : Color(red: 0.28, green: 0.46, blue: 0.72)
        }
        let saturation = isDark ? 0.55 : 0.5
        let brightness = isDark ? 0.65 : 0.55
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // MARK: AI Storm palettes

    /// Named AI Storm color palettes.
    static let aiStormPaletteNames = ["Cyberpunk", "Synthwave", "Matrix", "Inferno"]

    /// Returns the 4-color palette for the given palette index.
    static func aiStormColors(palette: Int) -> (Color, Color, Color, Color) {
        switch palette {
        case 1: // Synthwave — purple/pink
            return (
                Color(red: 0.6, green: 0.1, blue: 1.0),
                Color(red: 1.0, green: 0.2, blue: 0.6),
                Color(red: 0.4, green: 0.0, blue: 0.9),
                Color(red: 0.9, green: 0.4, blue: 0.8)
            )
        case 2: // Matrix — green
            return (
                Color(red: 0.0, green: 1.0, blue: 0.2),
                Color(red: 0.1, green: 0.8, blue: 0.1),
                Color(red: 0.0, green: 0.6, blue: 0.1),
                Color(red: 0.3, green: 1.0, blue: 0.4)
            )
        case 3: // Inferno — orange/red
            return (
                Color(red: 1.0, green: 0.4, blue: 0.0),
                Color(red: 1.0, green: 0.15, blue: 0.0),
                Color(red: 0.9, green: 0.6, blue: 0.0),
                Color(red: 1.0, green: 0.0, blue: 0.2)
            )
        default: // Cyberpunk — cyan/magenta (original)
            return (
                Color(red: 0.0, green: 0.95, blue: 1.0),
                Color(red: 0.7, green: 0.2, blue: 1.0),
                Color(red: 0.1, green: 1.0, blue: 0.3),
                Color(red: 1.0, green: 0.1, blue: 0.6)
            )
        }
    }

    // MARK: Fog colors

    /// Returns the base fog color.
    static func fogBaseColor(isDark: Bool, hue: Double) -> Color {
        if hue < 0 {
            return isDark ? .white : .gray
        }
        let saturation = isDark ? 0.15 : 0.2
        let brightness = isDark ? 0.9 : 0.65
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
