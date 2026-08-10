// SnowCrystalTests.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Testing
import SwiftUI
@testable import wthrr

// MARK: - Crystal geometry

@Suite("SnowCrystalGeometry")
struct SnowCrystalGeometryTests {

    @Test("Each shape produces the expected number of stroke batches")
    func strokeBatching() {
        // The whole point of batching is that a dendrite is 3 stroked paths rather
        // than the 78 it used to be. If this count creeps up, the batching regressed.
        #expect(SnowCrystalGeometry.crystal(for: .dot, radius: 8).strokes.isEmpty)
        #expect(SnowCrystalGeometry.crystal(for: .star, radius: 8).strokes.count == 2)
        #expect(SnowCrystalGeometry.crystal(for: .dendrite, radius: 8).strokes.count == 3)
    }

    @Test("Geometry stays within the radius it was asked for")
    func geometryFitsRadius() {
        // Symbols are rasterised into a fixed frame, so geometry escaping the radius
        // would be silently clipped.
        for shape in [SnowShape.dot, .star, .dendrite] {
            let crystal = SnowCrystalGeometry.crystal(for: shape, radius: 10)
            var union = crystal.centre.boundingRect
            for stroke in crystal.strokes {
                union = union.union(stroke.path.boundingRect)
            }
            // Allow a small budget for round line caps extending past the arm tips.
            let capSlack: CGFloat = 3
            #expect(union.minX >= -10 - capSlack)
            #expect(union.maxX <= 10 + capSlack)
            #expect(union.minY >= -10 - capSlack)
            #expect(union.maxY <= 10 + capSlack)
        }
    }

    @Test("Geometry is centred on the origin so rotation spins about the middle")
    func geometryIsCentred() {
        for shape in [SnowShape.star, .dendrite] {
            let crystal = SnowCrystalGeometry.crystal(for: shape, radius: 10)
            var union = crystal.strokes[0].path.boundingRect
            for stroke in crystal.strokes.dropFirst() {
                union = union.union(stroke.path.boundingRect)
            }
            #expect(abs(union.midX) < 0.001)
            #expect(abs(union.midY) < 0.001)
        }
    }

    @Test("Line widths decrease from arms to branches to tips")
    func lineWidthHierarchy() {
        let d = SnowCrystalGeometry.crystal(for: .dendrite, radius: 8)
        #expect(d.strokes[0].lineWidth > d.strokes[1].lineWidth)
        #expect(d.strokes[1].lineWidth > d.strokes[2].lineWidth)
    }

    @Test("Geometry scales with radius")
    func scalesWithRadius() {
        let small = SnowCrystalGeometry.crystal(for: .star, radius: 4)
        let large = SnowCrystalGeometry.crystal(for: .star, radius: 16)
        #expect(large.strokes[0].path.boundingRect.width
                > small.strokes[0].path.boundingRect.width)
    }

    @Test("Every shape produces non-empty geometry")
    func noEmptyShapes() {
        for shape in [SnowShape.dot, .star, .dendrite] {
            let crystal = SnowCrystalGeometry.crystal(for: shape, radius: 6)
            #expect(!crystal.centre.isEmpty)
            for stroke in crystal.strokes {
                #expect(!stroke.path.isEmpty)
            }
        }
    }
}

// MARK: - Tint bucketing

@Suite("SnowTint")
struct SnowTintTests {

    @Test("Every tint the factory produces maps to a valid bucket")
    func tintBucketsCoverFactoryRange() {
        var rng = SeededRNG(seed: 77)
        for _ in 0..<1000 {
            let flake = SnowParticleFactory.makeFlake(startY: 0, screenWidth: 1000, rng: &rng)
            let bucket = SnowTint.bucket(for: flake.tint)
            #expect(bucket >= 0 && bucket < SnowTint.bucketCount)
        }
    }

    @Test("Bucketing uses the full range rather than collapsing to one bucket")
    func bucketsAreDistributed() {
        // `Particle.tint` spans 0–0.35, not 0–1. Bucketing against the wrong domain
        // quietly funnels every flake into the first couple of buckets and wastes most
        // of the resolved shading table — which is exactly what used to happen.
        var rng = SeededRNG(seed: 1234)
        var seen = Set<Int>()
        for _ in 0..<4000 {
            let flake = SnowParticleFactory.makeFlake(startY: 0, screenWidth: 1000, rng: &rng)
            seen.insert(SnowTint.bucket(for: flake.tint))
        }
        #expect(seen.count == SnowTint.bucketCount)
    }

    @Test("Bucket endpoints map to the extremes")
    func bucketEndpoints() {
        #expect(SnowTint.bucket(for: 0) == 0)
        #expect(SnowTint.bucket(for: SnowTint.maxTint) == SnowTint.bucketCount - 1)
    }

    @Test("Out-of-range tints clamp rather than crash")
    func tintClamping() {
        #expect(SnowTint.bucket(for: -5) == 0)
        #expect(SnowTint.bucket(for: 999) == SnowTint.bucketCount - 1)
    }

    @Test("Bucket representative tints round-trip to their own bucket")
    func representativeTintsRoundTrip() {
        for bucket in 0..<SnowTint.bucketCount {
            #expect(SnowTint.bucket(for: SnowTint.tint(forBucket: bucket)) == bucket)
        }
    }

    @Test("The factory never exceeds the tint domain the buckets assume")
    func factoryStaysWithinTintDomain() {
        var rng = SeededRNG(seed: 31)
        for _ in 0..<1000 {
            let flake = SnowParticleFactory.makeFlake(startY: 0, screenWidth: 800, rng: &rng)
            #expect(flake.tint >= 0 && flake.tint <= SnowTint.maxTint)
        }
    }
}
