// SnowRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

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
    /// Each flake is drawn according to its `SnowShape`: dot, star, or dendrite.
    private static func drawFlakes(
        context: GraphicsContext,
        isDark: Bool,
        particles: [Particle],
        particleOpacity: Double,
        tintHue: Double = -1
    ) {
        for flake in particles {
            let flakeColor = ColorTheme.snowColor(tint: flake.tint, isDark: isDark, hue: tintHue)

            var ctx = context
            ctx.opacity = flake.opacity * particleOpacity

            // Light-mode shadow pass for contrast against bright wallpapers
            if !isDark {
                var shadowCtx = context
                shadowCtx.opacity = flake.opacity * particleOpacity * 0.18
                let sr = flake.size * 1.15
                let shadowRect = CGRect(x: flake.x - sr + 0.7, y: flake.y - sr + 0.9,
                                        width: sr * 2, height: sr * 2)
                shadowCtx.fill(Path(ellipseIn: shadowRect), with: .color(Color(white: 0.3)))
            }

            switch flake.shape {
            case .dot:
                drawDot(ctx: ctx, flake: flake, color: flakeColor)
            case .star:
                drawStar(ctx: ctx, flake: flake, color: flakeColor)
            case .dendrite:
                drawDendrite(ctx: ctx, flake: flake, color: flakeColor)
            }
        }
    }

    /// Draws a soft round pellet — slightly oval to hint at 3D.
    private static func drawDot(ctx: GraphicsContext, flake: Particle, color: Color) {
        let r = flake.size
        let dotRect = CGRect(x: flake.x - r, y: flake.y - r * 0.9,
                             width: r * 2, height: r * 1.8)
        ctx.fill(Path(ellipseIn: dotRect), with: .color(color))
    }

    /// Draws a 6-arm plate crystal: 3 lines at 60-degree intervals with crossbars and a centre dot.
    private static func drawStar(ctx: GraphicsContext, flake: Particle, color: Color) {
        ctx.drawLayer { starCtx in
            starCtx.translateBy(x: flake.x, y: flake.y)
            starCtx.rotate(by: Angle(radians: flake.rotation))
            let arm = flake.size
            let lineWidth = max(1.0, flake.size * 0.28)

            // Draw 3 axes (each axis = 2 opposing arms)
            for i in 0..<3 {
                let angle = CGFloat(i) * .pi / 3
                var axisPath = Path()
                axisPath.move(to: CGPoint(x: -cos(angle) * arm, y: -sin(angle) * arm))
                axisPath.addLine(to: CGPoint(x: cos(angle) * arm, y: sin(angle) * arm))
                starCtx.stroke(axisPath, with: .color(color),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Crossbar at ~60% along each arm
                for sign: CGFloat in [-1, 1] {
                    let cx = sign * cos(angle) * arm * 0.6
                    let cy = sign * sin(angle) * arm * 0.6
                    let barAngle = angle + .pi / 2
                    let barLen   = arm * 0.32
                    var barPath = Path()
                    barPath.move(to: CGPoint(x: cx - cos(barAngle) * barLen,
                                             y: cy - sin(barAngle) * barLen))
                    barPath.addLine(to: CGPoint(x: cx + cos(barAngle) * barLen,
                                                y: cy + sin(barAngle) * barLen))
                    starCtx.stroke(barPath, with: .color(color),
                                   style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
                }
            }
            // Bright centre dot
            let cR = lineWidth * 1.1
            starCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                         with: .color(color))
        }
    }

    /// Draws a 3-axis branching dendrite: main arms, secondary branches, and tertiary tips.
    private static func drawDendrite(ctx: GraphicsContext, flake: Particle, color: Color) {
        ctx.drawLayer { dendCtx in
            dendCtx.translateBy(x: flake.x, y: flake.y)
            dendCtx.rotate(by: Angle(radians: flake.rotation))
            let arm      = flake.size
            let lineW    = max(1.0, flake.size * 0.22)
            let branchW  = lineW * 0.65
            let tipW     = lineW * 0.45

            for i in 0..<3 {
                let angle = CGFloat(i) * .pi / 3
                for sign: CGFloat in [-1, 1] {
                    let ex = sign * cos(angle) * arm
                    let ey = sign * sin(angle) * arm

                    // Main arm
                    var mainPath = Path()
                    mainPath.move(to: .zero)
                    mainPath.addLine(to: CGPoint(x: ex, y: ey))
                    dendCtx.stroke(mainPath, with: .color(color),
                                   style: StrokeStyle(lineWidth: lineW, lineCap: .round))

                    // Two pairs of secondary branches at 35% and 65% of the arm
                    for frac: CGFloat in [0.35, 0.65] {
                        let bx = sign * cos(angle) * arm * frac
                        let by = sign * sin(angle) * arm * frac
                        let branchLen = arm * (0.40 - frac * 0.18)
                        let branchAngle = angle + .pi / 2
                        for bSign: CGFloat in [-1, 1] {
                            var bPath = Path()
                            bPath.move(to: CGPoint(x: bx, y: by))
                            bPath.addLine(to: CGPoint(
                                x: bx + bSign * cos(branchAngle) * branchLen,
                                y: by + bSign * sin(branchAngle) * branchLen
                            ))
                            dendCtx.stroke(bPath, with: .color(color),
                                           style: StrokeStyle(lineWidth: branchW, lineCap: .round))

                            // Tiny tertiary tip at the end of each branch
                            let tipStartX = bx + bSign * cos(branchAngle) * branchLen
                            let tipStartY = by + bSign * sin(branchAngle) * branchLen
                            let tipLen    = branchLen * 0.38
                            for tSign: CGFloat in [-1, 1] {
                                let tipAngle = branchAngle + tSign * .pi / 4
                                var tPath = Path()
                                tPath.move(to: CGPoint(x: tipStartX, y: tipStartY))
                                tPath.addLine(to: CGPoint(
                                    x: tipStartX + cos(tipAngle) * tipLen,
                                    y: tipStartY + sin(tipAngle) * tipLen
                                ))
                                dendCtx.stroke(tPath, with: .color(color),
                                               style: StrokeStyle(lineWidth: tipW, lineCap: .round))
                            }
                        }
                    }
                }
            }
            // Centre hexagon dot
            let cR = lineW * 1.2
            dendCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                         with: .color(color))
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
