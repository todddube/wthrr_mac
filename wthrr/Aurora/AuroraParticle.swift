// AuroraParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation

// MARK: - Aurora particle factory

/// Creates aurora "band" particles — very slow, large, translucent.
/// These are mostly cosmetic — the real aurora is drawn by the renderer's gradient animation.
enum AuroraParticleFactory {
    /// Creates a single aurora band particle used as a subtle secondary layer of movement.
    /// Opacity is kept very low (0.02-0.06) since the primary aurora visual is produced
    /// by `AuroraRenderer`'s time-driven gradient animation rather than these particles.
    /// - Parameters:
    ///   - startY: Initial vertical position in points.
    ///   - screenWidth: Width of the target display in points.
    ///   - rng: Seeded random number generator for deterministic output.
    /// - Returns: A fully configured `Particle` representing an aurora band element.
    static func makeBand(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        let size = CGFloat(rng.next(in: 15...40))
        return Particle(
            x: CGFloat(rng.next(in: 0...Double(screenWidth))),
            y: startY,
            rotation: 0,
            rotationSpeed: 0,
            shape: .dot,
            tint: rng.next(in: 0...1),
            size: size,
            length: size,
            fallSpeed: CGFloat(rng.next(in: 1...5)),
            wobbleAmp: CGFloat(rng.next(in: 15...40)),
            wobbleFreq: CGFloat(rng.next(in: 0.05...0.15)),
            wobblePhase: CGFloat(rng.next(in: 0...6.28)),
            windSensitivity: CGFloat(rng.next(in: 0.3...0.6)),
            opacity: rng.next(in: 0.02...0.06)
        )
    }
}
