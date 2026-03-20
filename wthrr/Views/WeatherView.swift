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
        TimelineView(.animation) { _ in
            Canvas { context, size in
                model.configure(size: size, settings: settings)
                model.advance()

                let isDark = colorScheme == .dark

                // Draw clouds behind particles
                if settings.cloudsEnabled {
                    CloudRenderer.draw(
                        context: context,
                        size: size,
                        isDark: isDark,
                        clouds: model.clouds,
                        weatherType: settings.weatherType
                    )
                }

                let pOpacity = settings.particleOpacity
                switch settings.weatherType {
                case .rain:
                    RainRenderer.draw(
                        context: context,
                        size: size,
                        isDark: isDark,
                        particles: model.particles,
                        splashes: model.splashes,
                        puddles: model.puddles,
                        windVelocity: model.currentWindVelocity,
                        bolt: model.activeBolt,
                        particleOpacity: pOpacity
                    )
                case .aiStorm:
                    AIStormRenderer.draw(
                        context: context,
                        size: size,
                        isDark: isDark,
                        particles: model.particles,
                        scanLines: model.scanLines,
                        dataBolts: model.dataBolts,
                        corruptionPatches: model.corruptionPatches,
                        alienShips: model.alienShips,
                        screenFractures: model.screenFractures,
                        particleOpacity: pOpacity
                    )
                case .snow:
                    SnowRenderer.draw(
                        context: context,
                        size: size,
                        isDark: isDark,
                        particles: model.particles,
                        accumulationMap: model.accumulationMap,
                        baselineMap: model.baselineMap,
                        accumulationEnabled: settings.accumulationEnabled,
                        columnWidth: model.columnWidth,
                        particleOpacity: pOpacity
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
        }
    }
}
