// Cloud.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation

// MARK: - Cloud

/// A single cloud that drifts horizontally across the top of the screen.
struct Cloud {
    var x: CGFloat              // Current horizontal position (center)
    let y: CGFloat              // Vertical position (near top of screen)
    let width: CGFloat          // Cloud width in points
    let height: CGFloat         // Cloud height in points
    let speed: CGFloat          // Horizontal drift speed in pts/s
    let opacity: Double         // Base transparency (0-1)
    let blobCount: Int          // Number of ellipse blobs composing this cloud
    let blobSeed: UInt64        // Seed for deterministic blob placement
    let colorVariant: Int       // 0-2, selects color palette per weather type
}

// MARK: - Cloud factory

/// Namespace for cloud-creation logic shared by `WeatherAnimationModel`.
enum CloudFactory {
    /// Maximum number of clouds on screen at once.
    static let maxClouds = 5

    /// Maximum number of fair-weather cumulus on screen at once. Higher than
    /// `maxClouds` because these are the centrepiece of the Clear Skies scene rather
    /// than a backdrop for falling particles.
    static let maxFairWeatherClouds = 8

    /// Creates a large, bright cumulus for the Clear Skies scene.
    ///
    /// Differs from `makeCloud` in three ways that matter visually: the clouds are
    /// two to three times wider, they are spread down through the upper half of the
    /// screen instead of being pinned to a thin strip under the menu bar, and they are
    /// far more opaque — fair-weather cumulus are the subject here, not atmosphere.
    static func makeFairWeatherCloud(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        sizeMultiplier: Double,
        startOffScreen: Bool,
        rng: inout SeededRNG
    ) -> Cloud {
        let baseWidth = CGFloat(rng.next(in: 260...620))
        let width = min(baseWidth * CGFloat(sizeMultiplier), 780)
        // Cumulus are tall relative to their width compared with the flat overcast
        // used by the precipitation scenes.
        let height = width * CGFloat(rng.next(in: 0.36...0.58))

        // Spread through the upper half, keeping clear of the very top edge.
        let y = CGFloat(rng.next(in: 0.06...0.46)) * screenHeight

        let x: CGFloat
        if startOffScreen {
            x = -(width / 2 + CGFloat(rng.next(in: 0...260)))
        } else {
            x = CGFloat(rng.next(in: Double(-width / 2)...Double(screenWidth + width / 2)))
        }

        return Cloud(
            x: x,
            y: y,
            width: width,
            height: height,
            // Slow, lazy drift — a still summer afternoon, not a front moving through.
            speed: CGFloat(rng.next(in: 4...16)),
            opacity: rng.next(in: 0.42...0.72),
            blobCount: Int(rng.next(in: 7...12)),
            blobSeed: rng.nextRaw(),
            colorVariant: Int(rng.next(in: 0...2.99))
        )
    }

    /// Creates a cloud appropriate for the current screen dimensions and size setting.
    /// - Parameters:
    ///   - screenWidth: Width of the overlay screen.
    ///   - sizeMultiplier: User cloud size setting (0.5 - 1.5).
    ///   - startOffScreen: If true, cloud starts just off the left edge; otherwise random x.
    ///   - rng: Deterministic RNG for reproducible placement.
    static func makeCloud(
        screenWidth: CGFloat,
        sizeMultiplier: Double,
        startOffScreen: Bool,
        rng: inout SeededRNG
    ) -> Cloud {
        // Base width 120-260 scaled by user size setting, capped so clouds aren't too big
        let baseWidth = CGFloat(rng.next(in: 120...260))
        let width = min(baseWidth * CGFloat(sizeMultiplier), 350)
        let height = width * CGFloat(rng.next(in: 0.3...0.5))

        // Position near the top of the screen, just below the menu bar (~25px)
        let y = CGFloat(rng.next(in: 28...90))

        let x: CGFloat
        if startOffScreen {
            let offset = CGFloat(rng.next(in: 0...200))
            x = -(width / 2 + offset)
        } else {
            let lo = Double(-width / 2)
            let hi = Double(screenWidth + width / 2)
            x = CGFloat(rng.next(in: lo...hi))
        }

        let speed = CGFloat(rng.next(in: 12...40))
        let opacity = rng.next(in: 0.15...0.35)
        let blobCount = Int(rng.next(in: 5...9))
        let blobSeed = rng.nextRaw()
        let colorVariant = Int(rng.next(in: 0...2.99))

        return Cloud(
            x: x,
            y: y,
            width: width,
            height: height,
            speed: speed,
            opacity: opacity,
            blobCount: blobCount,
            blobSeed: blobSeed,
            colorVariant: colorVariant
        )
    }
}
