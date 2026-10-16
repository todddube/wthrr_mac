// RetroRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Retro renderer

/// Draws every weather type as 8-bit pixel art.
///
/// Retro mode is purely a presentation layer: it reads the same particles, clouds,
/// bolts and timers that `WeatherAnimationModel` already simulates and paints them
/// onto a coarse grid with a fixed palette. Physics, settings and live weather all
/// behave identically in both styles, so the toggle can be flipped at any moment
/// without rebuilding the scene.
@MainActor
enum RetroRenderer {

    /// Renders one frame of the active weather type in retro style.
    ///
    /// - Parameters:
    ///   - context:  Canvas graphics context to draw into.
    ///   - size:     Full canvas size in points.
    ///   - isDark:   Whether the system is in dark mode.
    ///   - model:    The animation model holding this canvas's simulation state.
    ///   - settings: Current user settings.
    ///   - now:      Timeline date, used for sprite animation frames.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        isDark: Bool,
        model: WeatherAnimationModel,
        settings: WeatherSettings,
        now: Date
    ) {
        let px = CGFloat(settings.retroPixelSize)
        let opacity = settings.particleOpacity * settings.timeDimFactor
        let time = now.timeIntervalSinceReferenceDate
        let type = settings.weatherType

        // Sky elements sit behind the clouds, exactly as in the smooth renderers.
        switch type {
        case .clear:
            RetroSkyRenderer.drawClearSky(
                context: context, size: size, px: px, isDark: isDark,
                sky: model.sky, time: model.clearTime, opacity: opacity,
                raysEnabled: settings.accumulationEnabled
            )
        case .aurora:
            RetroSkyRenderer.drawAurora(
                context: context, size: size, px: px, isDark: isDark,
                time: model.auroraTime, opacity: opacity
            )
        default:
            break
        }

        if settings.cloudsEnabled || type == .thunderstorm || type == .clear {
            drawClouds(context: context, px: px, isDark: isDark, clouds: model.clouds,
                       weatherType: type, cloudOpacity: settings.cloudOpacity)
        }

        switch type {
        case .snow:
            RetroPrecipitationRenderer.drawSnow(
                context: context, size: size, px: px, isDark: isDark,
                particles: model.particles,
                accumulationMap: model.accumulationMap,
                baselineMap: model.baselineMap,
                accumulationEnabled: settings.accumulationEnabled,
                columnWidth: model.columnWidth,
                opacity: opacity, tintHue: settings.snowTintHue
            )
        case .rain, .thunderstorm:
            RetroPrecipitationRenderer.drawRain(
                context: context, size: size, px: px, isDark: isDark,
                particles: model.particles,
                splashes: model.splashes, puddles: model.puddles,
                windVelocity: model.currentWindVelocity,
                bolt: model.activeBolt,
                opacity: opacity, tintHue: settings.rainTintHue
            )
        case .fog:
            RetroSkyRenderer.drawFog(
                context: context, size: size, px: px, isDark: isDark,
                particles: model.particles, fogBands: model.fogBands,
                opacity: opacity, tintHue: settings.fogTintHue
            )
        case .aiStorm:
            RetroAIStormRenderer.draw(
                context: context, size: size, px: px,
                particles: model.particles,
                scanLines: model.scanLines,
                dataBolts: model.dataBolts,
                corruptionPatches: model.corruptionPatches,
                alienShips: model.alienShips,
                screenFractures: model.screenFractures,
                opacity: opacity, time: time
            )
        case .clear:
            RetroSkyRenderer.drawMotes(
                context: context, px: px, particles: model.particles,
                opacity: opacity, time: time
            )
            drawBirds(context: context, size: size, px: px, time: model.clearTime,
                      settings: settings,
                      color: model.sky.isNight ? RetroPalette.lightGray : RetroPalette.darkGray,
                      opacity: opacity * (isDark ? 0.75 : 0.85))
        case .aurora:
            drawBirds(context: context, size: size, px: px, time: model.auroraTime,
                      settings: settings, color: RetroPalette.white,
                      opacity: opacity * (isDark ? 0.65 : 0.4))
        }
    }

    // MARK: Birds

    /// Two-frame pixel birds flying the same paths as the smooth flock.
    private static func drawBirds(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        time: CGFloat,
        settings: WeatherSettings,
        color: Color,
        opacity: Double
    ) {
        let poses = BirdRenderer.poses(
            size: size, time: time, count: settings.auroraBirdCount,
            sizeScale: settings.auroraBirdSize, wildness: settings.auroraBirdWildness
        )
        guard !poses.isEmpty else { return }

        var painter = PixelPainter(px: px)
        let ink = painter.ink(color, opacity: min(1, opacity))
        let spriteWidth = CGFloat(RetroSprites.birdUp.width) * px
        for bird in poses {
            let scale = max(1, Int((bird.halfSpan * 2 / spriteWidth).rounded()))
            let sprite = bird.lift > 0 ? RetroSprites.birdUp : RetroSprites.birdDown
            painter.sprite(sprite, x: bird.x, y: bird.y, inks: [ink], scale: scale)
        }
        painter.flush(into: context)
    }

    // MARK: Clouds

    /// A horizontal run of cloud cells, relative to the cloud's centre cell.
    private struct CloudRun {
        let dx: Int
        let dy: Int
        let width: Int
        /// 0 = body, 1 = sunlit top edge, 2 = shadowed underside.
        let shade: Int
    }

    /// Rasterised runs per cloud. Shapes never change after spawn — only x moves —
    /// so a hit is exact as long as the key covers everything the shape depends on:
    /// the blob seed *and* the cloud's dimensions, which the Cloud Size slider
    /// changes while the seeds stay the same.
    private static var cloudCache: [CloudKey: [CloudRun]] = [:]

    private struct CloudKey: Hashable {
        let seed: UInt64
        let width: Int
        let height: Int
        let blobCount: Int
        let px: Int

        init(_ cloud: Cloud, px: CGFloat) {
            seed = cloud.blobSeed
            width = Int(cloud.width.rounded())
            height = Int(cloud.height.rounded())
            blobCount = cloud.blobCount
            self.px = Int(px)
        }
    }

    /// Draws blocky three-tone clouds, cached per cloud.
    private static func drawClouds(
        context: GraphicsContext,
        px: CGFloat,
        isDark: Bool,
        clouds: [Cloud],
        weatherType: WeatherType,
        cloudOpacity: Double
    ) {
        guard !clouds.isEmpty else { return }

        // (top, body, shadow) per scene. Light mode shifts one notch darker so
        // clouds keep contrast against bright wallpapers.
        let tones: (Color, Color, Color)
        switch weatherType {
        case .clear:
            tones = isDark
                ? (RetroPalette.white, RetroPalette.white, RetroPalette.ice)
                : (RetroPalette.white, RetroPalette.ice, RetroPalette.sky)
        case .thunderstorm:
            tones = (RetroPalette.gray, RetroPalette.darkGray, RetroPalette.black)
        default:
            tones = isDark
                ? (RetroPalette.white, RetroPalette.lightGray, RetroPalette.gray)
                : (RetroPalette.lightGray, RetroPalette.gray, RetroPalette.darkGray)
        }

        // Clouds come and go as they drift off-screen. Drop only entries for clouds
        // no longer on screen, so live clouds never all re-rasterise in one frame.
        if cloudCache.count > clouds.count * 2 + 8 {
            let live = Set(clouds.map { CloudKey($0, px: px) })
            cloudCache = cloudCache.filter { live.contains($0.key) }
        }

        // Fair-weather cumulus are already dense; the thin precipitation clouds get
        // a boost because solid pixel fills read fainter than soft gradients.
        let boost = weatherType == .clear ? 0.9 : 1.3

        var painter = PixelPainter(px: px)
        for cloud in clouds {
            let key = CloudKey(cloud, px: px)
            let runs: [CloudRun]
            if let cached = cloudCache[key] {
                runs = cached
            } else {
                runs = rasterise(cloud: cloud, px: px)
                cloudCache[key] = runs
            }

            let alpha = min(0.9, PixelPainter.stepped(cloud.opacity * cloudOpacity * boost, levels: 4))
            let inks = [
                painter.ink(tones.1, opacity: alpha),
                painter.ink(tones.0, opacity: alpha),
                painter.ink(tones.2, opacity: alpha),
            ]
            let cx = painter.grid(cloud.x), cy = painter.grid(cloud.y)
            for run in runs {
                painter.cells(inks[run.shade], gx: cx + run.dx, gy: cy + run.dy, w: run.width)
            }
        }
        painter.flush(into: context)
    }

    /// Builds a cloud's cell runs from the same blob layout the smooth renderer uses.
    private static func rasterise(cloud: Cloud, px: CGFloat) -> [CloudRun] {
        var rng = SeededRNG(seed: cloud.blobSeed)
        var blobs: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)] = []
        for _ in 0..<cloud.blobCount {
            let w = cloud.width * CGFloat(rng.next(in: 0.35...0.7))
            let h = cloud.height * CGFloat(rng.next(in: 0.5...1.0))
            let ox = CGFloat(rng.next(in: -0.4...0.4)) * cloud.width
            let oy = CGFloat(rng.next(in: -0.3...0.3)) * cloud.height
            blobs.append((ox, oy, w / 2, h / 2))
        }

        let halfH = Int((cloud.height * 0.85 / px).rounded(.up))

        // Each blob crosses a row in one analytic span, so a row's coverage is the
        // union of at most `blobCount` intervals — O(rows × blobs), not O(cells × blobs).
        func spans(_ gy: Int) -> [ClosedRange<Int>] {
            let y = (CGFloat(gy) + 0.5) * px
            var out: [ClosedRange<Int>] = []
            for b in blobs {
                let ny = (y - b.cy) / b.ry
                guard abs(ny) <= 1 else { continue }
                let half = b.rx * (1 - ny * ny).squareRoot()
                // Cells whose centres lie inside the ellipse.
                let lo = Int(((b.cx - half) / px - 0.5).rounded(.up))
                let hi = Int(((b.cx + half) / px - 0.5).rounded(.down))
                if lo <= hi { out.append(lo...hi) }
            }
            out.sort { $0.lowerBound < $1.lowerBound }
            var merged: [ClosedRange<Int>] = []
            for r in out {
                if let last = merged.last, r.lowerBound <= last.upperBound + 1 {
                    merged[merged.count - 1] = last.lowerBound...max(last.upperBound, r.upperBound)
                } else {
                    merged.append(r)
                }
            }
            return merged
        }

        func covers(_ row: [ClosedRange<Int>], _ gx: Int) -> Bool {
            row.contains { $0.contains(gx) }
        }

        // Rows from one above the top to two below the bottom, for edge shading.
        var rows: [Int: [ClosedRange<Int>]] = [:]
        for gy in (-halfH - 1)...(halfH + 2) { rows[gy] = spans(gy) }

        var runs: [CloudRun] = []
        for gy in -halfH...halfH {
            let above = rows[gy - 1] ?? [], below = rows[gy + 2] ?? []
            for span in rows[gy] ?? [] {
                // Shade per cell: sunlit if open above, shadowed if open two below.
                func shade(_ gx: Int) -> Int {
                    !covers(above, gx) ? 1 : (!covers(below, gx) ? 2 : 0)
                }
                var start = span.lowerBound
                var current = shade(start)
                for gx in span.lowerBound...span.upperBound + 1 {
                    let s = gx > span.upperBound ? -1 : shade(gx)
                    if s != current {
                        runs.append(CloudRun(dx: start, dy: gy, width: gx - start, shade: current))
                        start = gx
                        current = s
                    }
                }
            }
        }
        return runs
    }
}
