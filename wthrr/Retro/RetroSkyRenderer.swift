// RetroSkyRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Retro sky renderer

/// 8-bit versions of the atmospheric scenes: a pixel sun or cratered moon with
/// starfield for Clear Skies, stepped curtains for Aurora, and scanline-dithered
/// banks for Fog. Old consoles had no alpha gradients, so every soft falloff here is
/// faked the way it was then: by thinning out cells, not by fading them.
enum RetroSkyRenderer {

    // MARK: Clear skies

    /// Draws the sun (with rotating dashed rays) or the moon and stars.
    static func drawClearSky(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        isDark: Bool,
        sky: SkyState,
        time: CGFloat,
        opacity: Double,
        raysEnabled: Bool
    ) {
        var painter = PixelPainter(px: px)
        let cx = CGFloat(sky.x) * size.width
        let cy = CGFloat(sky.y) * size.height
        let radius = min(size.width, size.height) * 0.05

        if sky.isNight {
            drawStars(painter: &painter, size: size, time: time, count: 70,
                      opacity: opacity * (isDark ? 0.9 : 0.6))
            let alpha = min(1, opacity * 0.9)
            let moon = painter.ink(RetroPalette.lightGray, opacity: alpha)
            let lit = painter.ink(RetroPalette.white, opacity: alpha)
            let crater = painter.ink(RetroPalette.gray, opacity: alpha)
            painter.disc(moon, cx: cx, cy: cy, radius: radius)
            painter.disc(lit, cx: cx - radius * 0.15, cy: cy - radius * 0.15, radius: radius * 0.78)
            let r = max(1, painter.grid(radius))
            let gcx = painter.grid(cx), gcy = painter.grid(cy)
            painter.cells(crater, gx: gcx - r / 3, gy: gcy - r / 3, w: 2, h: 2)
            painter.cells(crater, gx: gcx + r / 3, gy: gcy + r / 4)
            painter.cells(crater, gx: gcx - r / 5, gy: gcy + r / 2)
        } else {
            // Golden hour swaps the yellow core for orange, like a palette swap.
            let golden = sky.goldenness > 0.5
            let alpha = min(1, opacity * 0.9)
            let rim = painter.ink(golden ? RetroPalette.red : RetroPalette.orange, opacity: alpha)
            let body = painter.ink(golden ? RetroPalette.orange : RetroPalette.gold, opacity: alpha)
            let core = painter.ink(RetroPalette.yellow, opacity: alpha)
            painter.disc(rim, cx: cx, cy: cy, radius: radius)
            painter.disc(body, cx: cx, cy: cy, radius: radius * 0.82)
            painter.disc(core, cx: cx - radius * 0.2, cy: cy - radius * 0.2, radius: radius * 0.4)

            if raysEnabled {
                // Eight dashed rays, turning one notch at a time rather than smoothly.
                let ray = painter.ink(RetroPalette.gold, opacity: alpha * 0.85)
                let tick = (Double(time) * 2).rounded(.down)
                let spin = tick * (.pi / 32)
                let pulse = tick.truncatingRemainder(dividingBy: 2) == 0 ? 1.0 : 0.82
                for i in 0..<8 {
                    let a = spin + Double(i) * .pi / 4
                    let (s, c) = (CGFloat(sin(a)), CGFloat(cos(a)))
                    let inner = radius * 1.35
                    let outer = radius * (i.isMultiple(of: 2) ? 2.2 : 1.8) * CGFloat(pulse)
                    painter.line(ray,
                                 from: CGPoint(x: cx + c * inner, y: cy + s * inner),
                                 to: CGPoint(x: cx + c * outer, y: cy + s * outer),
                                 thickness: 2)
                }
            }
        }
        painter.flush(into: context)
    }

    /// Clear-sky motes as single twinkling cells.
    static func drawMotes(
        context: GraphicsContext,
        px: CGFloat,
        particles: [Particle],
        opacity: Double,
        time: Double
    ) {
        guard !particles.isEmpty else { return }
        var painter = PixelPainter(px: px)
        let bright = painter.ink(RetroPalette.yellow, opacity: min(1, opacity * 0.8))
        let dim = painter.ink(RetroPalette.white, opacity: min(1, opacity * 0.45))
        let frame = Int(time * 3)
        for (i, p) in particles.enumerated() {
            // Each mote blinks on its own schedule; about a third are "lit" per frame.
            let lit = PixelPainter.hash01(i, frame) < 0.35
            painter.dot(lit ? bright : dim, x: p.x, y: p.y)
        }
        painter.flush(into: context)
    }

