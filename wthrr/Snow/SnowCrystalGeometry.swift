// SnowCrystalGeometry.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Snow crystal geometry

/// Builds the vector geometry for each snow crystal shape, in a unit space where the
/// crystal's arm length is `radius`.
///
/// This is the single source of truth for what a snowflake looks like. It is consumed
/// twice: once to rasterise the reusable `Canvas` symbols, and once by the direct
/// vector fallback used when symbols are unavailable.
enum SnowCrystalGeometry {

    /// A stroked sub-path together with the width it should be stroked at.
    struct Stroke {
        let path: Path
        let lineWidth: CGFloat
    }

    /// The strokes and centre dot making up one crystal.
    struct Crystal {
        let strokes: [Stroke]
        let centre: Path
    }

    /// Builds the geometry for `shape` at the given arm radius, centred on the origin.
    ///
    /// Segments are batched by line width into as few paths as possible: stroking a
    /// self-overlapping path renders it as a single shape, so the joints look identical
    /// to stroking each segment separately while costing a fraction as much.
    static func crystal(for shape: SnowShape, radius: CGFloat) -> Crystal {
        switch shape {
        case .dot:      return dot(radius: radius)
        case .star:     return star(radius: radius)
        case .dendrite: return dendrite(radius: radius)
        }
    }

    // MARK: Dot

    /// A soft round pellet — slightly oval to hint at 3D.
    private static func dot(radius r: CGFloat) -> Crystal {
        Crystal(
            strokes: [],
            centre: Path(ellipseIn: CGRect(x: -r, y: -r * 0.9, width: r * 2, height: r * 1.8))
        )
    }

    // MARK: Star

    /// A 6-arm plate crystal: 3 axes at 60° with crossbars and a centre dot.
    private static func star(radius arm: CGFloat) -> Crystal {
        let lineWidth = max(1.0, arm * 0.28)

        var axes = Path()
        var bars = Path()

        for i in 0..<3 {
            let angle = CGFloat(i) * .pi / 3
            let ca = cos(angle), sa = sin(angle)
            axes.move(to: CGPoint(x: -ca * arm, y: -sa * arm))
            axes.addLine(to: CGPoint(x: ca * arm, y: sa * arm))

            // Crossbar at ~60% along each arm
            let barAngle = angle + .pi / 2
            let cb = cos(barAngle), sb = sin(barAngle)
            let barLen = arm * 0.32
            for sign: CGFloat in [-1, 1] {
                let cx = sign * ca * arm * 0.6
                let cy = sign * sa * arm * 0.6
                bars.move(to: CGPoint(x: cx - cb * barLen, y: cy - sb * barLen))
                bars.addLine(to: CGPoint(x: cx + cb * barLen, y: cy + sb * barLen))
            }
        }

        let cR = lineWidth * 1.1
        return Crystal(
            strokes: [
                Stroke(path: axes, lineWidth: lineWidth),
                Stroke(path: bars, lineWidth: lineWidth * 0.7),
            ],
            centre: Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2))
        )
    }

    // MARK: Dendrite

    /// A 3-axis branching crystal: main arms, secondary branches, and tertiary tips.
    private static func dendrite(radius arm: CGFloat) -> Crystal {
        let lineW   = max(1.0, arm * 0.22)
        let branchW = lineW * 0.65
        let tipW    = lineW * 0.45

        var mains    = Path()
        var branches = Path()
        var tips     = Path()

        for i in 0..<3 {
            let angle = CGFloat(i) * .pi / 3
            let ca = cos(angle), sa = sin(angle)
            let branchAngle = angle + .pi / 2
            let cb = cos(branchAngle), sb = sin(branchAngle)

            for sign: CGFloat in [-1, 1] {
                mains.move(to: .zero)
                mains.addLine(to: CGPoint(x: sign * ca * arm, y: sign * sa * arm))

                // Two pairs of secondary branches at 35% and 65% of the arm
                for frac: CGFloat in [0.35, 0.65] {
                    let bx = sign * ca * arm * frac
                    let by = sign * sa * arm * frac
                    let branchLen = arm * (0.40 - frac * 0.18)
                    let tipLen = branchLen * 0.38

                    for bSign: CGFloat in [-1, 1] {
                        let ex = bx + bSign * cb * branchLen
                        let ey = by + bSign * sb * branchLen
                        branches.move(to: CGPoint(x: bx, y: by))
                        branches.addLine(to: CGPoint(x: ex, y: ey))

                        for tSign: CGFloat in [-1, 1] {
                            let tipAngle = branchAngle + tSign * .pi / 4
                            tips.move(to: CGPoint(x: ex, y: ey))
                            tips.addLine(to: CGPoint(
                                x: ex + cos(tipAngle) * tipLen,
                                y: ey + sin(tipAngle) * tipLen
                            ))
                        }
                    }
                }
            }
        }

        let cR = lineW * 1.2
        return Crystal(
            strokes: [
                Stroke(path: mains, lineWidth: lineW),
                Stroke(path: branches, lineWidth: branchW),
                Stroke(path: tips, lineWidth: tipW),
            ],
            centre: Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2))
        )
    }
}

// MARK: - Snow tint buckets

/// Quantises `Particle.tint` so flake colours can be resolved once per frame rather
/// than once per flake.
///
/// `tint` only nudges one colour channel by a few percent, so a handful of buckets is
/// visually indistinguishable from a continuous value.
enum SnowTint {
    /// Number of distinct tints resolved per frame.
    static let bucketCount = 8

    /// The widest tint value `SnowParticleFactory` produces. Note this is 0.35, not 1 —
    /// bucketing against the wrong domain would funnel every flake into the first
    /// couple of buckets and waste most of the table.
    static let maxTint: Double = 0.35

    /// Maps a particle's tint to its bucket index.
    static func bucket(for tint: Double) -> Int {
        let t = max(0, min(1, tint / maxTint))
        return min(bucketCount - 1, Int(t * Double(bucketCount - 1) + 0.5))
    }

    /// The tint value at the centre of a bucket, used when resolving that bucket's colour.
    static func tint(forBucket bucket: Int) -> Double {
        Double(bucket) / Double(bucketCount - 1) * maxTint
    }
}
