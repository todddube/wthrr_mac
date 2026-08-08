// WeatherView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Weather view

/// Full-screen view that renders weather particles (snow, rain, or AI storm) and
/// secondary effects (drift, splashes, puddles) each frame. Uses a `TimelineView`
/// to drive redraws and delegates rendering to the appropriate weather-specific
/// renderer based on the active weather type.
///
/// The timeline's pacing comes from `RenderBudget`, which caps the frame rate and
/// suspends the timeline entirely when the overlay is paused, occluded, or the
/// displays are asleep. A suspended timeline requests no frames at all, so the
/// Canvas closure below is never invoked and nothing is rasterised.
struct WeatherView: View {
    @Environment(WeatherSettings.self) private var settings
    @Environment(ScreenGeometry.self)  private var geometry
    @Environment(\.colorScheme)        private var colorScheme
    @State private var model = WeatherAnimationModel()

    var body: some View {
        let budget = RenderBudget.current(settings: settings, isVisible: geometry.isVisible)

        TimelineView(.animation(minimumInterval: budget.minimumInterval, paused: budget.paused)) { timeline in
            Canvas { context, size in
                let frame = PerformanceMonitor.shared.beginFrame(canvasID: geometry.canvasID)
                defer {
                    PerformanceMonitor.shared.endFrame(frame, particleCount: model.particles.count)
                }

                model.configure(size: size, settings: settings)

                // `tick` makes this a no-op if SwiftUI evaluates the Canvas closure
                // more than once for a single timeline tick, so physics can't double-step.
                PerformanceMonitor.shared.measurePhysics {
                    model.advance(settings: settings, tick: timeline.date)
                }

                let isDark = colorScheme == .dark

                // Clouds are drawn first (behind particles) so particles appear to fall through them
                if settings.cloudsEnabled || settings.weatherType == .thunderstorm {
                    CloudRenderer.draw(
                        context: context,
                        size: size,
                        isDark: isDark,
                        clouds: model.clouds,
                        weatherType: settings.weatherType,
                        cloudOpacity: settings.cloudOpacity
                    )
                }

                // Combine user opacity setting with the time-of-day dim factor
                // so effects fade naturally at night without changing the stored setting.
                let pOpacity = settings.particleOpacity * settings.timeDimFactor
                switch settings.weatherType {
                case .rain:
                    RainRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        splashes: model.splashes, puddles: model.puddles,
                        windVelocity: model.currentWindVelocity,
                        bolt: model.activeBolt,
                        particleOpacity: pOpacity,
                        tintHue: settings.rainTintHue
                    )
                case .aiStorm:
                    AIStormRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        scanLines: model.scanLines,
                        dataBolts: model.dataBolts,
                        corruptionPatches: model.corruptionPatches,
                        alienShips: model.alienShips,
                        screenFractures: model.screenFractures,
                        particleOpacity: pOpacity
                    )
                case .thunderstorm:
                    RainRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        splashes: model.splashes, puddles: model.puddles,
                        windVelocity: model.currentWindVelocity,
                        bolt: model.activeBolt,
                        particleOpacity: pOpacity,
                        tintHue: settings.rainTintHue
                    )
                case .fog:
                    FogRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        fogBands: model.fogBands,
                        particleOpacity: pOpacity,
                        tintHue: settings.fogTintHue
                    )
                case .aurora:
                    AuroraRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        time: model.auroraTime,
                        particleOpacity: pOpacity,
                        birdCount: settings.auroraBirdCount,
                        birdSize: settings.auroraBirdSize,
                        birdWildness: settings.auroraBirdWildness
                    )
                case .snow:
                    // Frost level: starts at 20% average accumulation, full at 100%.
                    // Uses the same effective height cap the physics engine uses so
                    // the fraction stays in [0, 1] even when maxAccumulationHeight
                    // exceeds 20% of the screen (the model's hard ceiling).
                    let frostLevel: CGFloat = {
                        guard settings.accumulationEnabled,
                              !model.accumulationMap.isEmpty else { return 0 }
                        let avg = model.accumulationMap.reduce(0, +)
                                  / CGFloat(model.accumulationMap.count)
                        let effectiveMax = min(CGFloat(settings.maxAccumulationHeight),
                                               size.height * 0.20)
                        guard effectiveMax > 0 else { return 0 }
                        return max(0, min(1, (avg / effectiveMax - 0.20) / 0.80))
                    }()
                    SnowRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        accumulationMap: model.accumulationMap,
                        baselineMap: model.baselineMap,
                        accumulationEnabled: settings.accumulationEnabled,
                        columnWidth: model.columnWidth,
                        particleOpacity: pOpacity,
                        tintHue: settings.snowTintHue,
                        time: model.snowTime,
                        frostLevel: frostLevel
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: settings.accumulationEnabled) { _, enabled in
            if !enabled {
                model.clearAccumulation()
                if settings.weatherType == .rain { model.clearRainEffects() }
            }
        }
        .onChange(of: settings.weatherType) { _, _ in
            model.clearAccumulation()
            model.clearRainEffects()
            model.clearAIStormEffects()
            model.clearFogEffects()
            model.clearAuroraEffects()
        }
    }
}