    /// A deterministic starfield in the upper two-thirds, twinkling in steps.
    private static func drawStars(
        painter: inout PixelPainter,
        size: CGSize,
        time: CGFloat,
        count: Int,
        opacity: Double
    ) {
        let dim = painter.ink(RetroPalette.lightGray, opacity: min(1, opacity * 0.6))
        let bright = painter.ink(RetroPalette.white, opacity: min(1, opacity))
        let accent = painter.ink(RetroPalette.yellow, opacity: min(1, opacity))
        let frame = Int(time * 2)
        for i in 0..<count {
            let x = CGFloat(PixelPainter.hash01(i, 1)) * size.width
            let y = CGFloat(PixelPainter.hash01(i, 2)) * size.height * 0.62
            let twinkle = PixelPainter.hash01(i, frame / 2 + i % 3)
            if i % 9 == 0 {
                // A few big four-point stars that flare every few frames.
                let sprite = twinkle > 0.6 ? RetroSprites.starBig : RetroSprites.starSmall
                painter.sprite(sprite, x: x, y: y, inks: [bright, accent])
            } else {
                painter.dot(twinkle > 0.3 ? bright : dim, x: x, y: y)
            }
        }
    }

    // MARK: Aurora

    /// Band colour triples: (core, mid, edge), all from the palette.
    private static let auroraBands: [(Color, Color, Color)] = [
        (RetroPalette.mint, RetroPalette.green, RetroPalette.teal),
        (RetroPalette.sky, RetroPalette.teal, RetroPalette.blue),
        (RetroPalette.magenta, RetroPalette.purple, RetroPalette.navy),
        (RetroPalette.mint, RetroPalette.teal, RetroPalette.navy),
        (RetroPalette.green, RetroPalette.mint, RetroPalette.teal),
    ]

    /// Draws aurora curtains as vertical stripes whose height ripples over time,
    /// with a magenta fringe on top and a dithered fade at the bottom.
    static func drawAurora(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        isDark: Bool,
        time: CGFloat,
        opacity: Double
    ) {
        var painter = PixelPainter(px: px)
        drawStars(painter: &painter, size: size, time: time, count: 55,
                  opacity: opacity * (isDark ? 0.7 : 0.4))

        // Curtains are drawn two cells wide — that's the "stripe" that sells it.
        let stripe = 2
        for (i, colors) in auroraBands.enumerated() {
            // Same band motion as the smooth renderer.
            let phase = CGFloat(i) * 1.3 + time * 0.15
            let xCenter = size.width * (0.15 + CGFloat(i) * 0.18) + sin(phase) * size.width * 0.08
            let bandWidth = size.width * (0.12 + 0.06 * sin(phase * 0.7))
            let bandHeight = size.height * (0.4 + 0.2 * sin(phase * 0.5 + 1.0))
            let yOffset = size.height * (0.05 + 0.1 * sin(phase * 0.3))

            let base = (0.08 + 0.06 * sin(Double(phase) * 0.9)) * opacity * 2.0
            let alpha = PixelPainter.stepped(min(1, isDark ? base : base * 0.6), levels: 5)
            let core = painter.ink(colors.0, opacity: alpha)
            let mid = painter.ink(colors.1, opacity: alpha)
            let edge = painter.ink(colors.2, opacity: alpha * 0.8)
            let fringe = painter.ink(RetroPalette.magenta, opacity: alpha * 0.7)

            let gx0 = painter.grid(xCenter - bandWidth / 2)
            let gx1 = painter.grid(xCenter + bandWidth / 2)
            let halfCols = max(1, CGFloat(gx1 - gx0) / 2)
            var gx = gx0
            while gx <= gx1 {
                let u = abs(CGFloat(gx) - CGFloat(gx0) - halfCols) / halfCols   // 0 centre → 1 edge
                let ink = u < 0.35 ? core : (u < 0.7 ? mid : edge)
                let x = CGFloat(gx) * px
                // Ripple: each stripe's top and length wave along the curtain.
                let top = yOffset + sin(x * 0.012 + time * 0.6 + CGFloat(i)) * bandHeight * 0.07
                // Two short ripples make a wavy hem rather than one long slope.
                let length = bandHeight * (0.72
                    + 0.12 * sin(x * 0.045 - time * 0.8 + CGFloat(i) * 2)
                    + 0.06 * sin(x * 0.13 + time * 1.3))
                let gyTop = painter.grid(top)
                let tail = 6
                let rows = max(tail + 2, Int(length / px))
                painter.cells(fringe, gx: gx, gy: gyTop, w: stripe)
                painter.cells(ink, gx: gx, gy: gyTop + 1, w: stripe, h: rows - tail - 1)
                // Dithered tail: cells thin out row by row, the old-console fade.
                for t in 0..<tail {
                    let gy = gyTop + rows - tail + t
                    let keep = 1 - Double(t + 1) / Double(tail + 1)
                    for s in 0..<stripe where PixelPainter.hash01(gx + s, gy) < keep {
                        painter.cells(edge, gx: gx + s, gy: gy)
                    }
                }
                gx += stripe
            }
        }
        painter.flush(into: context)
    }

