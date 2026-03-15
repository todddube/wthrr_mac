// Particle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import Foundation

// MARK: - Particle

/// Value type representing a single weather particle's current position and immutable
/// physical characteristics. Position (x, y) is mutated each frame by the animation
/// model; all other fields are assigned once at spawn time.
/// Used for both snowflakes (with shape, tint, rotation) and raindrops (thin fast streaks).
struct Particle {
    var x: CGFloat
    var y: CGFloat
    var rotation: CGFloat       // Current rotation angle in radians (snow only, drifts over time)
    let rotationSpeed: CGFloat  // Radians per second the particle slowly spins
    let shape: SnowShape        // Visual crystal shape (snow only; ignored for rain)
    let tint: Double            // Slight blue tint 0 = pure white, 1 = max tint (snow only)
    let size: CGFloat           // Radius / half-width in points (snow: 2-8, rain: 0.8-1.8)
    let length: CGFloat         // Streak length (snow: size*2, rain: 8-25 pts)
    let fallSpeed: CGFloat      // Downward speed in pts/s before speed multiplier
    let wobbleAmp: CGFloat      // Horizontal wobble amplitude in pts
    let wobbleFreq: CGFloat     // Wobble oscillation frequency in Hz
    let wobblePhase: CGFloat    // Per-particle phase offset so wobbles stay out of sync
    let windSensitivity: CGFloat // Scales how strongly this particle responds to wind
    let opacity: Double         // Alpha value (snow: 0.45-0.95, rain: 0.55-0.85)
}

// MARK: - Wind model

/// Simulates a smoothly varying horizontal wind that gusts and changes direction.
/// Velocity is expressed in points per second; positive = rightward.
@MainActor
class WindModel {
    private(set) var velocity: CGFloat = 0
    private var targetVelocity: CGFloat = 0
    private var timeUntilChange: CGFloat = 0

    /// Advances the wind simulation by one time step.
    /// - Parameters:
    ///   - dt: Elapsed seconds since the last update (capped upstream to 1/20 s).
    ///   - strength: Wind intensity from `WeatherSettings.windStrength` (0 = calm, 1 = full gale).
    func update(dt: CGFloat, strength: CGFloat) {
        guard strength > 0 else {
            velocity += (0 - velocity) * min(dt * 1.5, 1.0)
            return
        }
        let maxGust = CGFloat(15 + 125 * strength)
        let smooth  = CGFloat(0.5 + 1.5 * strength)
        velocity += (targetVelocity - velocity) * min(dt * smooth, 1.0)
        timeUntilChange -= dt
        if timeUntilChange <= 0 {
            let flip: CGFloat = strength < 0.5 ? 1.0 : (CGFloat.random(in: 0...1) < 0.25 ? -1.0 : 1.0)
            let gustMag = CGFloat.random(in: maxGust * 0.3...maxGust)
            targetVelocity = gustMag * flip
            let baseInterval = CGFloat.random(in: 1.5...6.0)
            timeUntilChange = baseInterval * (1.2 - strength * 0.8)
        }
    }
}

// MARK: - Seeded RNG

/// A fast xorshift64 pseudo-random number generator seeded from `WeatherSettings.randomSeed`.
/// Provides deterministic per-particle randomness so the same seed always produces
/// the same particle population.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    /// Returns the next raw 64-bit pseudo-random value.
    mutating func nextRaw() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }

    /// Returns a uniformly distributed Double in [0, 1].
    mutating func next01() -> Double { Double(nextRaw()) / Double(UInt64.max) }

    /// Returns a uniformly distributed Double within the given closed range.
    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next01() * (range.upperBound - range.lowerBound)
    }
}
