// RainRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Rain renderer

/// Renders rain streaks, splash effects, and puddles onto a Canvas graphics context.
/// Streak angle varies with wind velocity for a natural wind-driven appearance.
enum RainRenderer {

    /// Draws all rain effects: lightning flash, puddles, streaks, splashes, and bolt.
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points.
    ///   - isDark: Whether the system is in dark mode (affects all rain colours).
    ///   - particles: The current array of rain particles to render.
    ///   - splashes: Active splash effects from raindrop impacts.
    ///   - puddles: Persistent puddles that grow during rain + puddles mode.
    ///   - windVelocity: Current horizontal wind speed in pts/s (tilts rain streaks).
    ///   - bolt: The currently active lightning bolt, or nil if no strike is in progress.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        particles: [Particle],
        splashes: [Splash],
        puddles: [Puddle],
        windVelocity: CGFloat,
        bolt: LightningBolt? = nil,
        particleOpacity: Double = 1.0
    ) {
        let rainColor: Color = isDark
            ? Color(red: 0.78, green: 0.88, blue: 1.0)
            : Color(red: 0.55, green: 0.65, blue: 0.80)

        let splashColor: Color = isDark
            ? Color(red: 0.75, green: 0.88, blue: 1.0, opacity: 0.7)
            : Color(red: 0.50, green: 0.62, blue: 0.78, opacity: 0.6)

        // Screen flash behind everything
        if let bolt, bolt.flashOpacity > 0.001 {
            var flashCtx = context
            flashCtx.opacity = bolt.flashOpacity
            flashCtx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        }

        drawPuddles(context: context, size: size, isDark: isDark, puddles: puddles)
        drawStreaks(context: context, particles: particles, windVelocity: windVelocity,
                    rainColor: rainColor, particleOpacity: particleOpacity)
        drawSplashes(context: context, splashes: splashes, splashColor: splashColor)

        // Lightning bolt on top of everything
        if let bolt {
            drawLightningBolt(context: context, bolt: bolt)
        }
    }

    // MARK: Puddle rendering

    /// Renders puddles as ellipses at the screen bottom with a specular shine layer
    /// and expanding ripple rings triggered by nearby raindrop impacts.
    private static func drawPuddles(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        puddles: [Puddle]
    ) {
        let puddleBodyColor: Color = isDark
            ? Color(red: 0.30, green: 0.52, blue: 0.82, opacity: 0.72)
            : Color(red: 0.28, green: 0.46, blue: 0.72, opacity: 0.60)

        let puddleShineColor: Color = isDark
            ? Color(red: 0.65, green: 0.82, blue: 1.0, opacity: 0.35)
            : Color(red: 0.70, green: 0.84, blue: 1.0, opacity: 0.28)

        let rippleColor: Color = isDark
            ? Color(red: 0.60, green: 0.80, blue: 1.0)
            : Color(red: 0.45, green: 0.65, blue: 0.90)

        for puddle in puddles where puddle.height > 0.5 {
            let halfH  = puddle.height
            let bodyY  = size.height - halfH
            let bodyH  = halfH * 2.2

            // Body ellipse
            let bodyRect = CGRect(
                x: puddle.x - puddle.width / 2,
                y: bodyY,
                width: puddle.width,
                height: bodyH
            )
            var bodyCtx = context
            bodyCtx.opacity = puddle.opacity
            bodyCtx.fill(Path(ellipseIn: bodyRect), with: .color(puddleBodyColor))

            // Specular shine — narrow ellipse across the upper third
            let shineW  = puddle.width * 0.55
            let shineH  = halfH * 0.45
            let shineRect = CGRect(
                x: puddle.x - shineW / 2,
                y: bodyY + halfH * 0.15,
                width: shineW,
                height: shineH
            )
            var shineCtx = context
            shineCtx.opacity = puddle.opacity * 0.9
            shineCtx.fill(Path(ellipseIn: shineRect), with: .color(puddleShineColor))

            // Ripple ring
            if puddle.rippleOpacity > 0.01 {
                let rr = puddle.rippleRadius
                let clampedRR = min(rr, puddle.width * 0.42)
                let rippleRect = CGRect(
                    x: puddle.x - clampedRR,
                    y: bodyY + halfH * 0.45 - clampedRR * 0.3,
                    width: clampedRR * 2,
                    height: clampedRR * 0.6
                )
                var rippleCtx = context
                rippleCtx.opacity = puddle.rippleOpacity
                rippleCtx.stroke(
                    Path(ellipseIn: rippleRect),
                    with: .color(rippleColor),
                    lineWidth: 1.0
                )
            }
        }
    }

    // MARK: Streak rendering

    /// Renders rain as angled streaks. Tilt angle is derived from wind velocity,
    /// clamped to +/-25 degrees for readability.
    private static func drawStreaks(
        context: GraphicsContext,
        particles: [Particle],
        windVelocity: CGFloat,
        rainColor: Color,
        particleOpacity: Double
    ) {
        let maxTiltDeg: CGFloat = 25
        let tiltAngle = CGFloat(atan2(windVelocity * 0.015, 1.0))
            .clamped(to: -maxTiltDeg * .pi / 180 ... maxTiltDeg * .pi / 180)

        for drop in particles {
            let halfLen = drop.length / 2
            let dx = sin(tiltAngle) * halfLen
            let dy = cos(tiltAngle) * halfLen
            let top    = CGPoint(x: drop.x - dx, y: drop.y - dy)
            let bottom = CGPoint(x: drop.x + dx, y: drop.y + dy)

            var path = Path()
            path.move(to: top)
            path.addLine(to: bottom)

            var ctx = context
            ctx.opacity = drop.opacity * particleOpacity
            ctx.stroke(path, with: .color(rainColor),
                       style: StrokeStyle(lineWidth: drop.size * 1.5, lineCap: .round))
        }
    }

    // MARK: Splash rendering

    /// Renders expanding elliptical splash rings with radiating droplet dots.
    private static func drawSplashes(
        context: GraphicsContext,
        splashes: [Splash],
        splashColor: Color
    ) {
        for splash in splashes {
            var ctx = context
            ctx.opacity = splash.opacity

            // Primary expanding elliptical ring at impact point
            let r = splash.radius
            let ringRect = CGRect(
                x: splash.x - r,
                y: splash.y - r * 0.35,
                width: r * 2,
                height: r * 0.7
            )
            ctx.stroke(Path(ellipseIn: ringRect), with: .color(splashColor), lineWidth: 1.2)

            // Second outer ring (slightly larger, more transparent)
            let r2 = r * 1.35
            let outerRect = CGRect(
                x: splash.x - r2,
                y: splash.y - r2 * 0.35,
                width: r2 * 2,
                height: r2 * 0.7
            )
            var outerCtx = context
            outerCtx.opacity = splash.opacity * 0.45
            outerCtx.stroke(Path(ellipseIn: outerRect), with: .color(splashColor), lineWidth: 0.7)

            // Four droplet dots radiating outward at compass points
            let dotR: CGFloat = 1.4
            let dotOffsets: [(CGFloat, CGFloat)] = [
                (-r * 0.7, -r * 0.55),
                ( r * 0.7, -r * 0.55),
                (-r * 0.35, -r * 0.85),
                ( r * 0.35, -r * 0.85)
            ]
            for (ox, oy) in dotOffsets {
                let dotRect = CGRect(x: splash.x + ox - dotR, y: splash.y + oy - dotR,
                                     width: dotR * 2, height: dotR * 2)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(splashColor))
            }
        }
    }

    // MARK: Lightning bolt rendering

    /// Draws a jagged lightning bolt with a soft glow behind a bright core stroke.
    /// Opacity fades over the bolt's lifetime for a natural flash-and-fade effect.
    private static func drawLightningBolt(context: GraphicsContext, bolt: LightningBolt) {
        guard bolt.segments.count >= 2 else { return }

        let progress = bolt.age / bolt.lifetime
        // Bolt fades out over its lifetime, with a brief re-brighten at 35-45%
        let boltOpacity: Double
        if progress < 0.15 {
            boltOpacity = 1.0
        } else if progress > 0.35 && progress < 0.45 {
            boltOpacity = 0.7
        } else {
            boltOpacity = Double(max(0, 1.0 - progress * 1.3))
        }
        guard boltOpacity > 0.01 else { return }

        var path = Path()
        path.move(to: bolt.segments[0])
        for i in 1..<bolt.segments.count {
            path.addLine(to: bolt.segments[i])
        }

        // Outer glow — wide, soft, purple-blue tinted
        var glowCtx = context
        glowCtx.opacity = boltOpacity * 0.35
        glowCtx.stroke(
            path,
            with: .color(Color(red: 0.6, green: 0.7, blue: 1.0)),
            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
        )

        // Mid glow — medium width, brighter
        var midCtx = context
        midCtx.opacity = boltOpacity * 0.6
        midCtx.stroke(
            path,
            with: .color(Color(red: 0.8, green: 0.85, blue: 1.0)),
            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
        )

        // Bright core — thin white
        var coreCtx = context
        coreCtx.opacity = boltOpacity
        coreCtx.stroke(
            path,
            with: .color(.white),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - CGFloat clamp helper

extension CGFloat {
    /// Clamps this value to the given closed range.
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
