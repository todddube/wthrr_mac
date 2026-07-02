// FrostRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Frost renderer

/// Draws ice-crystal formations that creep inward from screen edges as snow accumulates.
/// All geometry is deterministic from root position — no persistent state required.
/// Frost level (0–1) is derived from average accumulation relative to the max depth setting.
enum FrostRenderer {

    // MARK: - Public draw entry point

    /// Renders screen-edge frost formations scaled by the current accumulation level.
    ///
    /// - Parameters:
    ///   - context:         Canvas graphics context to draw into.
    ///   - size:            Full canvas size in points.
    ///   - isDark:          Dark mode flag — affects color brightness.
    ///   - time:            Elapsed snow-mode time (seconds) — drives a subtle shimmer.
    ///   - frostLevel:      0 = none, 1 = full creep (derived from accumulation / maxHeight).
    ///   - particleOpacity: Global opacity multiplier from WeatherSettings.
    ///   - tintHue:         Snow hue override (-1 = default ice blue-white).
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        time: CGFloat,
        frostLevel: CGFloat,
        particleOpacity: Double,
        tintHue: Double
    ) {
        guard frostLevel > 0.01 else { return }

        // Slow sine shimmer (±6%) makes the ice surface look alive
        let shimmer = CGFloat(0.94 + 0.06 * sin(Double(time) * 0.55))
        let baseOpacity = CGFloat(particleOpacity) * shimmer

        // Bottom edge — most prominent, visually ties into the snow drift
        drawEdge(context: context, size: size, isDark: isDark,
                 edge: .bottom, frostLevel: frostLevel,
                 baseOpacity: baseOpacity, tintHue: tintHue)

        // Side edges — subtler, scale with frostLevel
        let sideOpacity = baseOpacity * 0.65
        drawEdge(context: context, size: size, isDark: isDark,
                 edge: .left, frostLevel: frostLevel,
                 baseOpacity: sideOpacity, tintHue: tintHue)
        drawEdge(context: context, size: size, isDark: isDark,
                 edge: .right, frostLevel: frostLevel,
                 baseOpacity: sideOpacity, tintHue: tintHue)

        // Top corners — only appear at high accumulation (frostLevel > 0.5)
        let cornerLevel = max(0, (frostLevel - 0.50) * 2.0)
        if cornerLevel > 0.01 {
            let cornerOpacity = baseOpacity * 0.45
            drawCorner(context: context, size: size, isDark: isDark,
                       isLeft: true, frostLevel: cornerLevel,
                       baseOpacity: cornerOpacity, tintHue: tintHue)
            drawCorner(context: context, size: size, isDark: isDark,
                       isLeft: false, frostLevel: cornerLevel,
                       baseOpacity: cornerOpacity, tintHue: tintHue)
        }
    }

    // MARK: - Edge frost

    private enum Edge { case bottom, left, right }

    private static func drawEdge(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        edge: Edge,
        frostLevel: CGFloat,
        baseOpacity: CGFloat,
        tintHue: Double
    ) {
        let spacing: CGFloat   // pt between root points along the edge
        let maxReach: CGFloat  // how far frost can creep inward at frostLevel = 1.0
        let edgeLength: CGFloat

        switch edge {
        case .bottom:
            spacing    = 44
            maxReach   = min(size.height * 0.28, 210)
            edgeLength = size.width
        case .left, .right:
            spacing    = 50
            maxReach   = min(size.width * 0.10, 100)
            edgeLength = size.height
        }

        let count = max(1, Int(edgeLength / spacing))

        for i in 0..<count {
            // Deterministic per-root seeds via LCG
            var lcg = lcgSeed(UInt64(i) &* 2654435761 &+ 0x9E3779B97F4A7C15)
            let h1 = lcgFrac(&lcg)   // position jitter
            let h2 = lcgFrac(&lcg)   // angle jitter
            let h3 = lcgFrac(&lcg)   // arm length scale
            let h4 = lcgFrac(&lcg)   // opacity variation

            // Slightly stagger root positions for an organic look
            let pos = (CGFloat(i) + 0.5 + CGFloat(h1) * 0.3 - 0.15) * spacing
            guard pos >= 0, pos <= edgeLength else { continue }

            let (rx, ry, baseAngle): (CGFloat, CGFloat, CGFloat)
            switch edge {
            case .bottom:
                rx = pos; ry = size.height
                // Mostly upward (-90°) with ±16° variation
                baseAngle = -.pi / 2 + CGFloat(h2 - 0.5) * 0.55
            case .left:
                rx = 0; ry = pos
                // Mostly rightward (0°) with ±14° variation
                baseAngle = CGFloat(h2 - 0.5) * 0.48
            case .right:
                rx = size.width; ry = pos
                // Mostly leftward (180°) with ±14° variation
                baseAngle = .pi + CGFloat(h2 - 0.5) * 0.48
            }

            let armLength = maxReach * frostLevel * CGFloat(0.55 + h3 * 0.45)
            let rootOpacity = baseOpacity * CGFloat(0.58 + h4 * 0.28)

            branch(context: context, isDark: isDark,
                   x: rx, y: ry, angle: baseAngle, length: armLength,
                   depth: 0, opacity: rootOpacity, seed: lcg, tintHue: tintHue)
        }
    }

    // MARK: - Corner frost clusters

    private static func drawCorner(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        isLeft: Bool,
        frostLevel: CGFloat,
        baseOpacity: CGFloat,
        tintHue: Double
    ) {
        let cx: CGFloat = isLeft ? 0 : size.width
        let cy: CGFloat = 0

        // Center angle points 45° inward toward the screen interior
        let centerAngle: CGFloat = isLeft ? .pi * 0.25 : .pi * 0.75
        let spreadAngle: CGFloat = .pi * 0.65
        let maxReach = min(size.width, size.height) * 0.14 * frostLevel

        let numArms = 9
        for i in 0..<numArms {
            var lcg = lcgSeed(UInt64(i) &* 0xDEADBEEF &+ (isLeft ? UInt64(1) : UInt64(2)) &* 0x9E3779B9)
            let h1 = lcgFrac(&lcg)
            let h2 = lcgFrac(&lcg)

            let angle = centerAngle - spreadAngle / 2 + CGFloat(i) / CGFloat(numArms - 1) * spreadAngle
            let length = maxReach * CGFloat(0.55 + h1 * 0.45)

            branch(context: context, isDark: isDark,
                   x: cx, y: cy, angle: angle, length: length,
                   depth: 0, opacity: baseOpacity * CGFloat(0.55 + h2 * 0.30),
                   seed: lcg, tintHue: tintHue)
        }
    }

    // MARK: - Recursive branch drawer

    /// Draws a single frost arm and recursively spawns sub-branches.
    /// The length-based guard naturally limits branching depth at low frostLevel
    /// without needing an explicit depth cap — short arms can't support children.
    private static func branch(
        context: GraphicsContext,
        isDark: Bool,
        x: CGFloat, y: CGFloat,
        angle: CGFloat,
        length: CGFloat,
        depth: Int,
        opacity: CGFloat,
        seed: UInt64,
        tintHue: Double
    ) {
        guard length > 5, depth < 4, opacity > 0.03 else {
            // Draw a tiny glint dot at the tip of terminal branches
            if length > 2, opacity > 0.06 {
                let r: CGFloat = 1.1
                var ctx = context
                ctx.opacity = min(0.9, opacity * 1.3)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(tipGlintColor(isDark: isDark, tintHue: tintHue)))
            }
            return
        }

        var lcg = seed

        let endX = x + cos(angle) * length
        let endY = y + sin(angle) * length

        // Draw this arm segment
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: endX, y: endY))

        // Line width tapers with depth for a natural branching silhouette
        let lineWidth = max(0.4, 2.0 - CGFloat(depth) * 0.48)
        var ctx = context
        ctx.opacity = min(0.92, opacity)
        ctx.stroke(path, with: .color(frostColor(isDark: isDark, tintHue: tintHue)),
                   lineWidth: lineWidth)

        // Spawn sub-branches: 3 at depth 0, 2 thereafter
        let numSubs = depth < 2 ? 3 : 2
        let childOpacity = opacity * 0.68

        for bi in 0..<numSubs {
            let h1 = lcgFrac(&lcg)   // attach-point jitter
            let h2 = lcgFrac(&lcg)   // angle spread jitter
            let h3 = lcgFrac(&lcg)   // length jitter

            // Distribute attachment points along the arm
            let frac = CGFloat(bi + 1) / CGFloat(numSubs + 1) + CGFloat(h1 - 0.5) * 0.08
            let bx = x + cos(angle) * length * frac
            let by = y + sin(angle) * length * frac

            // Alternate sides: even = left of parent, odd = right
            let side: CGFloat = bi.isMultiple(of: 2) ? 1 : -1
            // Branch angle: 36–54° from parent direction
            let spread = .pi / 5 + CGFloat(h2) * .pi / 9
            let childAngle = angle + spread * side
            let childLength = length * CGFloat(0.52 + h3 * 0.14)

            branch(context: context, isDark: isDark,
                   x: bx, y: by, angle: childAngle, length: childLength,
                   depth: depth + 1, opacity: childOpacity, seed: lcg, tintHue: tintHue)
        }
    }

    // MARK: - Colors

    private static func frostColor(isDark: Bool, tintHue: Double) -> Color {
        guard tintHue < 0 else {
            return Color(hue: tintHue, saturation: 0.32, brightness: isDark ? 1.0 : 0.86)
        }
        return isDark
            ? Color(red: 0.88, green: 0.95, blue: 1.00)
            : Color(red: 0.66, green: 0.79, blue: 0.93)
    }

    private static func tipGlintColor(isDark: Bool, tintHue: Double) -> Color {
        guard tintHue < 0 else {
            return Color(hue: tintHue, saturation: 0.1, brightness: 1.0)
        }
        return isDark ? Color.white : Color(red: 0.82, green: 0.90, blue: 0.98)
    }

    // MARK: - LCG helpers

    /// One warm-up step to mix the initial seed before first use.
    private static func lcgSeed(_ initial: UInt64) -> UInt64 {
        initial &* 6364136223846793005 &+ 1442695040888963407
    }

    /// Advances the LCG and returns a [0, 1) double.
    private static func lcgFrac(_ seed: inout UInt64) -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double(seed >> 33) / Double(1 << 31)
    }
}
