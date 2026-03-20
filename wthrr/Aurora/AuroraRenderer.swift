// AuroraRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Aurora renderer

/// Draws slow-rippling vertical aurora bands across the full screen.
/// Pure gradient animation — no particle physics needed.
enum AuroraRenderer {
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        time: CGFloat,
        particleOpacity: Double = 1.0
    ) {
        let bandCount = 5
        let colors: [Color] = [
            Color(red: 0.1, green: 0.9, blue: 0.4),   // green
            Color(red: 0.2, green: 0.6, blue: 0.9),   // teal
            Color(red: 0.5, green: 0.2, blue: 0.9),   // purple
            Color(red: 0.1, green: 0.8, blue: 0.6),   // aqua
            Color(red: 0.3, green: 0.9, blue: 0.3),   // bright green
        ]

        for i in 0..<bandCount {
            let phase = CGFloat(i) * 1.3 + time * 0.15
            let xCenter = size.width * (0.15 + CGFloat(i) * 0.18) + sin(phase) * size.width * 0.08
            let bandWidth = size.width * CGFloat(0.12 + 0.06 * sin(phase * 0.7))
            let bandHeight = size.height * CGFloat(0.4 + 0.2 * sin(phase * 0.5 + 1.0))
            let yOffset = size.height * CGFloat(0.05 + 0.1 * sin(phase * 0.3))

            let rect = CGRect(x: xCenter - bandWidth / 2, y: yOffset,
                               width: bandWidth, height: bandHeight)

            var ctx = context
            let opacity = (0.08 + 0.06 * sin(phase * 0.9)) * particleOpacity
            ctx.opacity = isDark ? opacity : opacity * 0.6

            let color = colors[i % colors.count]
            let gradient = Gradient(colors: [
                color.opacity(0),
                color.opacity(0.4),
                color.opacity(0.7),
                color.opacity(0.4),
                color.opacity(0)
            ])

            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: xCenter - bandWidth / 2, y: yOffset),
                    endPoint: CGPoint(x: xCenter + bandWidth / 2, y: yOffset)
                )
            )

            // Vertical fade
            let vGradient = Gradient(colors: [
                .clear,
                color.opacity(0.3),
                color.opacity(0.5),
                color.opacity(0.2),
                .clear
            ])
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    vGradient,
                    startPoint: CGPoint(x: xCenter, y: yOffset),
                    endPoint: CGPoint(x: xCenter, y: yOffset + bandHeight)
                )
            )
        }
    }
}
