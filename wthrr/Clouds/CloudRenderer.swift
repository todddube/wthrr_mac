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
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        clouds: [Cloud],
        weatherType: WeatherType
    ) {
        for cloud in clouds {
            switch weatherType {
            case .snow, .rain:
                drawNaturalCloud(context: context, cloud: cloud, isDark: isDark)
            case .aiStorm:
                drawAICloud(context: context, cloud: cloud, isDark: isDark)
            }
        }
    }

    // MARK: Natural clouds (snow / rain)

    /// Draws a soft, grayish cloud composed of overlapping ellipses.
    private static func drawNaturalCloud(
        context: GraphicsContext,
        cloud: Cloud,
        isDark: Bool
    ) {
        var rng = SeededRNG(seed: cloud.blobSeed)
        let baseGray: Double = isDark ? 0.55 : 0.72

        for _ in 0..<cloud.blobCount {
            let blobW = cloud.width * CGFloat(rng.next(in: 0.35...0.7))
            let blobH = cloud.height * CGFloat(rng.next(in: 0.5...1.0))
            let offsetX = CGFloat(rng.next(in: -0.4...0.4)) * cloud.width
            let offsetY = CGFloat(rng.next(in: -0.3...0.3)) * cloud.height

            let cx = cloud.x + offsetX
            let cy = cloud.y + offsetY

            let grayShift = rng.next(in: -0.08...0.08)
            let gray = baseGray + grayShift
            let alpha = cloud.opacity * rng.next(in: 0.6...1.0)

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
    private static func drawAICloud(
        context: GraphicsContext,
        cloud: Cloud,
        isDark: Bool
    ) {
        let neonPalette: [(Double, Double, Double)] = [
            (0.0, 1.0, 0.9),   // cyan
            (0.85, 0.0, 1.0),  // magenta
            (0.2, 1.0, 0.2),   // green
        ]
        let palette = neonPalette[cloud.colorVariant % neonPalette.count]

        var rng = SeededRNG(seed: cloud.blobSeed)

        // Glitchy rectangular blocks instead of smooth ellipses
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
            ).opacity(cloud.opacity * rng.next(in: 0.5...1.0))

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
            ).opacity(cloud.opacity * 1.5)

            context.stroke(
                path,
                with: .color(lineColor),
                lineWidth: CGFloat(rng.next(in: 0.5...1.5))
            )
        }
    }
}
