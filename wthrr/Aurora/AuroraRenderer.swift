// AuroraRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Aurora renderer

/// Draws slow-rippling vertical aurora bands across the full screen.
/// Pure gradient animation — no particle physics needed.
enum AuroraRenderer {
    /// Renders five animated aurora bands using layered linear gradients driven by elapsed time.
    ///
    /// Each band oscillates in position, width, and height using independent sine phases so
    /// the bands drift organically rather than moving in lockstep. Two gradient passes are
    /// composited per band — a horizontal pass for lateral fade and a vertical pass for
    /// the characteristic curtain shape:
    ///   - Horizontal gradient: fades the band's intensity from its edges to transparent.
    ///   - Vertical gradient: creates the aurora "curtain" effect — bright mid-screen,
    ///     fading toward the horizon at the bottom.
    ///
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points.
    ///   - isDark: Whether the system is in dark mode (light-mode dimming applied at 0.6×).
    ///   - time: Elapsed animation time in seconds, advanced each frame by `WeatherAnimationModel`.
    ///   - particleOpacity: Global opacity multiplier from `WeatherSettings`.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        time: CGFloat,
        particleOpacity: Double = 1.0
    ) {
        let bandCount = 5
        // Each band gets a unique hue to produce the classic green-teal-purple aurora palette
        let colors: [Color] = [
            Color(red: 0.1, green: 0.9, blue: 0.4),   // green
            Color(red: 0.2, green: 0.6, blue: 0.9),   // teal
            Color(red: 0.5, green: 0.2, blue: 0.9),   // purple
            Color(red: 0.1, green: 0.8, blue: 0.6),   // aqua
            Color(red: 0.3, green: 0.9, blue: 0.3),   // bright green
        ]

        for i in 0..<bandCount {
            // Each band has a unique phase offset so they drift at different rates
            let phase = CGFloat(i) * 1.3 + time * 0.15
            // Horizontal centre oscillates gently ±8% of screen width
            let xCenter = size.width * (0.15 + CGFloat(i) * 0.18) + sin(phase) * size.width * 0.08
            // Width breathes between 12% and 18% of screen width
            let bandWidth = size.width * CGFloat(0.12 + 0.06 * sin(phase * 0.7))
            // Height breathes between 40% and 60% of screen height
            let bandHeight = size.height * CGFloat(0.4 + 0.2 * sin(phase * 0.5 + 1.0))
            // Top edge drifts vertically between 5% and 15% from the top
            let yOffset = size.height * CGFloat(0.05 + 0.1 * sin(phase * 0.3))

            let rect = CGRect(x: xCenter - bandWidth / 2, y: yOffset,
                               width: bandWidth, height: bandHeight)

            var ctx = context
            // Base opacity breathes between 0.08 and 0.14; dimmed further in light mode
            let opacity = (0.08 + 0.06 * sin(phase * 0.9)) * particleOpacity
            ctx.opacity = isDark ? opacity : opacity * 0.6

            let color = colors[i % colors.count]
            // Horizontal gradient: transparent → peak → transparent across the band width
            let gradient = Gradient(colors: [
                color.opacity(0),
                color.opacity(0.4),
                color.opacity(0.7),
                color.opacity(0.4),
                color.opacity(0)
            ])

            // First pass: horizontal lateral fade
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: xCenter - bandWidth / 2, y: yOffset),
                    endPoint: CGPoint(x: xCenter + bandWidth / 2, y: yOffset)
                )
            )

            // Second pass: vertical curtain fade — bright in the middle, clear at top and bottom
            let vGradient = Gradient(colors: [
                .clear,
                color.opacity(0.3),
                color.opacity(0.5),
                color.opacity(0.2),
                .clear
            ])
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    vGradient,
                    startPoint: CGPoint(x: xCenter, y: yOffset),
                    endPoint: CGPoint(x: xCenter, y: yOffset + bandHeight)
                )
            )
        }
    }
}
