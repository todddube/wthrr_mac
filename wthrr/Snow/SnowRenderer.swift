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

    /// Number of quantised tint buckets used to pre-resolve flake shading.
    ///
    /// `Particle.tint` is a continuous 0–1 value, but it only nudges one colour channel
    /// by a few percent — quantising it to a handful of buckets is visually identical
    /// and lets us resolve the shading once per frame instead of once per flake.
    private static let tintBucketCount = 8

    /// Renders individual snow crystals with per-flake rotation and colour tint.
    /// Each flake is drawn according to its `SnowShape`: dot, star, or dendrite.
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
        let shadings: [GraphicsContext.Shading] = (0..<tintBucketCount).map { i in
            let tint = Double(i) / Double(tintBucketCount - 1)
            return context.resolve(
                .color(ColorTheme.snowColor(tint: tint, isDark: isDark, hue: tintHue))
            )
        }
        let shadowShading = context.resolve(.color(Color(white: 0.3)))
        let maxBucket = tintBucketCount - 1

        for flake in particles {
            let bucket = min(maxBucket, max(0, Int(flake.tint * Double(maxBucket) + 0.5)))
            let shading = shadings[bucket]

            var ctx = context
            ctx.opacity = flake.opacity * particleOpacity

            // Light-mode shadow pass for contrast against bright wallpapers
            if !isDark {
                var shadowCtx = context
                shadowCtx.opacity = flake.opacity * particleOpacity * 0.18
                let sr = flake.size * 1.15
                let shadowRect = CGRect(x: flake.x - sr + 0.7, y: flake.y - sr + 0.9,
                                        width: sr * 2, height: sr * 2)
                shadowCtx.fill(Path(ellipseIn: shadowRect), with: shadowShading)
            }

            switch flake.shape {
            case .dot:
                drawDot(ctx: ctx, flake: flake, shading: shading)
            case .star:
                drawStar(ctx: ctx, flake: flake, shading: shading)
            case .dendrite:
                drawDendrite(ctx: ctx, flake: flake, shading: shading)
            }
        }
    }

    /// Draws a soft round pellet — slightly oval to hint at 3D.
    private static func drawDot(ctx: GraphicsContext, flake: Particle, shading: GraphicsContext.Shading) {
        let r = flake.size
        let dotRect = CGRect(x: flake.x - r, y: flake.y - r * 0.9,
                             width: r * 2, height: r * 1.8)
        ctx.fill(Path(ellipseIn: dotRect), with: shading)
    }

    /// Draws a 6-arm plate crystal: 3 lines at 60-degree intervals with crossbars and a centre dot.
    ///
    /// All segments of a given line width are accumulated into one `Path` and stroked
    /// once. Stroking a self-overlapping path renders it as a single shape, so joints
    /// look the same as before while the draw-call count drops from 10 to 3.
    private static func drawStar(ctx: GraphicsContext, flake: Particle, shading: GraphicsContext.Shading) {
        ctx.drawLayer { starCtx in
            starCtx.translateBy(x: flake.x, y: flake.y)
            starCtx.rotate(by: Angle(radians: flake.rotation))
            let arm = flake.size
            let lineWidth = max(1.0, flake.size * 0.28)

            var axes = Path()
            var bars = Path()

            // 3 axes (each axis = 2 opposing arms)
            for i in 0..<3 {
                let angle = CGFloat(i) * .pi / 3
                let ca = cos(angle), sa = sin(angle)
                axes.move(to: CGPoint(x: -ca * arm, y: -sa * arm))
                axes.addLine(to: CGPoint(x: ca * arm, y: sa * arm))

                // Crossbar at ~60% along each arm
                let barAngle = angle + .pi / 2
                let cb = cos(barAngle), sb = sin(barAngle)
                let barLen = arm * 0.32
                for sign: CGFloat in [-1, 1] {
                    let cx = sign * ca * arm * 0.6
                    let cy = sign * sa * arm * 0.6
                    bars.move(to: CGPoint(x: cx - cb * barLen, y: cy - sb * barLen))
                    bars.addLine(to: CGPoint(x: cx + cb * barLen, y: cy + sb * barLen))
                }
            }

            starCtx.stroke(axes, with: shading,
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            starCtx.stroke(bars, with: shading,
                           style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))

            // Bright centre dot
            let cR = lineWidth * 1.1
            starCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                         with: shading)
        }
    }

    /// Draws a 3-axis branching dendrite: main arms, secondary branches, and tertiary tips.
    ///
    /// This was by far the most expensive thing wthrr drew: 78 individual `Path`
    /// allocations and 78 `stroke` calls per flake, per frame. Batching by line width
    /// brings that down to 3 paths and 4 draw calls with no change in appearance.
    private static func drawDendrite(ctx: GraphicsContext, flake: Particle, shading: GraphicsContext.Shading) {
        ctx.drawLayer { dendCtx in
            dendCtx.translateBy(x: flake.x, y: flake.y)
            dendCtx.rotate(by: Angle(radians: flake.rotation))
            let arm      = flake.size
            let lineW    = max(1.0, flake.size * 0.22)
            let branchW  = lineW * 0.65
            let tipW     = lineW * 0.45

            var mains    = Path()
            var branches = Path()
            var tips     = Path()

            for i in 0..<3 {
                let angle = CGFloat(i) * .pi / 3
                let ca = cos(angle), sa = sin(angle)
                let branchAngle = angle + .pi / 2
                let cb = cos(branchAngle), sb = sin(branchAngle)

                for sign: CGFloat in [-1, 1] {
                    // Main arm
                    mains.move(to: .zero)
                    mains.addLine(to: CGPoint(x: sign * ca * arm, y: sign * sa * arm))

                    // Two pairs of secondary branches at 35% and 65% of the arm
                    for frac: CGFloat in [0.35, 0.65] {
                        let bx = sign * ca * arm * frac
                        let by = sign * sa * arm * frac
                        let branchLen = arm * (0.40 - frac * 0.18)
                        let tipLen = branchLen * 0.38

                        for bSign: CGFloat in [-1, 1] {
                            let ex = bx + bSign * cb * branchLen
                            let ey = by + bSign * sb * branchLen
                            branches.move(to: CGPoint(x: bx, y: by))
                            branches.addLine(to: CGPoint(x: ex, y: ey))

                            // Tiny tertiary tips at the end of each branch
                            for tSign: CGFloat in [-1, 1] {
                                let tipAngle = branchAngle + tSign * .pi / 4
                                tips.move(to: CGPoint(x: ex, y: ey))
                                tips.addLine(to: CGPoint(
                                    x: ex + cos(tipAngle) * tipLen,
                                    y: ey + sin(tipAngle) * tipLen
                                ))
                            }
                        }
                    }
                }
            }

            dendCtx.stroke(mains, with: shading,
                           style: StrokeStyle(lineWidth: lineW, lineCap: .round))
            dendCtx.stroke(branches, with: shading,
                           style: StrokeStyle(lineWidth: branchW, lineCap: .round))
            dendCtx.stroke(tips, with: shading,
                           style: StrokeStyle(lineWidth: tipW, lineCap: .round))

            // Centre hexagon dot
            let cR = lineW * 1.2
            dendCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                         with: shading)
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
