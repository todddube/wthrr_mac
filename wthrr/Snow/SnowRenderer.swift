// SnowRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Snow renderer

/// Renders snow particles (dots, star crystals, dendrites) and the accumulated
/// drift shape onto a Canvas graphics context.
enum SnowRenderer {

    /// Draws all snow particles and the drift accumulation surface.
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points.
    ///   - isDark: Whether the system is in dark mode (affects particle and drift colours).
    ///   - particles: The current array of snow particles to render.
    ///   - accumulationMap: Per-column accumulated snow height in points.
    ///   - baselineMap: Per-column ground level in canvas coordinates.
    ///   - accumulationEnabled: Whether drift accumulation is currently active.
    ///   - columnWidth: Width of each accumulation column in points.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        particles: [Particle],
        accumulationMap: [CGFloat],
        baselineMap: [CGFloat],
        accumulationEnabled: Bool,
        columnWidth: CGFloat,
        particleOpacity: Double = 1.0,
        tintHue: Double = -1,
        time: CGFloat = 0,
        frostLevel: CGFloat = 0
    ) {
        drawFlakes(context: context, isDark: isDark, particles: particles, particleOpacity: particleOpacity, tintHue: tintHue)
        drawDrift(
            context: context, size: size, isDark: isDark,
            accumulationMap: accumulationMap, baselineMap: baselineMap,
            accumulationEnabled: accumulationEnabled, columnWidth: columnWidth,
            tintHue: tintHue
        )
        if frostLevel > 0.01 {
            FrostRenderer.draw(
                context: context, size: size, isDark: isDark,
                time: time, frostLevel: frostLevel,
                particleOpacity: particleOpacity, tintHue: tintHue
            )
        }
    }

    // MARK: Snowflake rendering

    /// Renders individual snow crystals with per-flake rotation and colour tint.
    ///
    /// Geometry comes from `SnowCrystalGeometry`, which batches each crystal's segments
    /// by line width into as few stroked paths as possible — a dendrite is 3 paths and
    /// 4 draw calls rather than the 78 it once was.
    ///
    /// A `Canvas`-symbol implementation (rasterise each crystal once, blit per flake)
    /// was built and measured against this, and came out 3–5% *slower* on an M4: with
    /// the geometry already batched, resampling a rotated and scaled bitmap per flake
    /// costs more than stroking the paths outright. Direct vector drawing stays.
    private static func drawFlakes(
        context: GraphicsContext,
        isDark: Bool,
        particles: [Particle],
        particleOpacity: Double,
        tintHue: Double = -1
    ) {
        guard !particles.isEmpty else { return }

        // Resolve the shading table once per frame. Previously every flake allocated a
        // `Color` and forced the context to resolve it to a CGColor on each fill —
        // hundreds of redundant resolutions per frame per display.
        let shadings: [GraphicsContext.Shading] = (0..<SnowTint.bucketCount).map { i in
            context.resolve(
                .color(ColorTheme.snowColor(tint: SnowTint.tint(forBucket: i),
                                            isDark: isDark, hue: tintHue))
            )
        }
        let shadowShading = context.resolve(.color(Color(white: 0.3)))

        for flake in particles {
            // Light-mode shadow pass for contrast against bright wallpapers
            if !isDark {
                var shadowCtx = context
                shadowCtx.opacity = flake.opacity * particleOpacity * 0.18
                let sr = flake.size * 1.15
                let shadowRect = CGRect(x: flake.x - sr + 0.7, y: flake.y - sr + 0.9,
                                        width: sr * 2, height: sr * 2)
                shadowCtx.fill(Path(ellipseIn: shadowRect), with: shadowShading)
            }

            var ctx = context
            ctx.opacity = flake.opacity * particleOpacity
            drawCrystal(ctx: ctx, flake: flake, shading: shadings[SnowTint.bucket(for: flake.tint)])
        }
    }

    /// Strokes one crystal's batched geometry.
    private static func drawCrystal(
        ctx: GraphicsContext,
        flake: Particle,
        shading: GraphicsContext.Shading
    ) {
        let crystal = SnowCrystalGeometry.crystal(for: flake.shape, radius: flake.size)

        if crystal.strokes.isEmpty {
            // Dots are rotationally symmetric, so they need no transparency layer.
            var dotCtx = ctx
            dotCtx.translateBy(x: flake.x, y: flake.y)
            dotCtx.fill(crystal.centre, with: shading)
            return
        }

        // The layer keeps overlapping strokes from double-darkening at flake opacity.
        ctx.drawLayer { c in
            c.translateBy(x: flake.x, y: flake.y)
            c.rotate(by: Angle(radians: flake.rotation))
            for stroke in crystal.strokes {
                c.stroke(stroke.path, with: shading,
                         style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round))
            }
            c.fill(crystal.centre, with: shading)
        }
    }

    // MARK: Drift rendering

    /// Renders the accumulated snow drift as a smooth filled shape along the screen bottom.
    /// The drift surface uses quadratic curves for a natural, rounded appearance.
    private static func drawDrift(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        accumulationMap: [CGFloat],
        baselineMap: [CGFloat],
        accumulationEnabled: Bool,
        columnWidth: CGFloat,
        tintHue: Double = -1
    ) {
        let mapCount = accumulationMap.count
        guard accumulationEnabled && mapCount > 1 else { return }

        let driftFillColor = ColorTheme.snowDriftColor(isDark: isDark, hue: tintHue)

        let driftEdgeColor: Color = isDark
            ? Color(white: 0.80, opacity: 0.6)
            : Color(red: 0.65, green: 0.73, blue: 0.85, opacity: 0.7)

        let colW = columnWidth

        // Filled body — walk right edge down -> bottom -> left along top surface
        var driftPath = Path()
        driftPath.move(to: CGPoint(x: 0, y: size.height))
        driftPath.addLine(to: CGPoint(x: size.width, y: size.height))

        var firstPoint = true
        var prevPt = CGPoint.zero
        for col in (0..<mapCount).reversed() {
            let x    = CGFloat(col) * colW + colW * 0.5
            let topY = baselineMap[col] - accumulationMap[col]
            let pt   = CGPoint(x: x, y: topY)
            if firstPoint {
                driftPath.addLine(to: pt)
                firstPoint = false
            } else {
                let mid = CGPoint(x: (prevPt.x + pt.x) / 2, y: (prevPt.y + pt.y) / 2)
                driftPath.addQuadCurve(to: pt, control: mid)
            }
            prevPt = pt
        }
        driftPath.closeSubpath()
        context.fill(driftPath, with: .color(driftFillColor))

        // Top edge stroke for definition
        var edgePath = Path()
        firstPoint = true
        prevPt = .zero
        for col in 0..<mapCount {
            let x    = CGFloat(col) * colW + colW * 0.5
            let topY = baselineMap[col] - accumulationMap[col]
            let pt   = CGPoint(x: x, y: topY)
            if firstPoint {
                edgePath.move(to: pt)
                firstPoint = false
            } else {
                let mid = CGPoint(x: (prevPt.x + pt.x) / 2, y: (prevPt.y + pt.y) / 2)
                edgePath.addQuadCurve(to: pt, control: mid)
            }
            prevPt = pt
        }
        context.stroke(edgePath, with: .color(driftEdgeColor), lineWidth: 1.5)
    }
}
