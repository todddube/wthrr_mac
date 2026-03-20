// AIStormRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Neon palette

/// The AI storm neon colour palette — supports multiple swappable themes.
enum NeonPalette {
    /// Current palette colors resolved from settings.
    private static var current: (Color, Color, Color, Color) {
        ColorTheme.aiStormColors(palette: WeatherSettings.shared.aiStormPalette)
    }

    static var cyan:    Color { current.0 }
    static var purple:  Color { current.1 }
    static var green:   Color { current.2 }
    static var magenta: Color { current.3 }

    /// Returns a colour from the palette based on a normalised tint value (0-1).
    static func color(for tint: Double) -> Color {
        let c = current
        switch tint {
        case ..<0.25:  return c.0
        case ..<0.50:  return c.1
        case ..<0.75:  return c.2
        default:       return c.3
        }
    }

    /// Returns a colour by palette index (for bolts, scan lines, patches).
    static func indexed(_ index: Int) -> Color {
        let c = current
        switch index % 4 {
        case 0:  return c.0
        case 1:  return c.1
        case 2:  return c.2
        default: return c.3
        }
    }
}

// MARK: - AI storm renderer

/// Renders the AI storm: glitch particles, data bolts, scan lines, and corruption patches.
/// The visual style evokes digital corruption — neon colours, geometric fragments,
/// circuit-trace lightning, and sweeping distortion bands.
enum AIStormRenderer {

