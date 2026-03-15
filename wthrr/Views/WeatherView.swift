// WeatherView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather view

/// Full-screen Canvas that renders weather particles (snow or rain) and secondary
/// effects (drift, splashes, puddles) each frame. Delegates rendering to the
/// appropriate weather-specific renderer based on the active weather type.
struct WeatherView: View {
    @Environment(WeatherSettings.self) private var settings
    @Environment(ScreenGeometry.self)  private var geometry
    @Environment(\.colorScheme)        private var colorScheme
    @StateObject private var model = WeatherAnimationModel()

    var body: some View {
        Canvas { context, size in
            model.configure(size: size, settings: settings)
            _ = model.tick

            let isDark = colorScheme == .dark
            let isRain = settings.weatherType == .rain

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
                    bolt: model.activeBolt
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
                    screenFractures: model.screenFractures
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
                    columnWidth: model.columnWidth
                )
            }
        }
        .ignoresSafeArea()
        .onAppear    { model.start() }
        .onDisappear { model.stop()  }
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
