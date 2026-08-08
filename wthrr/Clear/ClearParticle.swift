// ClearParticle.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Sky state

/// Where the sun (or moon) sits right now and what the sky looks like around it.
///
/// Derived entirely from the local clock: the light source tracks an arc from the
/// left edge at sunrise, through its highest point at solar noon, to the right edge
/// at sunset — then the moon repeats the arc through the night. Position is expressed
/// in unit coordinates so the same state works on any display size.
struct SkyState {
    /// Horizontal position of the light source, 0 = left edge, 1 = right edge.
    let x: Double

    /// Vertical position, 0 = top of screen, 1 = bottom. Smallest around solar noon.
    let y: Double

    /// True between sunset and sunrise — the moon is up instead of the sun.
    let isNight: Bool

    /// 0 at the horizon, 1 at the peak of the arc. Drives warmth and ray length.
    let altitude: Double

    /// How golden the light is: 1 near sunrise/sunset, 0 at midday.
    let goldenness: Double

    /// Nominal sunrise and sunset hours. A real solar calculation would need the
    /// user's latitude and the date; for a decorative overlay a fixed civil day is
    /// close enough and keeps the scene independent of location permissions.
    private static let sunriseHour = 6.0
    private static let sunsetHour  = 19.0

    /// Builds the sky state for a given local time expressed in fractional hours (0–24).
    static func at(hours: Double) -> SkyState {
        let sunrise = sunriseHour
        let sunset  = sunsetHour

        let isNight = hours < sunrise || hours >= sunset

        // Progress along the current arc, 0 → 1.
        let t: Double
        if isNight {
            let nightLength = (24 - sunset) + sunrise
            let elapsed = hours >= sunset ? hours - sunset : (24 - sunset) + hours
            t = nightLength > 0 ? elapsed / nightLength : 0.5
        } else {
            t = (hours - sunrise) / max(0.001, sunset - sunrise)
        }

        // Arc: left edge → across → right edge, peaking in the middle.
        let arc = sin(.pi * t)                        // 0 at the horizons, 1 at the peak
        let x = 0.12 + 0.76 * t
        let y = 0.40 - 0.28 * arc                     // higher on screen at the peak

        // Golden hour: strongest when the light source is near either horizon.
        let goldenness = isNight ? 0.0 : max(0.0, 1.0 - arc * 1.6)

        return SkyState(x: x, y: y, isNight: isNight, altitude: arc, goldenness: goldenness)
    }

    /// The sky state for right now.
    static var current: SkyState {
        let cal = Calendar.current
        let now = Date()
        let h = Double(cal.component(.hour, from: now))
        let m = Double(cal.component(.minute, from: now))
        return .at(hours: h + m / 60.0)
    }
}

// MARK: - Clear-sky particle factory

/// Creates the drifting motes that catch the light in Clear Skies mode — pollen,
/// dust, and seed fluff rather than falling precipitation.
enum ClearParticleFactory {

    /// Builds a single mote. Motes are tiny, nearly weightless, and drift slowly:
    /// a small negative `fallSpeed` makes some of them rise on thermals instead of
    /// falling, which is what sells "warm still afternoon" rather than "it's raining
    /// very slowly".
    static func makeMote(startY: CGFloat, screenWidth: CGFloat, rng: inout SeededRNG) -> Particle {
        // Roughly a third of motes rise; the rest sink gently.
        let rises = rng.next01() < 0.35
        let speed = rises
            ? CGFloat(rng.next(in: -14.0 ... -4.0))
            : CGFloat(rng.next(in: 5.0...22.0))

        let size = CGFloat(rng.next(in: 0.9...2.6))

        return Particle(
            x: CGFloat(rng.next01()) * screenWidth,
            y: startY,
            rotation: CGFloat(rng.next(in: 0...(.pi * 2))),
            rotationSpeed: CGFloat(rng.next(in: -0.6...0.6)),
            shape: .dot,
            tint: rng.next(in: 0...1),
            size: size,
            length: size * 2,
            fallSpeed: speed,
            // Wide, lazy wobble — motes wander far more than snow does.
            wobbleAmp: CGFloat(rng.next(in: 18...55)),
            wobbleFreq: CGFloat(rng.next(in: 0.15...0.55)),
            wobblePhase: CGFloat(rng.next(in: 0...(.pi * 2))),
            windSensitivity: CGFloat(rng.next(in: 0.7...1.6)),
            opacity: rng.next(in: 0.18...0.55)
        )
    }
}
