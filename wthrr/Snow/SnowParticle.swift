// SnowParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import Foundation

// MARK: - Snow shape

/// Visual shape category for snow crystals.
/// Small flakes render as dots, medium as star plates, and large as branching dendrites.
enum SnowShape {
    case dot         // Small round pellet — graupel / sleety drop
    case star        // 6-arm star with short crossbars — classic plate crystal
    case dendrite    // 3-axis branching crystal — most intricate, largest flakes only
}

// MARK: - Snow particle factory

/// Creates snow particles with randomised crystal properties.
enum SnowParticleFactory {

    /// Creates a single snowflake with randomised properties.
    /// Larger flakes get intricate crystal shapes; smaller ones are simple dots.
    /// Larger flakes fall faster and are less wind-sensitive, giving a sense of depth.
    /// - Parameters:
    ///   - startY: Initial vertical position in points.
    ///   - screenWidth: Width of the target display in points.
    ///   - rng: Seeded random number generator for deterministic output.
    /// - Returns: A fully configured `Particle` representing a snowflake.
    static func makeFlake(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        let size = CGFloat(rng.next(in: 2.0...8.0))
        let sizeFactor = (size - 2.0) / 6.0   // 0 = smallest, 1 = largest

        // Shape distribution: small -> dot, medium -> star, large -> dendrite
        let shapeRoll = rng.next01()
        let shape: SnowShape
        if size < 3.5 {
            shape = .dot
        } else if size < 6.0 {
            shape = shapeRoll < 0.75 ? .star : .dot
        } else {
            shape = shapeRoll < 0.55 ? .dendrite : .star
        }

        return Particle(
            x: CGFloat(rng.next(in: -20...max(Double(screenWidth) + 20, 1))),
            y: startY,
            rotation: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            rotationSpeed: CGFloat(rng.next(in: -0.4...0.4)),
            shape: shape,
            tint: rng.next(in: 0.0...0.35),
            size: size,
            length: size * 2,
            fallSpeed: CGFloat(rng.next(in: 35...110)) * (0.45 + sizeFactor * 0.8),
            wobbleAmp: CGFloat(rng.next(in: 0.2...2.2)),
            wobbleFreq: CGFloat(rng.next(in: 0.3...2.0)),
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.5...1.5)) * (1.3 - sizeFactor * 0.7),
            opacity: rng.next(in: 0.45...0.95)
        )
    }
}
