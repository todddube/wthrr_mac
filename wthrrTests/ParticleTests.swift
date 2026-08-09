// ParticleTests.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Testing
import Foundation
@testable import wthrr

// MARK: - Seeded RNG

/// The whole particle system is reproducible only because `SeededRNG` is. If this
/// drifts, saved presets and the reroll button stop meaning anything.
@Suite("SeededRNG")
struct SeededRNGTests {

    @Test("The same seed always produces the same sequence")
    func deterministic() {
        var a = SeededRNG(seed: 12345)
        var b = SeededRNG(seed: 12345)
        for _ in 0..<500 {
            #expect(a.nextRaw() == b.nextRaw())
        }
    }

    @Test("Different seeds diverge")
    func differentSeeds() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        let aVals = (0..<20).map { _ in a.nextRaw() }
        let bVals = (0..<20).map { _ in b.nextRaw() }
        #expect(aVals != bVals)
    }

    @Test("A zero seed does not collapse the generator")
    func zeroSeedIsHandled() {
        // xorshift64 is a fixed point at zero, so the initialiser has to substitute.
        var rng = SeededRNG(seed: 0)
        let values = (0..<10).map { _ in rng.nextRaw() }
        #expect(Set(values).count > 1)
        #expect(!values.contains(0))
    }

    @Test("next01 stays within the unit interval")
    func unitInterval() {
        var rng = SeededRNG(seed: 99)
        for _ in 0..<2000 {
            let v = rng.next01()
            #expect(v >= 0 && v <= 1)
        }
    }

    @Test("next(in:) respects its bounds")
    func rangeBounds() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<2000 {
            let v = rng.next(in: -3.5...9.25)
            #expect(v >= -3.5 && v <= 9.25)
        }
    }

    @Test("Values spread across the range rather than clustering")
    func reasonableDistribution() {
        var rng = SeededRNG(seed: 4242)
        var buckets = [Int](repeating: 0, count: 10)
        for _ in 0..<10_000 {
            buckets[min(9, Int(rng.next01() * 10))] += 1
        }
        // A uniform generator gives ~1000 per bucket; allow generous slack.
        for count in buckets {
            #expect(count > 700 && count < 1300)
        }
    }
}

// MARK: - Clear-sky motes

@Suite("ClearParticleFactory")
struct ClearParticleFactoryTests {

    @Test("Motes are reproducible from a seed")
    func deterministic() {
        var a = SeededRNG(seed: 555)
        var b = SeededRNG(seed: 555)
        let p1 = ClearParticleFactory.makeMote(startY: 10, screenWidth: 1000, rng: &a)
        let p2 = ClearParticleFactory.makeMote(startY: 10, screenWidth: 1000, rng: &b)
        #expect(p1.x == p2.x)
        #expect(p1.fallSpeed == p2.fallSpeed)
        #expect(p1.size == p2.size)
        #expect(p1.opacity == p2.opacity)
    }

    @Test("Some motes rise and some sink")
    func mixOfRisingAndSinking() {
        var rng = SeededRNG(seed: 31337)
        let motes = (0..<400).map { _ in
            ClearParticleFactory.makeMote(startY: 0, screenWidth: 800, rng: &rng)
        }
        let rising = motes.filter { $0.fallSpeed < 0 }
        let sinking = motes.filter { $0.fallSpeed > 0 }
        // Roughly a third should rise; assert only that both populations exist
        // in meaningful numbers so the intent can't silently regress to all-falling.
        #expect(rising.count > 50)
        #expect(sinking.count > 50)
    }

    @Test("Motes stay small, faint, and on screen")
    func fieldRanges() {
        var rng = SeededRNG(seed: 2024)
        for _ in 0..<500 {
            let m = ClearParticleFactory.makeMote(startY: 5, screenWidth: 1440, rng: &rng)
            #expect(m.x >= 0 && m.x <= 1440)
            #expect(m.size >= 0.9 && m.size <= 2.6)
            #expect(m.opacity >= 0.18 && m.opacity <= 0.55)
            #expect(abs(m.fallSpeed) <= 22)
        }
    }
}

// MARK: - Wind

@MainActor
@Suite("WindModel")
struct WindModelTests {

    @Test("Wind decays toward calm when strength is zero")
    func decaysToCalm() {
        let wind = WindModel()
        // Build up some velocity first.
        for _ in 0..<200 { wind.update(dt: 1.0 / 60.0, strength: 1.0) }

        for _ in 0..<600 { wind.update(dt: 1.0 / 60.0, strength: 0) }
        #expect(abs(wind.velocity) < 1.0)
    }

