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

        // Draw fog bands — large translucent horizontal gradient strips
        for band in fogBands {
            let topY = band.y - band.height / 2
            let bottomY = band.y + band.height / 2
            let rect = CGRect(x: 0, y: topY, width: size.width, height: band.height)

            var ctx = context
            ctx.opacity = band.opacity * particleOpacity

            let gradient = Gradient(colors: [
                baseColor.opacity(0),
                baseColor.opacity(0.5),
                baseColor.opacity(0.8),
                baseColor.opacity(0.5),
                baseColor.opacity(0)
            ])
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: size.width / 2, y: topY),
                    endPoint: CGPoint(x: size.width / 2, y: bottomY)
                )
            )
        }

        // Draw wisp particles — large soft ellipses using radial gradients
        // (avoids per-particle blur filters which are expensive GPU passes)
        for particle in particles {
            var ctx = context
            ctx.opacity = particle.opacity * particleOpacity

            // Scale up the ellipse and use a radial gradient to simulate blur
            let r = particle.size * 2.5
            let center = CGPoint(x: particle.x, y: particle.y)
            let rect = CGRect(x: particle.x - r, y: particle.y - r * 0.4,
                               width: r * 2, height: r * 0.8)
            let gradient = Gradient(colors: [
                baseColor.opacity(0.6),
                baseColor.opacity(0.25),
                baseColor.opacity(0)
            ])
            ctx.fill(
                Ellipse().path(in: rect),
                with: .radialGradient(gradient, center: center,
                                       startRadius: 0, endRadius: r)
            )
        }
    }
}
