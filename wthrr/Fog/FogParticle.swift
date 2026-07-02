// FogParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation

// MARK: - Fog data types

/// A horizontal gradient band that drifts slowly down the screen.
struct FogBand {
    var y: CGFloat              // Vertical center position
    var height: CGFloat         // Vertical extent of the gradient band
    let speed: CGFloat          // Drift speed in pts/s (very slow: 3-12)
    let opacity: Double         // Peak opacity (0.06 - 0.18)
    let phase: CGFloat          // Phase offset for subtle horizontal undulation
}

// MARK: - Fog particle factory

/// Creates fog wisp particles — large, slow, translucent.
enum FogParticleFactory {
    /// Creates a single fog wisp with randomised position, size, and drift parameters.
    /// Wisps are intentionally very low-opacity (0.03-0.12) and large (8-30 pt radius)
    /// so many can overlap without obscuring the wallpaper.
    /// - Parameters:
    ///   - startY: Initial vertical position in points.
    ///   - screenWidth: Width of the target display in points.
    ///   - rng: Seeded random number generator for deterministic output.
    /// - Returns: A fully configured `Particle` representing a fog wisp.
    static func makeWisp(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        let size = CGFloat(rng.next(in: 8...30))
        return Particle(
            x: CGFloat(rng.next(in: 0...Double(screenWidth))),
            y: startY,
            rotation: 0,
            rotationSpeed: 0,
            shape: .dot,
            tint: 0,
            size: size,
            length: size * 3,
            fallSpeed: CGFloat(rng.next(in: 4...15)),
            wobbleAmp: CGFloat(rng.next(in: 8...30)),
            wobbleFreq: CGFloat(rng.next(in: 0.15...0.4)),
            wobblePhase: CGFloat(rng.next(in: 0...6.28)),
            windSensitivity: CGFloat(rng.next(in: 0.6...1.2)),
            opacity: rng.next(in: 0.03...0.12)
        )
    }
}
