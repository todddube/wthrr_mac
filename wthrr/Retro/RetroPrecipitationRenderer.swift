// RetroPrecipitationRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Retro precipitation renderer

/// 8-bit snow and rain: sprite flakes, stepped drift, Bresenham rain streaks,
/// blocky puddles and a pixel lightning bolt.
enum RetroPrecipitationRenderer {

    /// Opacity notches particles are bucketed into. Three is enough to keep depth
    /// (near flakes bright, far flakes dim) without blowing the ink budget.
    private static let opacityLevels: [Double] = [0.45, 0.72, 1.0]

    /// Picks the opacity bucket for a particle's own alpha.
    private static func bucket(_ alpha: Double) -> Int {
        alpha < 0.6 ? 0 : (alpha < 0.8 ? 1 : 2)
    }

    // MARK: Snow

    /// Draws snowflake sprites and the stepped accumulation drift.
    static func drawSnow(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        isDark: Bool,
        particles: [Particle],
        accumulationMap: [CGFloat],
        baselineMap: [CGFloat],
        accumulationEnabled: Bool,
        columnWidth: CGFloat,
        opacity: Double,
        tintHue: Double
    ) {
        let base = RetroPalette.nearest(
            hue: tintHue, fallback: isDark ? RetroPalette.white : RetroPalette.ice)
        let accent = isDark ? RetroPalette.ice : RetroPalette.sky

        var painter = PixelPainter(px: px)
        let mains = opacityLevels.map { painter.ink(base, opacity: min(1, $0 * opacity)) }
        let accents = opacityLevels.map { painter.ink(accent, opacity: min(1, $0 * opacity)) }

        // Sprite ink lists per bucket, built once rather than once per flake.
        let spriteInks = (0..<opacityLevels.count).map { [mains[$0], accents[$0]] }

        for p in particles {
            let b = bucket(p.opacity)
            let inks = spriteInks[b]
            switch p.shape {
            case .dot:
                // The biggest pellets get a 2×2 block so they read as nearer.
                if p.size > 3 {
                    painter.dot(mains[b], x: p.x, y: p.y, w: 2, h: 2)
                } else {
                    painter.sprite(RetroSprites.flakeSmall, x: p.x, y: p.y, inks: inks)
                }
            case .star:
                painter.sprite(RetroSprites.flakeStar, x: p.x, y: p.y, inks: inks)
            case .dendrite:
                painter.sprite(RetroSprites.flakeDendrite, x: p.x, y: p.y, inks: inks)
            }
        }

        // Drift: one stepped column per grid cell, white cap over an icy body.
        if accumulationEnabled, accumulationMap.count > 1, accumulationMap.count == baselineMap.count {
            let body = painter.ink(isDark ? RetroPalette.ice : RetroPalette.lightGray,
                                   opacity: min(1, 0.9 * opacity))
            let cap = painter.ink(RetroPalette.white, opacity: min(1, opacity))
            let cols = Int((size.width / px).rounded(.up))
            let perCell = max(1, Int((px / columnWidth).rounded(.up)))
            for gx in 0..<cols {
                let first = min(accumulationMap.count - 1, Int(CGFloat(gx) * px / columnWidth))
                let last = min(accumulationMap.count - 1, first + perCell - 1)
                var depth: CGFloat = 0
                var ground: CGFloat = 0
                for c in first...last {
                    depth = max(depth, accumulationMap[c])
                    ground = max(ground, baselineMap[c])
                }
                let cellsHigh = Int((depth / px).rounded())
                guard cellsHigh > 0 else { continue }
                let groundCell = painter.grid(ground)
                let top = groundCell - cellsHigh
                painter.cells(cap, gx: gx, gy: top)
                painter.cells(body, gx: gx, gy: top + 1, h: cellsHigh)
            }
        }

        painter.flush(into: context)
    }

    // MARK: Rain

