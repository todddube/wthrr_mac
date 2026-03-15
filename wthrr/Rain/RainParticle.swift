// RainParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import Foundation

// MARK: - Rain data types

/// A short-lived splash effect spawned when a raindrop hits the ground or a puddle.
/// Expands and fades over its lifetime, then is removed by the animation model.
struct Splash {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat         // Expands over lifetime
    var opacity: Double         // Fades to zero over lifetime
    var age: CGFloat            // Seconds elapsed since spawning
    let lifetime: CGFloat       // Total duration (0.2 - 0.4 s)
}

/// A puddle that forms at the bottom of the screen in rain + puddles mode.
/// Puddles grow as raindrops land nearby, capped at a maximum height, and display
/// ripple rings when splashes occur close by.
struct Puddle {
    var x: CGFloat              // Horizontal centre
    var width: CGFloat          // Horizontal extent
    var height: CGFloat         // Vertical half-height (max 18 pts)
    var opacity: Double         // 0.55 - 0.80
    var rippleRadius: CGFloat   // Active ripple ring radius (0 = no ripple)
    var rippleOpacity: Double   // Fades as ripple expands
}

// MARK: - Lightning

/// A lightning bolt composed of jagged line segments, visible for a brief flash.
/// The bolt originates near the top of the screen and zigzags downward.
struct LightningBolt {
    let segments: [CGPoint]     // Ordered points from top to bottom forming the bolt path
    var age: CGFloat = 0        // Seconds elapsed since the strike
    let lifetime: CGFloat       // Total visible duration (~0.35 s)
    var flashOpacity: Double    // Full-screen flash intensity, fades quickly
}

// MARK: - Rain particle factory

/// Creates rain particles with randomised streak properties.
enum RainParticleFactory {

    /// Creates a single raindrop with randomised properties.
    /// Raindrops are thin, fast-falling streaks with minimal wobble.
    /// - Parameters:
    ///   - startY: Initial vertical position in points.
    ///   - screenWidth: Width of the target display in points.
    ///   - rng: Seeded random number generator for deterministic output.
    /// - Returns: A fully configured `Particle` representing a raindrop.
    static func makeRaindrop(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        let size = CGFloat(rng.next(in: 0.8...1.8))
        return Particle(
            x: CGFloat(rng.next(in: -20...max(Double(screenWidth) + 20, 1))),
            y: startY,
            rotation: 0,
            rotationSpeed: 0,
            shape: .dot,        // Unused for rain rendering
            tint: 0,
            size: size,
            length: CGFloat(rng.next(in: 8...25)),
            fallSpeed: CGFloat(rng.next(in: 300...600)),
            wobbleAmp: CGFloat(rng.next(in: 0.0...0.3)),
            wobbleFreq: CGFloat(rng.next(in: 0.2...0.8)),
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.3...0.7)),
            opacity: rng.next(in: 0.55...0.85)
        )
    }
}
