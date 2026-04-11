// WeatherView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather view

/// Full-screen view that renders weather particles (snow, rain, or AI storm) and
/// secondary effects (drift, splashes, puddles) each frame. Uses a `TimelineView`
/// to drive display-refresh-synced redraws and delegates rendering to the
/// appropriate weather-specific renderer based on the active weather type.
struct WeatherView: View {
    @Environment(WeatherSettings.self) private var settings
    @Environment(ScreenGeometry.self)  private var geometry
    @Environment(\.colorScheme)        private var colorScheme
    @State private var model = WeatherAnimationModel()

    var body: some View {
        // TimelineView(.animation) requests a redraw every display refresh cycle (~60 fps).
        // The Canvas closure is called once per frame with the current graphics context and size.
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Configure and advance are driven by the timeline date change,
                // not inside the Canvas closure, to avoid double-advances if
                // Canvas evaluates its body more than once per frame.
                model.configure(size: size, settings: settings)
                model.advance(settings: settings)

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
                    SnowRenderer.draw(
                        context: context, size: size, isDark: isDark,
                        particles: model.particles,
                        accumulationMap: model.accumulationMap,
                        baselineMap: model.baselineMap,
                        accumulationEnabled: settings.accumulationEnabled,
                        columnWidth: model.columnWidth,
                        particleOpacity: pOpacity,
                        tintHue: settings.snowTintHue
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
