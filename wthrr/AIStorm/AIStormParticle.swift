// AIStormParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation

// MARK: - Glitch shape

/// Visual shape category for AI storm glitch particles.
/// Each shape evokes digital corruption and data fragments.
enum GlitchShape {
    case pixel      // Small filled square — a stray pixel
    case bracket    // Angle bracket fragment — broken code
    case slash      // Diagonal slash — data stream artifact
    case dot        // Tiny glowing dot — stray bit
}

// MARK: - Scan line

/// A horizontal distortion band that sweeps vertically across the screen.
/// Creates a brief visual glitch as it passes, like a CRT scan artifact.
struct ScanLine {
    var y: CGFloat              // Current vertical position
    let speed: CGFloat          // Downward speed in pts/s (80 - 250)
    let width: CGFloat          // Band height in pts (2 - 6)
    let opacity: Double         // 0.15 - 0.40
    let colorIndex: Int         // Indexes into the neon palette (0 = cyan, 1 = purple, 2 = green)
}

// MARK: - Data bolt

/// A circuit-trace lightning bolt made entirely of right-angle (horizontal + vertical)
/// segments. Glows in neon cyan or purple for an electronic feel.
struct DataBolt {
    let segments: [CGPoint]     // Ordered points forming the right-angle path
    var age: CGFloat = 0        // Seconds since the bolt fired
    let lifetime: CGFloat       // Total visible duration (0.25 - 0.40 s)
    var flashOpacity: Double    // Screen tint flash intensity
    let colorIndex: Int         // 0 = cyan, 1 = purple, 2 = green
}

// MARK: - Corruption patch

/// A brief rectangular region of visual noise/static that appears and dissolves.
struct CorruptionPatch {
    var x: CGFloat
    var y: CGFloat
    let width: CGFloat          // 20 - 80 pts
    let height: CGFloat         // 4 - 16 pts
    var age: CGFloat = 0
    let lifetime: CGFloat       // 0.15 - 0.5 s
    let colorIndex: Int
}

// MARK: - Alien ship

/// A small alien craft that flies across the screen in smooth curved paths.
/// Ships steer toward a wandering target point, creating organic flight arcs.
/// Each ship has a triangular hull with a neon engine glow and a fading trail.
struct AlienShip {
    var x: CGFloat              // Current horizontal position
    var y: CGFloat              // Current vertical position
    var vx: CGFloat             // Horizontal velocity in pts/s
    var vy: CGFloat             // Vertical velocity in pts/s
    var targetX: CGFloat        // Steering target X
    var targetY: CGFloat        // Steering target Y
    var timeUntilRetarget: CGFloat  // Seconds until a new target is picked
    let size: CGFloat           // Hull half-width (8 - 16 pts)
    let colorIndex: Int         // Neon palette index
    let speed: CGFloat          // Max speed in pts/s (60 - 180)
    var trail: [(CGFloat, CGFloat)]  // Recent positions for the engine trail (newest first)
}

// MARK: - Screen fracture

/// A glass-crack pattern that appears at a random impact point and radiates outward.
/// Each fracture has several jagged arms spreading from the centre, fading over time.
struct ScreenFracture {
    let origin: CGPoint         // Impact point
    let arms: [[CGPoint]]       // Each arm is a series of points radiating from origin
    var age: CGFloat = 0        // Seconds since the fracture appeared
    let lifetime: CGFloat       // Total duration (2.0 - 4.0 s)
    let colorIndex: Int         // Neon palette index
    var flashOpacity: Double    // Brief flash at the impact point on spawn
}

// MARK: - AI storm particle factory

/// Creates AI storm particles — erratic glitch fragments in neon colours.
enum AIStormParticleFactory {

    /// Creates a single glitch particle with randomised properties.
    /// Some particles fall upward, some drift sideways, and all have
    /// neon colours from the AI storm palette.
    /// - Parameters:
    ///   - startY: Initial vertical position in points.
    ///   - screenWidth: Width of the target display in points.
    ///   - rng: Seeded random number generator for deterministic output.
    /// - Returns: A fully configured `Particle` representing a glitch fragment.
    static func makeGlitch(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        let size = CGFloat(rng.next(in: 1.5...5.0))
        let sizeFactor = (size - 1.5) / 3.5

        // Shape distribution based on size
        let shapeRoll = rng.next01()
        let shape: SnowShape
        if size < 2.5 {
            shape = .dot       // Tiny dots
        } else if size < 3.8 {
            shape = shapeRoll < 0.6 ? .star : .dot   // Star = bracket rendering
        } else {
            shape = shapeRoll < 0.5 ? .dendrite : .star  // Dendrite = slash rendering
        }

        // Some particles fall upward (negative speed) for an eerie feel
        let directionRoll = rng.next01()
        let baseSpeed: CGFloat
        if directionRoll < 0.15 {
            baseSpeed = CGFloat(rng.next(in: -80...(-20)))    // Fall upward
        } else if directionRoll < 0.25 {
            baseSpeed = CGFloat(rng.next(in: -10...10))       // Float sideways
        } else {
            baseSpeed = CGFloat(rng.next(in: 30...180))       // Fall down (most)
        }

        // Tint encodes which neon colour to use (0-1 maps to palette)
        let tint = rng.next(in: 0.0...1.0)

        return Particle(
            x: CGFloat(rng.next(in: -20...max(Double(screenWidth) + 20, 1))),
            y: startY,
            rotation: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            rotationSpeed: CGFloat(rng.next(in: -2.0...2.0)),  // Fast spin
            shape: shape,
            tint: tint,
            size: size,
            length: size * 1.5,
            fallSpeed: baseSpeed * (0.6 + sizeFactor * 0.6),
            wobbleAmp: CGFloat(rng.next(in: 0.5...4.0)),       // Erratic wobble
            wobbleFreq: CGFloat(rng.next(in: 0.8...4.0)),      // High frequency
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.2...1.2)),
            opacity: rng.next(in: 0.4...0.95)
        )
    }
}