    /// Draws all AI storm effects layered for maximum visual impact.
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points.
    ///   - isDark: Whether the system is in dark mode.
    ///   - particles: The current array of glitch particles to render.
    ///   - scanLines: Active horizontal distortion bands.
    ///   - dataBolts: Active circuit-trace lightning bolts.
    ///   - corruptionPatches: Active rectangular noise patches.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        particles: [Particle],
        scanLines: [ScanLine],
        dataBolts: [DataBolt],
        corruptionPatches: [CorruptionPatch],
        alienShips: [AlienShip] = [],
        screenFractures: [ScreenFracture] = [],
        particleOpacity: Double = 1.0
    ) {
        // Screen tint flash from data bolts and fracture impacts
        for bolt in dataBolts where bolt.flashOpacity > 0.001 {
            var flashCtx = context
            flashCtx.opacity = bolt.flashOpacity
            let tintColor = NeonPalette.indexed(bolt.colorIndex).opacity(0.5)
            flashCtx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(tintColor))
        }
        for fracture in screenFractures where fracture.flashOpacity > 0.001 {
            var flashCtx = context
            flashCtx.opacity = fracture.flashOpacity
            flashCtx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        }

        drawScreenFractures(context: context, fractures: screenFractures)
        drawScanLines(context: context, size: size, scanLines: scanLines)
        drawCorruptionPatches(context: context, patches: corruptionPatches)
        drawGlitchParticles(context: context, particles: particles, isDark: isDark, particleOpacity: particleOpacity)
        drawAlienShips(context: context, ships: alienShips)
        drawDataBolts(context: context, bolts: dataBolts)
    }

    // MARK: Glitch particle rendering

    /// Renders glitch fragments as neon geometric shapes with a soft glow.
    /// Shape is determined by the particle's SnowShape field:
    /// dot = tiny glowing dot, star = angle bracket, dendrite = diagonal slash.
    private static func drawGlitchParticles(
        context: GraphicsContext,
        particles: [Particle],
        isDark: Bool,
        particleOpacity: Double
    ) {
        for p in particles {
            let neonColor = NeonPalette.color(for: p.tint)
            var ctx = context
            ctx.opacity = p.opacity * particleOpacity

            // Glow pass — larger, softer, same colour
            var glowCtx = context
            glowCtx.opacity = p.opacity * particleOpacity * 0.3
            let glowR = p.size * 2.5
            let glowRect = CGRect(x: p.x - glowR, y: p.y - glowR,
                                  width: glowR * 2, height: glowR * 2)
            glowCtx.fill(Path(ellipseIn: glowRect), with: .color(neonColor))

            switch p.shape {
            case .dot:
                // Tiny glowing dot
                let r = p.size * 0.7
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(neonColor))

            case .star:
                // Angle bracket fragment: < or > shape
                ctx.drawLayer { bracketCtx in
                    bracketCtx.translateBy(x: p.x, y: p.y)
                    bracketCtx.rotate(by: Angle(radians: p.rotation))
                    let arm = p.size
                    let lineW = max(1.0, p.size * 0.35)
                    var path = Path()
                    path.move(to: CGPoint(x: -arm * 0.6, y: -arm * 0.8))
                    path.addLine(to: CGPoint(x: arm * 0.4, y: 0))
                    path.addLine(to: CGPoint(x: -arm * 0.6, y: arm * 0.8))
                    bracketCtx.stroke(path, with: .color(neonColor),
                                      style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round))
                }

            case .dendrite:
                // Diagonal slash with a perpendicular tick
                ctx.drawLayer { slashCtx in
                    slashCtx.translateBy(x: p.x, y: p.y)
                    slashCtx.rotate(by: Angle(radians: p.rotation))
                    let arm = p.size * 1.2
                    let lineW = max(1.0, p.size * 0.3)
                    // Main slash
                    var path = Path()
                    path.move(to: CGPoint(x: -arm * 0.5, y: -arm))
                    path.addLine(to: CGPoint(x: arm * 0.5, y: arm))
                    slashCtx.stroke(path, with: .color(neonColor),
                                    style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                    // Perpendicular tick at centre
                    var tick = Path()
                    tick.move(to: CGPoint(x: -arm * 0.3, y: 0))
                    tick.addLine(to: CGPoint(x: arm * 0.3, y: 0))
                    slashCtx.stroke(tick, with: .color(neonColor),
                                    style: StrokeStyle(lineWidth: lineW * 0.6, lineCap: .round))
                }
            }
        }
    }

    // MARK: Scan line rendering

    /// Renders horizontal distortion bands that sweep across the screen.
    /// Each band is a thin semi-transparent rectangle in a neon colour.
    private static func drawScanLines(
        context: GraphicsContext,
        size: CGSize,
        scanLines: [ScanLine]
    ) {
        for line in scanLines {
            var ctx = context
            ctx.opacity = line.opacity
            let color = NeonPalette.indexed(line.colorIndex)
            let rect = CGRect(x: 0, y: line.y, width: size.width, height: line.width)
            ctx.fill(Path(rect), with: .color(color))

            // Bright edge at the top of the band
            var edgeCtx = context
            edgeCtx.opacity = line.opacity * 0.6
            let edgeRect = CGRect(x: 0, y: line.y, width: size.width, height: 1)
            edgeCtx.fill(Path(edgeRect), with: .color(.white))
        }
    }

    // MARK: Data bolt rendering

    /// Renders circuit-trace lightning bolts — right-angle paths in neon colours
    /// with a soft glow and bright core, similar to PCB traces.
    private static func drawDataBolts(
        context: GraphicsContext,
        bolts: [DataBolt]
    ) {
        for bolt in bolts {
            guard bolt.segments.count >= 2 else { continue }

            let progress = bolt.age / bolt.lifetime
            let boltOpacity: Double
            if progress < 0.15 {
                boltOpacity = 1.0
            } else if progress > 0.4 && progress < 0.5 {
                boltOpacity = 0.6  // Brief re-flash
            } else {
                boltOpacity = Double(max(0, 1.0 - progress * 1.4))
            }
            guard boltOpacity > 0.01 else { continue }

            let color = NeonPalette.indexed(bolt.colorIndex)

            var path = Path()
            path.move(to: bolt.segments[0])
            for i in 1..<bolt.segments.count {
                path.addLine(to: bolt.segments[i])
            }

            // Outer glow
            var glowCtx = context
            glowCtx.opacity = boltOpacity * 0.3
            glowCtx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: 10, lineCap: .butt, lineJoin: .miter))

            // Mid glow
            var midCtx = context
            midCtx.opacity = boltOpacity * 0.6
            midCtx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: 4, lineCap: .butt, lineJoin: .miter))

            // Bright core — white
            var coreCtx = context
            coreCtx.opacity = boltOpacity
            coreCtx.stroke(path, with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .butt, lineJoin: .miter))
        }
    }

    // MARK: Corruption patch rendering

    /// Renders brief rectangular static patches — regions of visual corruption.
    /// Each patch is a series of thin horizontal lines (scanline noise effect).
    private static func drawCorruptionPatches(
        context: GraphicsContext,
        patches: [CorruptionPatch]
    ) {
        for patch in patches {
            let progress = patch.age / patch.lifetime
            let patchOpacity = Double(1.0 - progress) * 0.5
            guard patchOpacity > 0.01 else { continue }

            let color = NeonPalette.indexed(patch.colorIndex)

            // Draw horizontal noise lines within the patch bounds
            let lineCount = max(2, Int(patch.height / 2))
            let lineSpacing = patch.height / CGFloat(lineCount)

            for i in 0..<lineCount {
                // Alternate between colour and dark lines for a static look
                let isLit = i % 2 == 0
                guard isLit else { continue }

                var ctx = context
                ctx.opacity = patchOpacity * (0.5 + Double.random(in: 0...0.5))
                let lineY = patch.y + CGFloat(i) * lineSpacing
                let lineRect = CGRect(x: patch.x, y: lineY,
                                      width: patch.width, height: max(1, lineSpacing * 0.6))
                ctx.fill(Path(lineRect), with: .color(color))
            }

            // Border flash
            var borderCtx = context
            borderCtx.opacity = patchOpacity * 0.3
            let borderRect = CGRect(x: patch.x, y: patch.y,
                                    width: patch.width, height: patch.height)
            borderCtx.stroke(Path(borderRect), with: .color(color), lineWidth: 0.5)
        }
    }

    // MARK: Alien ship rendering

    /// Renders alien ships as neon triangular hulls with an engine glow and a fading trail.
    /// The ship rotates to face its direction of travel.
    private static func drawAlienShips(
        context: GraphicsContext,
        ships: [AlienShip]
    ) {
        for ship in ships {
            let color = NeonPalette.indexed(ship.colorIndex)

            // Engine trail — fading dots from recent positions
            for (idx, pos) in ship.trail.enumerated() {
                let trailProgress = Double(idx) / Double(max(1, ship.trail.count))
                let trailOpacity = (1.0 - trailProgress) * 0.4
                let trailR = ship.size * CGFloat(0.3 - trailProgress * 0.2)
                guard trailR > 0.5 else { continue }
                var trailCtx = context
                trailCtx.opacity = trailOpacity
                let trailRect = CGRect(x: pos.0 - trailR, y: pos.1 - trailR,
                                       width: trailR * 2, height: trailR * 2)
                trailCtx.fill(Path(ellipseIn: trailRect), with: .color(color))
            }

            // Heading angle from velocity
            let heading = atan2(ship.vy, ship.vx)

            // Engine glow — large soft circle behind the ship
            var glowCtx = context
            glowCtx.opacity = 0.25
            let glowR = ship.size * 2.5
            let glowRect = CGRect(x: ship.x - glowR, y: ship.y - glowR,
                                  width: glowR * 2, height: glowR * 2)
            glowCtx.fill(Path(ellipseIn: glowRect), with: .color(color))

            // Hull — triangular shape pointing in direction of travel
            context.drawLayer { hullCtx in
                hullCtx.translateBy(x: ship.x, y: ship.y)
                hullCtx.rotate(by: Angle(radians: heading))

                let s = ship.size
                var hull = Path()
                hull.move(to: CGPoint(x: s * 1.2, y: 0))          // Nose
                hull.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.6))  // Left wing
                hull.addLine(to: CGPoint(x: -s * 0.3, y: 0))      // Centre notch
                hull.addLine(to: CGPoint(x: -s * 0.7, y: s * 0.6))   // Right wing
                hull.closeSubpath()

                // Filled hull
                var fillCtx = hullCtx
                fillCtx.opacity = 0.7
                fillCtx.fill(hull, with: .color(color))

                // Bright edge
                hullCtx.stroke(hull, with: .color(.white.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.0, lineJoin: .round))

                // Cockpit dot
                let cockpitR = s * 0.2
                hullCtx.fill(
                    Path(ellipseIn: CGRect(x: s * 0.3 - cockpitR, y: -cockpitR,
                                           width: cockpitR * 2, height: cockpitR * 2)),
                    with: .color(.white)
                )
            }
        }
    }

    // MARK: Screen fracture rendering

    /// Renders glass-crack patterns: jagged arms radiating from an impact point.
    /// Each arm is drawn with a neon glow and a bright white core, fading over time.
    /// A brief white flash appears at the impact point on spawn.
    private static func drawScreenFractures(
        context: GraphicsContext,
        fractures: [ScreenFracture]
    ) {
        for fracture in fractures {
            let progress = fracture.age / fracture.lifetime
            // Cracks appear instantly then fade out over the lifetime
            let crackOpacity = Double(max(0, 1.0 - progress * 0.8))
            guard crackOpacity > 0.01 else { continue }

            let color = NeonPalette.indexed(fracture.colorIndex)

            // Impact flash circle
            if fracture.flashOpacity > 0.01 {
                var impactCtx = context
                impactCtx.opacity = fracture.flashOpacity
                let impactR: CGFloat = 30
                let impactRect = CGRect(x: fracture.origin.x - impactR,
                                        y: fracture.origin.y - impactR,
                                        width: impactR * 2, height: impactR * 2)
                impactCtx.fill(Path(ellipseIn: impactRect), with: .color(.white))
            }

            for arm in fracture.arms {
                guard arm.count >= 2 else { continue }

                var path = Path()
                path.move(to: arm[0])
                for i in 1..<arm.count {
                    path.addLine(to: arm[i])
                }

                // Outer glow
                var glowCtx = context
                glowCtx.opacity = crackOpacity * 0.3
                glowCtx.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                // Mid layer
                var midCtx = context
                midCtx.opacity = crackOpacity * 0.5
                midCtx.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Bright core
                var coreCtx = context
                coreCtx.opacity = crackOpacity * 0.9
                coreCtx.stroke(path, with: .color(.white),
                               style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
            }

            // Small impact dot at origin
            var dotCtx = context
            dotCtx.opacity = crackOpacity * 0.7
            let dotR: CGFloat = 3
            dotCtx.fill(
                Path(ellipseIn: CGRect(x: fracture.origin.x - dotR, y: fracture.origin.y - dotR,
                                       width: dotR * 2, height: dotR * 2)),
                with: .color(.white)
            )
        }
    }
}