    // MARK: Fog

    /// Draws fog bands as broken scanlines — dense rows in the band's middle,
    /// sparser rows at its edges — and wisps as stacked three-row puffs.
    static func drawFog(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        isDark: Bool,
        particles: [Particle],
        fogBands: [FogBand],
        opacity: Double,
        tintHue: Double
    ) {
        let color = RetroPalette.nearest(
            hue: tintHue, fallback: isDark ? RetroPalette.lightGray : RetroPalette.gray)
        var painter = PixelPainter(px: px)

        let cols = Int((size.width / px).rounded(.up))
        for (b, band) in fogBands.enumerated() {
            let ink = painter.ink(color, opacity: min(1, band.opacity * opacity * 1.4))
            let gyTop = painter.grid(band.y - band.height / 2)
            let rows = max(1, Int(band.height / px))
            // The bank slides sideways with its phase so it undulates as it sinks.
            let slide = Int(sin(band.phase + band.y * 0.01) * 8)
            for r in 0..<rows {
                let t = (Double(r) + 0.5) / Double(rows)
                let density = sin(.pi * t)              // 0 at edges, 1 mid-band
                // Row stride: every row in the core, every 2nd/3rd towards the edges.
                let stride = density > 0.7 ? 1 : (density > 0.4 ? 2 : 3)
                guard r % stride == 0 else { continue }
                // Broken scanline: dashes of random length with random gaps, each row
                // starting at its own offset so the gaps never line up into a grid.
                var gx = slide - Int(PixelPainter.hash01(r, b) * 16)
                var n = 0
                while gx < cols {
                    let len = 3 + Int(PixelPainter.hash01(n, r, b) * 14)
                    if PixelPainter.hash01(r, n, b + 7) < density * 0.55 {
                        painter.cells(ink, gx: gx, gy: gyTop + r, w: len)
                    }
                    gx += len + 1 + Int(PixelPainter.hash01(n, b, r + 3) * 4)
                    n += 1
                }
            }
        }

        // Wisps: three opacity notches, each puff a wide row with narrower caps.
        let wispInks = [0.05, 0.09, 0.13].map {
            painter.ink(color, opacity: min(1, $0 * opacity * 1.6))
        }
        for p in particles {
            let ink = wispInks[p.opacity < 0.06 ? 0 : (p.opacity < 0.09 ? 1 : 2)]
            let r = p.size * 2.5
            let w = max(2, Int(r * 2 / px))
            let gx = painter.grid(p.x) - w / 2
            let gy = painter.grid(p.y)
            painter.cells(ink, gx: gx, gy: gy, w: w)
            painter.cells(ink, gx: gx + w / 5, gy: gy - 1, w: max(1, w * 3 / 5))
            painter.cells(ink, gx: gx + w / 4, gy: gy + 1, w: max(1, w / 2))
        }

        painter.flush(into: context)
    }
}
