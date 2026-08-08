// BirdRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Bird renderer

/// Draws animated silhouette birds drifting across the sky.
///
/// All positions, speeds, and wing angles are derived purely from `time` plus the bird
/// index — there is no persistent bird state to simulate, so this renderer is safe to
/// call from any scene. Shared by Aurora (pale birds against the night sky) and
/// Clear Skies (dark silhouettes against daylight).
enum BirdRenderer {

    /// Renders a flock of flapping birds.
    ///
    /// - Parameters:
    ///   - context:   Canvas graphics context to draw into.
    ///   - size:      Full canvas size in points.
    ///   - time:      Elapsed animation time in seconds; drives drift and wing flap.
    ///   - count:     Number of birds to render (0 = off).
    ///   - sizeScale: Global size multiplier (0.5 tiny → 3.0 huge). 1.0 ≈ 28 pt wingspan.
    ///   - wildness:  Variation factor (0 = uniform flock, 1 = chaotic scatter).
    ///   - color:     Silhouette colour.
    ///   - opacity:   Final stroke opacity.
    ///   - bandTop:   Top of the vertical band birds occupy, as a fraction of height.
    ///   - bandDepth: Height of that band, as a fraction of screen height.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        time: CGFloat,
        count: Int,
        sizeScale: Double,
        wildness: Double,
        color: Color,
        opacity: Double,
        bandTop: Double = 0.03,
        bandDepth: Double = 0.15
    ) {
        guard count > 0, opacity > 0.005 else { return }

        // Base half-wingspan in points — "size 1.0" gives ~14 pt half = 28 pt full wingspan
        let baseHalf: CGFloat = 14.0

        var ctx = context
        ctx.opacity = opacity

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

            // Y position within the configured band; wildness spreads birds across more of it
            let yBase = bandTop + h2 * (bandDepth + wildness * 0.10)
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

            ctx.stroke(path, with: .color(color), lineWidth: max(1.0, halfSpan * 0.10))
        }
    }
}
