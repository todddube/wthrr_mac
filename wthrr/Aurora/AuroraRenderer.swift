// AuroraRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Aurora renderer

/// Draws slow-rippling vertical aurora bands across the full screen,
/// plus animated silhouette birds whose count, size, and wildness are user-configurable.
enum AuroraRenderer {

    // MARK: - Birds

    /// Draws animated silhouette birds drifting across the aurora sky.
    /// All positions, speeds, and wing angles are derived purely from `time` + bird index —
    /// no persistent state required.
    ///
    /// - Parameters:
    ///   - count:     Number of birds to render (0 = off).
    ///   - sizeScale: Global size multiplier (0.5 tiny → 3.0 huge). Default 1.0 ≈ 28 pt wingspan.
    ///   - wildness:  Variation factor (0 = uniform flock, 1 = chaotic scatter).
    private static func drawBirds(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        time: CGFloat,
        particleOpacity: Double,
        count: Int,
        sizeScale: Double,
        wildness: Double
    ) {
        guard count > 0 else { return }

        let baseOpacity = particleOpacity * (isDark ? 0.60 : 0.35)
        // Base half-wingspan in points — "size 1.0" gives ~14 pt half = 28 pt full wingspan
        let baseHalf: CGFloat = 14.0

        for i in 0..<count {
            // Deterministic per-bird seeds using multiples of irrational constants
            let fi = Double(i)
            let h1 = (fi * 137.508).truncatingRemainder(dividingBy: 1.0)   // golden angle frac
            let h2 = (fi * 97.0 + 17.3).truncatingRemainder(dividingBy: 100.0) / 100.0
            let h3 = (fi * 61.0 + 5.7).truncatingRemainder(dividingBy: 100.0) / 100.0
            let h4 = (fi * 173.0 + 3.1).truncatingRemainder(dividingBy: 100.0) / 100.0
            let h5 = (fi * 43.0 + 11.9).truncatingRemainder(dividingBy: 100.0) / 100.0

            // Horizontal speed: 0.010–0.024 screen-widths/sec; wildness widens the spread
            let speedBase = 0.012 + h2 * 0.012
            let speed = CGFloat(speedBase * (1.0 + wildness * (h3 - 0.5) * 0.8))

            // Flap rate: 2.4–3.8 rad/sec base; wildness adds scatter
            let flapBase = 2.4 + h3 * 1.4
            let flapSpeed = CGFloat(flapBase + wildness * (h4 - 0.5) * 1.6)

            // Phase offset so birds don't flap in sync
            let phase = CGFloat(h1 * .pi * 2)

            // Per-bird size: wildness drives variation between 0.55× and 1.6× of sizeScale
            let sizeVar = wildness > 0
                ? (0.55 + h5 * 1.05) * wildness + 1.0 * (1.0 - wildness)
                : 1.0
            let halfSpan = baseHalf * CGFloat(sizeScale * sizeVar)

            // Y position: upper 25% of screen; wildness spreads birds across more of that band
            let yBase = 0.03 + h2 * (0.15 + wildness * 0.10)
            let y = CGFloat(yBase) * size.height
                  + sin(time * 0.22 + phase) * size.height * 0.010

            // X position: drift left→right, wrap with small off-screen buffer
            let startX = CGFloat(h1) * size.width
            let x = (startX + speed * size.width * time)
                .truncatingRemainder(dividingBy: size.width + halfSpan * 2) - halfSpan

            // Wing lift: sine flap
            let wh = halfSpan * 0.55 * sin(time * flapSpeed + phase)

            // Two quad-curve strokes forming a "M" wing silhouette
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x - halfSpan, y: y - halfSpan * 0.25),
                control: CGPoint(x: x - halfSpan * 0.48, y: y - halfSpan * 0.55 + wh)
            )
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x + halfSpan, y: y - halfSpan * 0.25),
                control: CGPoint(x: x + halfSpan * 0.48, y: y - halfSpan * 0.55 + wh)
            )

            var ctx = context
            ctx.opacity = baseOpacity
            let lineW = max(1.0, halfSpan * 0.10)
            ctx.stroke(path, with: .color(.white), lineWidth: lineW)
        }
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
        let bandCount = 5
        let colors: [Color] = [
            Color(red: 0.1, green: 0.9, blue: 0.4),   // green
            Color(red: 0.2, green: 0.6, blue: 0.9),   // teal
            Color(red: 0.5, green: 0.2, blue: 0.9),   // purple
            Color(red: 0.1, green: 0.8, blue: 0.6),   // aqua
            Color(red: 0.3, green: 0.9, blue: 0.3),   // bright green
        ]

        for i in 0..<bandCount {
            let phase = CGFloat(i) * 1.3 + time * 0.15
            let xCenter = size.width * (0.15 + CGFloat(i) * 0.18) + sin(phase) * size.width * 0.08
            let bandWidth = size.width * CGFloat(0.12 + 0.06 * sin(phase * 0.7))
            let bandHeight = size.height * CGFloat(0.4 + 0.2 * sin(phase * 0.5 + 1.0))
            let yOffset = size.height * CGFloat(0.05 + 0.1 * sin(phase * 0.3))

            let rect = CGRect(x: xCenter - bandWidth / 2, y: yOffset,
                              width: bandWidth, height: bandHeight)

            var ctx = context
            let opacity = (0.08 + 0.06 * sin(phase * 0.9)) * particleOpacity
            ctx.opacity = isDark ? opacity : opacity * 0.6

            let color = colors[i % colors.count]
            let gradient = Gradient(colors: [
                color.opacity(0),
                color.opacity(0.4),
                color.opacity(0.7),
                color.opacity(0.4),
                color.opacity(0)
            ])
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: xCenter - bandWidth / 2, y: yOffset),
                    endPoint: CGPoint(x: xCenter + bandWidth / 2, y: yOffset)
                )
            )

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

        drawBirds(
            context: context, size: size, isDark: isDark, time: time,
            particleOpacity: particleOpacity,
            count: birdCount, sizeScale: birdSize, wildness: birdWildness
        )
    }
}