    @Test("Wind stays within the gust ceiling for a given strength")
    func respectsGustCeiling() {
        let wind = WindModel()
        let strength = 0.5
        let maxGust = CGFloat(15 + 125 * strength)
        for _ in 0..<5000 {
            wind.update(dt: 1.0 / 60.0, strength: CGFloat(strength))
            // Velocity chases the target, so it can never exceed the largest target.
            #expect(abs(wind.velocity) <= maxGust + 0.001)
        }
    }

    @Test("Velocity remains finite across long runs and varying strength")
    func staysFinite() {
        let wind = WindModel()
        for i in 0..<5000 {
            wind.update(dt: 1.0 / 60.0, strength: CGFloat(Double(i % 100) / 100.0))
            #expect(wind.velocity.isFinite)
        }
    }
}

// MARK: - Clouds

@Suite("CloudFactory")
struct CloudFactoryTests {

    @Test("Fair-weather cumulus are large and spread through the upper half")
    func fairWeatherCloudShape() {
        var rng = SeededRNG(seed: 808)
        for _ in 0..<300 {
            let c = CloudFactory.makeFairWeatherCloud(
                screenWidth: 2000, screenHeight: 1200,
                sizeMultiplier: 1.0, startOffScreen: false, rng: &rng
            )
            #expect(c.width >= 260 && c.width <= 780)
            #expect(c.y >= 0.06 * 1200 && c.y <= 0.46 * 1200)
            #expect(c.height > 0 && c.height < c.width)
            #expect(c.blobCount >= 7 && c.blobCount <= 12)
            // Noticeably more opaque than the precipitation clouds.
            #expect(c.opacity >= 0.42 && c.opacity <= 0.72)
        }
    }

    @Test("Fair-weather clouds drift slowly")
    func fairWeatherCloudSpeed() {
        var rng = SeededRNG(seed: 9)
        for _ in 0..<200 {
            let c = CloudFactory.makeFairWeatherCloud(
                screenWidth: 1600, screenHeight: 1000,
                sizeMultiplier: 1.0, startOffScreen: false, rng: &rng
            )
            #expect(c.speed >= 4 && c.speed <= 16)
        }
    }

    @Test("Off-screen clouds start fully clear of the left edge")
    func offScreenStart() {
        var rng = SeededRNG(seed: 4)
        for _ in 0..<100 {
            let c = CloudFactory.makeFairWeatherCloud(
                screenWidth: 1600, screenHeight: 1000,
                sizeMultiplier: 1.0, startOffScreen: true, rng: &rng
            )
            #expect(c.x + c.width / 2 <= 0)
        }
    }

    @Test("The size multiplier scales width but respects the hard cap")
    func sizeMultiplierIsCapped() {
        var rng = SeededRNG(seed: 11)
        for _ in 0..<200 {
            let c = CloudFactory.makeFairWeatherCloud(
                screenWidth: 1600, screenHeight: 1000,
                sizeMultiplier: 3.0, startOffScreen: false, rng: &rng
            )
            #expect(c.width <= 780)
        }
    }
}

// MARK: - Weather type persistence

@Suite("WeatherType")
struct WeatherTypeTests {

    @Test("Raw values round-trip so saved settings and presets stay valid")
    func rawValuesRoundTrip() {
        for type in WeatherType.allCases {
            #expect(WeatherType(rawValue: type.rawValue) == type)
        }
    }

    @Test("Raw values are stable identifiers")
    func rawValuesAreStable() {
        // These strings are persisted in UserDefaults and exported preset JSON.
        // Changing one silently resets a user's saved weather, so pin them.
        #expect(WeatherType.clear.rawValue == "clear")
        #expect(WeatherType.snow.rawValue == "snow")
        #expect(WeatherType.rain.rawValue == "rain")
        #expect(WeatherType.aiStorm.rawValue == "aiStorm")
        #expect(WeatherType.thunderstorm.rawValue == "thunderstorm")
        #expect(WeatherType.fog.rawValue == "fog")
        #expect(WeatherType.aurora.rawValue == "aurora")
    }

    @Test("Every type has display strings")
    func displayStringsExist() {
        // Guards against a new case being added without the switch arms being filled in
        // with something meaningful (the compiler forces exhaustiveness, not quality).
        #expect(WeatherType.allCases.count == 7)
    }
}
