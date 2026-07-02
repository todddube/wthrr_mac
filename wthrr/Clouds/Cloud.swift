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
