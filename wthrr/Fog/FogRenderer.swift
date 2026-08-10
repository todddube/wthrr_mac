// FogRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Fog renderer

/// Draws slow-drifting translucent fog bands and wisp particles.
enum FogRenderer {
    /// Renders all fog elements: horizontal gradient bands followed by large soft wisp particles.
    /// Bands and wisps are drawn front-to-back, both using gradient fills to simulate
    /// a soft-focus blur without the GPU cost of an actual blur filter.
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points.
    ///   - isDark: Whether the system is in dark mode (affects fog base colour).
    ///   - particles: Active fog wisp particles to render as radial-gradient ellipses.
    ///   - fogBands: Active horizontal gradient bands drifting across the screen.
    ///   - particleOpacity: Global opacity multiplier from `WeatherSettings`.
    ///   - tintHue: Custom hue value (-1 = default white/gray).
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        particles: [Particle],
        fogBands: [FogBand],
        particleOpacity: Double = 1.0,
        tintHue: Double = -1
    ) {
        let baseColor = ColorTheme.fogBaseColor(isDark: isDark, hue: tintHue)

        // Both gradients are identical for every band and every wisp — only the
        // geometry varies. Building them inside the loops meant allocating a `Gradient`
        // and its `Color` stops once per element per frame: with 400 wisps that was
        // ~1,600 throwaway allocations every single frame.
        let bandGradient = Gradient(colors: [
            baseColor.opacity(0),
            baseColor.opacity(0.5),
            baseColor.opacity(0.8),
            baseColor.opacity(0.5),
            baseColor.opacity(0)
        ])
        let wispGradient = Gradient(colors: [
            baseColor.opacity(0.6),
            baseColor.opacity(0.25),
            baseColor.opacity(0)
        ])

        // Draw fog bands — large translucent horizontal gradient strips
        let midX = size.width / 2
        for band in fogBands {
            let topY = band.y - band.height / 2
            let rect = CGRect(x: 0, y: topY, width: size.width, height: band.height)

            var ctx = context
            ctx.opacity = band.opacity * particleOpacity
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    bandGradient,
                    startPoint: CGPoint(x: midX, y: topY),
                    endPoint: CGPoint(x: midX, y: band.y + band.height / 2)
                )
            )
        }

        // Draw wisp particles — large soft ellipses using radial gradients
        // (avoids per-particle blur filters which are expensive GPU passes)
        guard !particles.isEmpty else { return }

        // Resolve one unit-circle shading and reuse it for every wisp, positioning and
        // squashing it with the context transform instead of rebuilding a shading whose
        // centre and radius are baked in. One `resolve` per frame rather than one per wisp.
        let unitShading = context.resolve(
            .radialGradient(wispGradient, center: .zero, startRadius: 0, endRadius: 1)
        )
        // The wisp is a flattened ellipse but the gradient over it is *circular* — the
        // ellipse clips the gradient part-way through, which is what gives wisps their
        // defined upper and lower edge. Scaling uniformly below keeps that relationship
        // intact; an anisotropic scale would stretch the gradient with the path and
        // wash the edges out.
        let unitWisp = Path(ellipseIn: CGRect(x: -1, y: -0.4, width: 2, height: 0.8))

        for particle in particles {
            var ctx = context
            ctx.opacity = particle.opacity * particleOpacity

            let r = particle.size * 2.5
            ctx.translateBy(x: particle.x, y: particle.y)
            ctx.scaleBy(x: r, y: r)
            ctx.fill(unitWisp, with: unitShading)
        }
    }
}
