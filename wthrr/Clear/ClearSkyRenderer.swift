// ClearSkyRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Clear sky renderer

/// Renders the fair-weather scene: a sun (or moon after dark) tracking an arc across
/// the sky, volumetric light shafts, lens flare, drifting motes, and birds.
///
/// Clouds are drawn separately by `CloudRenderer` so they can be layered *behind* the
/// light shafts, which is what makes the shafts read as light rather than as decals.
///
/// Everything is derived from `SkyState` plus elapsed time — there is no persistent
/// state, so the scene is correct immediately on the first frame after a mode switch.
enum ClearSkyRenderer {

    /// Draws the complete clear-sky scene except the clouds.
    ///
    /// - Parameters:
    ///   - context:         Canvas graphics context.
    ///   - size:            Full canvas size in points.
    ///   - isDark:          System dark mode; dims the whole scene so it doesn't glare.
    ///   - sky:             Sun/moon position and colour temperature for the current time.
    ///   - time:            Elapsed clear-mode time in seconds; drives ray shimmer and birds.
    ///   - particles:       Drifting motes.
    ///   - particleOpacity: Global opacity multiplier from `WeatherSettings`.
    ///   - raysEnabled:     Whether to draw the volumetric light shafts.
    ///   - birdCount:       Number of birds (0 = none).
    ///   - birdSize:        Bird size multiplier.
    ///   - birdWildness:    Bird variation (0 uniform → 1 chaotic).
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        sky: SkyState,
        time: CGFloat,
        particles: [Particle],
        particleOpacity: Double,
        raysEnabled: Bool,
        birdCount: Int,
        birdSize: Double,
        birdWildness: Double
    ) {
        // The overlay sits on top of the user's desktop, so everything here is additive
        // and translucent — we tint the wallpaper rather than replacing it.
        let scene = particleOpacity * (isDark ? 0.72 : 1.0)
        let origin = CGPoint(x: sky.x * size.width, y: sky.y * size.height)

        drawSkyWash(context: context, size: size, sky: sky, scene: scene)

        if raysEnabled {
            drawLightShafts(context: context, size: size, sky: sky,
                            origin: origin, time: time, scene: scene)
        }

        drawLightSource(context: context, size: size, sky: sky,
                        origin: origin, time: time, scene: scene)

        drawLensFlare(context: context, size: size, sky: sky,
                      origin: origin, scene: scene)

        drawMotes(context: context, sky: sky, origin: origin,
                  particles: particles, particleOpacity: particleOpacity, isDark: isDark)

        // Birds sit lower in the frame than in Aurora so they cross in front of the
        // clouds rather than hugging the very top edge.
        BirdRenderer.draw(
            context: context, size: size, time: time,
            count: birdCount, sizeScale: birdSize, wildness: birdWildness,
            color: sky.isNight ? .white : Color(white: 0.12),
            opacity: scene * (sky.isNight ? 0.5 : 0.65),
            bandTop: 0.10,
            bandDepth: 0.26
        )
    }

    // MARK: - Sky wash

    /// A soft vertical tint over the whole screen: warm gold low on the horizon at
    /// dawn and dusk, cool blue at midday, deep indigo at night. Kept very light so
    /// the desktop stays readable.
    private static func drawSkyWash(
        context: GraphicsContext,
        size: CGSize,
        sky: SkyState,
        scene: Double
    ) {
        let top: Color
        let bottom: Color

        if sky.isNight {
            top    = Color(red: 0.05, green: 0.07, blue: 0.22)
            bottom = Color(red: 0.10, green: 0.10, blue: 0.20)
        } else {
            // Blend the midday blue toward golden as the sun approaches a horizon.
            let g = sky.goldenness
            top = Color(
                red:   0.35 + 0.45 * g,
                green: 0.62 + 0.18 * g,
                blue:  0.95 - 0.45 * g
            )
            bottom = Color(
                red:   0.85 * g + 0.55 * (1 - g),
                green: 0.62 * g + 0.75 * (1 - g),
                blue:  0.40 * g + 0.92 * (1 - g)
            )
        }

        var ctx = context
        ctx.opacity = scene * (sky.isNight ? 0.22 : 0.16)
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [top.opacity(0.9), bottom.opacity(0.15)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    // MARK: - Volumetric light shafts

    /// Long translucent wedges fanning out from the light source. Each shaft slowly
    /// breathes in width and length on its own phase, which reads as light moving
    /// through air rather than a static starburst.
    private static func drawLightShafts(
        context: GraphicsContext,
        size: CGSize,
        sky: SkyState,
        origin: CGPoint,
        time: CGFloat,
        scene: Double
    ) {
        // Shafts fade out when the light source is near a horizon and at night.
        let strength = sky.isNight ? 0.30 : (0.45 + 0.55 * sky.altitude)
        guard strength > 0.02 else { return }

        let shaftCount = 11
        let reach = hypot(size.width, size.height) * 1.15
        let hue: Color = sky.isNight
            ? Color(red: 0.80, green: 0.86, blue: 1.0)
            : Color(red: 1.0, green: 0.94 - 0.16 * sky.goldenness, blue: 0.72 - 0.32 * sky.goldenness)

        var ctx = context
        ctx.opacity = scene * strength * 0.13

        for i in 0..<shaftCount {
            let fi = CGFloat(i)
            // Spread the fan slightly wider than a half-turn and rotate it very slowly.
            let base = (fi / CGFloat(shaftCount)) * .pi * 2 + time * 0.012
            // Per-shaft breathing on independent phases.
            let breathe = 0.55 + 0.45 * sin(time * 0.23 + fi * 1.7)
            let halfWidth = (0.012 + 0.030 * breathe) * .pi
            let length = reach * (0.55 + 0.45 * breathe)

            var path = Path()
            path.move(to: origin)
            path.addLine(to: CGPoint(
                x: origin.x + cos(base - halfWidth) * length,
                y: origin.y + sin(base - halfWidth) * length
            ))
            path.addLine(to: CGPoint(
                x: origin.x + cos(base + halfWidth) * length,
                y: origin.y + sin(base + halfWidth) * length
            ))
            path.closeSubpath()

            // Fade each wedge along its length so it dissolves instead of ending abruptly.
            ctx.fill(
                path,
                with: .radialGradient(
                    Gradient(colors: [hue.opacity(0.95), hue.opacity(0.35), .clear]),
                    center: origin,
                    startRadius: 0,
                    endRadius: length
                )
            )
        }
    }

    // MARK: - Sun / moon

    /// The light source itself: a layered glow, a bright core, and — for the moon —
    /// a few craters and a scatter of stars.
    private static func drawLightSource(
        context: GraphicsContext,
        size: CGSize,
        sky: SkyState,
        origin: CGPoint,
        time: CGFloat,
        scene: Double
    ) {
        let core: CGFloat = min(size.width, size.height) * (sky.isNight ? 0.045 : 0.058)
        // Gentle pulse so the disc doesn't look pasted on.
        let pulse = 1.0 + 0.03 * sin(time * 0.6)

        let bodyColor: Color = sky.isNight
            ? Color(red: 0.94, green: 0.95, blue: 1.0)
            : Color(red: 1.0, green: 0.96 - 0.10 * sky.goldenness, blue: 0.80 - 0.35 * sky.goldenness)

        if sky.isNight { drawStars(context: context, size: size, scene: scene, time: time) }

        // Outer halo — large, very soft.
        var haloCtx = context
        haloCtx.opacity = scene * (sky.isNight ? 0.30 : 0.42)
        let haloR = core * 7.5 * pulse
        haloCtx.fill(
            Path(ellipseIn: CGRect(x: origin.x - haloR, y: origin.y - haloR,
                                   width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [bodyColor.opacity(0.55), bodyColor.opacity(0.14), .clear]),
                center: origin, startRadius: 0, endRadius: haloR
            )
        )

        // Inner glow — tighter and brighter.
        var glowCtx = context
        glowCtx.opacity = scene * 0.75
        let glowR = core * 2.6 * pulse
        glowCtx.fill(
            Path(ellipseIn: CGRect(x: origin.x - glowR, y: origin.y - glowR,
                                   width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [bodyColor.opacity(0.9), bodyColor.opacity(0.25), .clear]),
                center: origin, startRadius: 0, endRadius: glowR
            )
        )

        // Core disc.
        var coreCtx = context
        coreCtx.opacity = scene * (sky.isNight ? 0.85 : 0.95)
        let r = core * pulse
        let discRect = CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)
        coreCtx.fill(Path(ellipseIn: discRect), with: .color(bodyColor))

        if sky.isNight {
            // A few craters give the moon some form.
            var craterCtx = context
            craterCtx.opacity = scene * 0.28
            let craters: [(CGFloat, CGFloat, CGFloat)] = [
                (-0.30, -0.22, 0.24), (0.26, 0.10, 0.18), (-0.10, 0.34, 0.14), (0.34, -0.34, 0.11)
            ]
            for (cx, cy, cr) in craters {
                let rad = r * cr
                craterCtx.fill(
                    Path(ellipseIn: CGRect(x: origin.x + cx * r - rad,
                                           y: origin.y + cy * r - rad,
                                           width: rad * 2, height: rad * 2)),
                    with: .color(Color(red: 0.55, green: 0.58, blue: 0.70))
                )
            }
        }
    }

    /// A deterministic scatter of stars for the night sky, twinkling out of phase.
    private static func drawStars(
        context: GraphicsContext,
        size: CGSize,
        scene: Double,
        time: CGFloat
    ) {
        var ctx = context
        ctx.opacity = scene * 0.7

        var rng = SeededRNG(seed: 0x5EED_57A2)
        for i in 0..<70 {
            let x = CGFloat(rng.next01()) * size.width
            // Keep stars in the upper two-thirds — the lower screen is usually busy.
            let y = CGFloat(rng.next01()) * size.height * 0.68
            let base = CGFloat(rng.next(in: 0.5...1.5))
            let twinkle = 0.55 + 0.45 * sin(time * CGFloat(rng.next(in: 0.6...2.0)) + CGFloat(i))
            let r = base * twinkle
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.75))
            )
        }
    }

    // MARK: - Lens flare

    /// Small ghost discs spaced along the line from the light source through the centre
    /// of the screen — the classic in-camera flare that sells a bright light source.
    private static func drawLensFlare(
        context: GraphicsContext,
        size: CGSize,
        sky: SkyState,
        origin: CGPoint,
        scene: Double
    ) {
        guard !sky.isNight, sky.altitude > 0.05 else { return }

        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = centre.x - origin.x
        let dy = centre.y - origin.y

        // (distance along the axis, radius as a fraction of the short edge, opacity, tint)
        let ghosts: [(CGFloat, CGFloat, Double, Color)] = [
            (0.55, 0.020, 0.16, Color(red: 1.0, green: 0.85, blue: 0.55)),
            (0.90, 0.034, 0.11, Color(red: 0.65, green: 0.95, blue: 0.85)),
            (1.30, 0.014, 0.14, Color(red: 1.0, green: 0.70, blue: 0.60)),
            (1.72, 0.046, 0.08, Color(red: 0.70, green: 0.80, blue: 1.00)),
            (2.10, 0.010, 0.12, Color(red: 1.0, green: 0.95, blue: 0.75)),
        ]

        let shortEdge = min(size.width, size.height)
        var ctx = context
        ctx.opacity = scene * sky.altitude

        for (t, rFrac, alpha, tint) in ghosts {
            let p = CGPoint(x: origin.x + dx * t, y: origin.y + dy * t)
            let r = shortEdge * rFrac
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(alpha), tint.opacity(alpha * 0.35), .clear]),
                    center: p, startRadius: 0, endRadius: r
                )
            )
        }
    }

    // MARK: - Motes

    /// Drifting pollen and dust. Motes near the light source are brighter and warmer,
    /// as though catching it — the cheap trick that ties the particles to the scene.
    private static func drawMotes(
        context: GraphicsContext,
        sky: SkyState,
        origin: CGPoint,
        particles: [Particle],
        particleOpacity: Double,
        isDark: Bool
    ) {
        guard !particles.isEmpty else { return }

        let lit: Color = sky.isNight
            ? Color(red: 0.85, green: 0.90, blue: 1.0)
            : Color(red: 1.0, green: 0.95, blue: 0.78)
        let plain: Color = isDark ? Color(white: 0.85) : Color(white: 1.0)

        // Motes within this distance of the light source get the warm treatment.
        let litRadius: CGFloat = 420

        for m in particles {
            let d = hypot(m.x - origin.x, m.y - origin.y)
            let litness = max(0, 1 - d / litRadius)

            var ctx = context
            ctx.opacity = m.opacity * particleOpacity * (0.55 + 0.85 * litness)

            let r = m.size * (1 + 0.6 * litness)
            let rect = CGRect(x: m.x - r, y: m.y - r, width: r * 2, height: r * 2)

            // A soft halo on the brightest motes reads as bokeh.
            if litness > 0.25 {
                let hr = r * 3.2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: m.x - hr, y: m.y - hr, width: hr * 2, height: hr * 2)),
                    with: .radialGradient(
                        Gradient(colors: [lit.opacity(0.35 * litness), .clear]),
                        center: CGPoint(x: m.x, y: m.y), startRadius: 0, endRadius: hr
                    )
                )
            }

            ctx.fill(Path(ellipseIn: rect), with: .color(litness > 0.15 ? lit : plain))
        }
    }
}
