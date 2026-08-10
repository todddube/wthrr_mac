// AuroraRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Aurora renderer

/// Draws slow-rippling vertical aurora bands across the full screen,
/// plus animated silhouette birds whose count, size, and wildness are user-configurable.
enum AuroraRenderer {

    // MARK: - Palette

    /// Number of aurora bands drawn across the screen.
    private static let bandCount = 5

    /// Band colours. Constant, so the gradients built from them are too.
    private static let bandColors: [Color] = [
        Color(red: 0.1, green: 0.9, blue: 0.4),   // green
        Color(red: 0.2, green: 0.6, blue: 0.9),   // teal
        Color(red: 0.5, green: 0.2, blue: 0.9),   // purple
        Color(red: 0.1, green: 0.8, blue: 0.6),   // aqua
        Color(red: 0.3, green: 0.9, blue: 0.3),   // bright green
    ]

    /// Horizontal core gradient for each band.
    private static let hGradients: [Gradient] = bandColors.map { color in
        Gradient(colors: [
            color.opacity(0), color.opacity(0.4), color.opacity(0.7),
            color.opacity(0.4), color.opacity(0),
        ])
    }

    /// Vertical falloff gradient for each band.
    private static let vGradients: [Gradient] = bandColors.map { color in
        Gradient(colors: [
            .clear, color.opacity(0.3), color.opacity(0.5), color.opacity(0.2), .clear,
        ])
    }

    // MARK: - Aurora bands + birds

    /// Renders five animated aurora bands and optional birds.
    ///
    /// - Parameters:
    ///   - context:          The Canvas graphics context to draw into.
    ///   - size:             Full canvas size in points.
    ///   - isDark:           Dark mode flag — light mode dims bands at 0.6×.
    ///   - time:             Elapsed animation time in seconds.
    ///   - particleOpacity:  Global opacity multiplier from `WeatherSettings`.
    ///   - birdCount:        Number of birds (0 = none). Default 8.
    ///   - birdSize:         Bird size multiplier. Default 1.0.
    ///   - birdWildness:     Bird variation (0 uniform → 1 chaotic). Default 0.4.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        time: CGFloat,
        particleOpacity: Double = 1.0,
        birdCount: Int = 8,
        birdSize: Double = 1.0,
        birdWildness: Double = 0.4
    ) {
        for i in 0..<Self.bandCount {
            let phase = CGFloat(i) * 1.3 + time * 0.15
            let xCenter = size.width * (0.15 + CGFloat(i) * 0.18) + sin(phase) * size.width * 0.08
            let bandWidth = size.width * CGFloat(0.12 + 0.06 * sin(phase * 0.7))
            let bandHeight = size.height * CGFloat(0.4 + 0.2 * sin(phase * 0.5 + 1.0))
            let yOffset = size.height * CGFloat(0.05 + 0.1 * sin(phase * 0.3))

            let rect = CGRect(x: xCenter - bandWidth / 2, y: yOffset,
                              width: bandWidth, height: bandHeight)
            let path = Path(rect)

            var ctx = context
            let opacity = (0.08 + 0.06 * sin(phase * 0.9)) * particleOpacity
            ctx.opacity = isDark ? opacity : opacity * 0.6

            ctx.fill(path, with: .linearGradient(
                Self.hGradients[i],
                startPoint: CGPoint(x: xCenter - bandWidth / 2, y: yOffset),
                endPoint: CGPoint(x: xCenter + bandWidth / 2, y: yOffset)))

            ctx.fill(path, with: .linearGradient(
                Self.vGradients[i],
                startPoint: CGPoint(x: xCenter, y: yOffset),
                endPoint: CGPoint(x: xCenter, y: yOffset + bandHeight)))
        }

        // Pale birds read as distant silhouettes against the night sky.
        BirdRenderer.draw(
            context: context, size: size, time: time,
            count: birdCount, sizeScale: birdSize, wildness: birdWildness,
            color: .white,
            opacity: particleOpacity * (isDark ? 0.60 : 0.35)
        )
    }
}
