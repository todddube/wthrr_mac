// SkyStateTests.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Testing
import Foundation
@testable import wthrr

// MARK: - Sky state

/// `SkyState` drives where the sun sits in Clear Skies mode. It is pure arithmetic
/// over the clock, which makes it the easiest part of the renderer to pin down.
@Suite("SkyState")
struct SkyStateTests {

    @Test("Day and night are split at the civil sunrise and sunset")
    func dayNightBoundaries() {
        #expect(SkyState.at(hours: 5.99).isNight)
        #expect(!SkyState.at(hours: 6.01).isNight)
        #expect(!SkyState.at(hours: 18.99).isNight)
        #expect(SkyState.at(hours: 19.01).isNight)
        #expect(SkyState.at(hours: 0).isNight)
        #expect(SkyState.at(hours: 23.99).isNight)
    }

    @Test("The sun moves left to right across the day")
    func sunTracksLeftToRight() {
        let morning = SkyState.at(hours: 7)
        let noon    = SkyState.at(hours: 12.5)
        let evening = SkyState.at(hours: 18)

        #expect(morning.x < noon.x)
        #expect(noon.x < evening.x)

        // Stays on screen at both extremes.
        #expect(SkyState.at(hours: 6).x >= 0)
        #expect(SkyState.at(hours: 19).x <= 1)
    }

    @Test("The sun is highest in the middle of the day")
    func sunPeaksAtMidday() {
        let morning = SkyState.at(hours: 7)
        let noon    = SkyState.at(hours: 12.5)
        let evening = SkyState.at(hours: 18)

        // y is measured downward, so a smaller y means higher in the sky.
        #expect(noon.y < morning.y)
        #expect(noon.y < evening.y)
        #expect(noon.altitude > morning.altitude)
        #expect(noon.altitude > evening.altitude)
    }

    @Test("Altitude stays within its unit range all day and night")
    func altitudeIsNormalised() {
        for tenths in 0..<240 {
            let s = SkyState.at(hours: Double(tenths) / 10.0)
            #expect(s.altitude >= 0 && s.altitude <= 1.0001)
            #expect(s.goldenness >= 0 && s.goldenness <= 1.0001)
            #expect(s.x.isFinite && s.y.isFinite)
        }
    }

    @Test("Light is golden near the horizons and neutral at midday")
    func goldenHour() {
        #expect(SkyState.at(hours: 6.2).goldenness > 0.5)
        #expect(SkyState.at(hours: 18.8).goldenness > 0.5)
        #expect(SkyState.at(hours: 12.5).goldenness == 0)
    }

    @Test("Night has no golden-hour warmth")
    func nightIsNotGolden() {
        #expect(SkyState.at(hours: 2).goldenness == 0)
        #expect(SkyState.at(hours: 22).goldenness == 0)
    }

    @Test("The moon also tracks across the night without jumping")
    func moonTracksAcrossNight() {
        // Night wraps midnight, so progress must be continuous across 23:59 → 00:00.
        let beforeMidnight = SkyState.at(hours: 23.98)
        let afterMidnight  = SkyState.at(hours: 0.02)
        #expect(afterMidnight.x > beforeMidnight.x)
        #expect(abs(afterMidnight.x - beforeMidnight.x) < 0.05)
    }
}