    /// Draws rain streaks, puddles, splashes and the lightning bolt.
    static func drawRain(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        isDark: Bool,
        particles: [Particle],
        splashes: [Splash],
        puddles: [Puddle],
        windVelocity: CGFloat,
        bolt: LightningBolt?,
        opacity: Double,
        tintHue: Double
    ) {
        if let bolt {
            PixelPainter.flash(context: context, size: size, color: RetroPalette.white,
                               opacity: bolt.flashOpacity)
        }

        let streakColor = RetroPalette.nearest(
            hue: tintHue, fallback: isDark ? RetroPalette.ice : RetroPalette.blue)
        let deepColor = RetroPalette.nearest(
            hue: tintHue, fallback: isDark ? RetroPalette.blue : RetroPalette.navy)

        var painter = PixelPainter(px: px)

        // Puddles first so streaks fall in front of them.
        let puddleBody = painter.ink(deepColor, opacity: min(1, 0.75 * opacity))
        let puddleShine = painter.ink(RetroPalette.sky, opacity: min(1, 0.85 * opacity))
        let ripple = painter.ink(RetroPalette.white, opacity: min(1, 0.8 * opacity))
        let groundCell = painter.grid(size.height) // one past the last visible row
        for puddle in puddles where puddle.height > 0.5 {
            let gx0 = painter.grid(puddle.x - puddle.width / 2)
            let w = max(2, Int((puddle.width / px).rounded()))
            let h = max(1, Int((puddle.height * 1.2 / px).rounded()))
            // Puddles taper: each row up is one cell narrower on both ends.
            for row in 0..<h {
                let inset = h - 1 - row
                painter.cells(puddleBody, gx: gx0 + inset, gy: groundCell - h + row,
                              w: max(1, w - inset * 2))
            }
            painter.cells(puddleShine, gx: gx0 + w / 4, gy: groundCell - h, w: max(1, w / 3))
            if puddle.rippleOpacity > 0.15 {
                let r = Int((min(puddle.rippleRadius, puddle.width * 0.42) / px).rounded())
                let mid = gx0 + w / 2
                painter.cells(ripple, gx: mid - r, gy: groundCell - h)
                painter.cells(ripple, gx: mid + r, gy: groundCell - h)
            }
        }

        // Streaks: Bresenham lines, so wind tilt shows up as a classic stair-step.
        let maxTilt: CGFloat = 25 * .pi / 180
        let tilt = CGFloat(atan2(windVelocity * 0.015, 1.0)).clamped(to: -maxTilt...maxTilt)
        let sinT = sin(tilt), cosT = cos(tilt)
        let streaks = opacityLevels.map { painter.ink(streakColor, opacity: min(1, $0 * opacity)) }
        for drop in particles {
            let half = drop.length / 2
            let ink = streaks[bucket(drop.opacity)]
            painter.line(ink,
                         from: CGPoint(x: drop.x - sinT * half, y: drop.y - cosT * half),
                         to: CGPoint(x: drop.x + sinT * half, y: drop.y + cosT * half))
        }

        // Splashes: two droplets hop outward and up as the splash ages.
        let splashInks = opacityLevels.map { painter.ink(RetroPalette.ice, opacity: min(1, $0)) }
        for splash in splashes where splash.opacity > 0.05 {
            let ink = splashInks[bucket(splash.opacity)]
            let gx = painter.grid(splash.x), gy = painter.grid(splash.y)
            let r = max(1, Int((splash.radius / px).rounded()))
            let lift = r > 2 ? 1 : 0
            painter.cells(ink, gx: gx - r, gy: gy - lift)
            painter.cells(ink, gx: gx + r, gy: gy - lift)
            if r <= 2 { painter.cells(ink, gx: gx, gy: gy - 1) }
        }

        // Lightning: a thick pale glow with a one-cell white core.
        if let bolt, bolt.segments.count >= 2 {
            let progress = bolt.age / bolt.lifetime
            let alpha: Double
            if progress < 0.15 { alpha = 1 }
            else if progress > 0.35 && progress < 0.45 { alpha = 0.7 }
            else { alpha = Double(max(0, 1 - progress * 1.3)) }
            if alpha > 0.05 {
                let a = PixelPainter.stepped(alpha, levels: 3)
                let glow = painter.ink(RetroPalette.ice, opacity: a * 0.6)
                let core = painter.ink(RetroPalette.white, opacity: a)
                painter.polyline(glow, bolt.segments, thickness: 3)
                painter.polyline(core, bolt.segments)
            }
        }

        painter.flush(into: context)
    }
}
