// CloudRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Cloud renderer

/// Draws translucent clouds near the top of the screen.
/// Snow and rain clouds are grayish; AI storm clouds use neon/glitch colors.
enum CloudRenderer {

    /// Draws all clouds into the given graphics context.
    /// Natural weather types (snow, rain, fog, aurora, thunderstorm) receive soft gray ellipse
    /// clouds; AI Storm receives angular neon-edged blocks with scanline accents.
    /// - Parameters:
    ///   - context: The Canvas graphics context to draw into.
    ///   - size: The full size of the canvas in points (unused, but provided for future clipping).
    ///   - isDark: Whether the system is in dark mode (affects base gray lightness).
    ///   - clouds: The current cloud population to render.
    ///   - weatherType: Determines which cloud style (natural vs. AI glitch) to use.
    ///   - cloudOpacity: Global cloud opacity multiplier from `WeatherSettings`.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        clouds: [Cloud],
        weatherType: WeatherType,
        cloudOpacity: Double = 1.0
    ) {
        for cloud in clouds {
            switch weatherType {
            case .snow, .rain, .thunderstorm, .fog, .aurora:
                drawNaturalCloud(context: context, cloud: cloud, isDark: isDark, cloudOpacity: cloudOpacity)
            case .aiStorm:
                drawAICloud(context: context, cloud: cloud, isDark: isDark, cloudOpacity: cloudOpacity)
            }
        }
    }

    // MARK: Natural clouds (snow / rain)

    /// Draws a soft, grayish cloud composed of overlapping ellipses.
    /// Each blob gets a slight random gray shift and opacity variation so the cloud
    /// looks volumetric rather than uniform. The `blobSeed` from the cloud struct
    /// ensures the blob layout is deterministic — blobs don't jitter between frames.
    private static func drawNaturalCloud(
        context: GraphicsContext,
        cloud: Cloud,
        isDark: Bool,
        cloudOpacity: Double = 1.0
    ) {
        // Re-create the same RNG used at cloud creation so blob placement is stable
        var rng = SeededRNG(seed: cloud.blobSeed)
        // Darker base in light mode so clouds have contrast against bright wallpapers
        let baseGray: Double = isDark ? 0.55 : 0.72

        for _ in 0..<cloud.blobCount {
            let blobW = cloud.width * CGFloat(rng.next(in: 0.35...0.7))
            let blobH = cloud.height * CGFloat(rng.next(in: 0.5...1.0))
            let offsetX = CGFloat(rng.next(in: -0.4...0.4)) * cloud.width
            let offsetY = CGFloat(rng.next(in: -0.3...0.3)) * cloud.height

            let cx = cloud.x + offsetX
            let cy = cloud.y + offsetY

            // Small per-blob gray variation gives the cloud visual texture
            let grayShift = rng.next(in: -0.08...0.08)
            let gray = baseGray + grayShift
            let alpha = cloud.opacity * cloudOpacity * rng.next(in: 0.6...1.0)

            let rect = CGRect(
                x: cx - blobW / 2,
                y: cy - blobH / 2,
                width: blobW,
                height: blobH
            )
            let color = Color(
                red: gray - 0.02,
                green: gray,
                blue: gray + 0.04
            ).opacity(alpha)

            context.fill(Ellipse().path(in: rect), with: .color(color))
        }
    }

    // MARK: AI storm clouds

    /// Draws a glitchy, neon-edged cloud with digital artifacts.
    /// Instead of smooth ellipses, uses dark rectangles with a neon tint and
    /// horizontal scanline edges for a corrupted-monitor aesthetic.
    private static func drawAICloud(
        context: GraphicsContext,
        cloud: Cloud,
        isDark: Bool,
        cloudOpacity: Double = 1.0
    ) {
        // Three neon hues; `colorVariant` selects one per cloud at creation time
        let neonPalette: [(Double, Double, Double)] = [
            (0.0, 1.0, 0.9),   // cyan
            (0.85, 0.0, 1.0),  // magenta
            (0.2, 1.0, 0.2),   // green
        ]
        let palette = neonPalette[cloud.colorVariant % neonPalette.count]

        // Reuse blobSeed so block placement is frame-stable (no jitter)
        var rng = SeededRNG(seed: cloud.blobSeed)

        // Glitchy rectangular blocks instead of smooth ellipses — 2 extra for density
        let blockCount = cloud.blobCount + 2
        for _ in 0..<blockCount {
            let bW = cloud.width * CGFloat(rng.next(in: 0.15...0.55))
            let bH = cloud.height * CGFloat(rng.next(in: 0.2...0.7))
            let offX = CGFloat(rng.next(in: -0.45...0.45)) * cloud.width
            let offY = CGFloat(rng.next(in: -0.35...0.35)) * cloud.height

            let rect = CGRect(
                x: cloud.x + offX - bW / 2,
                y: cloud.y + offY - bH / 2,
                width: bW,
                height: bH
            )

            // Dark fill with slight neon tint
            let tintStrength = rng.next(in: 0.05...0.2)
            let fillColor = Color(
                red: palette.0 * tintStrength + 0.08,
                green: palette.1 * tintStrength + 0.08,
                blue: palette.2 * tintStrength + 0.08
            ).opacity(cloud.opacity * cloudOpacity * rng.next(in: 0.5...1.0))

            context.fill(Rectangle().path(in: rect), with: .color(fillColor))
        }

        // Neon edge lines — a few horizontal scan-line style edges
        let edgeCount = Int(rng.next(in: 2...4.99))
        for _ in 0..<edgeCount {
            let ly = cloud.y + CGFloat(rng.next(in: -0.4...0.4)) * cloud.height
            let lx1 = cloud.x - cloud.width * CGFloat(rng.next(in: 0.2...0.5))
            let lx2 = cloud.x + cloud.width * CGFloat(rng.next(in: 0.2...0.5))

            var path = Path()
            path.move(to: CGPoint(x: lx1, y: ly))
            path.addLine(to: CGPoint(x: lx2, y: ly))

            let lineColor = Color(
                red: palette.0,
                green: palette.1,
                blue: palette.2
            ).opacity(cloud.opacity * cloudOpacity * 1.5)

            context.stroke(
                path,
                with: .color(lineColor),
                lineWidth: CGFloat(rng.next(in: 0.5...1.5))
            )
        }
    }
}
