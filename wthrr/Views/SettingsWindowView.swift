// SettingsWindowView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Settings window root

/// Settings window with a persistent icon toolbar (System Preferences style).
/// Five sections are always visible in the toolbar — no overflow, no dropdowns.
struct SettingsWindowView: View {
    @State private var selectedTab: SettingsTab = .appearance

    enum SettingsTab: String, CaseIterable {
        case appearance  = "Appearance"
        case environment = "Environment"
        case presets     = "Presets"
        case behavior    = "Behavior"

        var icon: String {
            switch self {
            case .appearance:  return "paintpalette.fill"
            case .environment: return "wind"
            case .presets:     return "star.fill"
            case .behavior:    return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Icon toolbar ─────────────────────────────────
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab
                                      ? Color.accentColor.opacity(0.12)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // ── Content area ─────────────────────────────────
            Group {
                switch selectedTab {
                case .appearance:  AppearanceTab()
                case .environment: EnvironmentTab()
                case .presets:     PresetsTab()
                case .behavior:    BehaviorTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 520, height: 530)
        .background(.regularMaterial)
    }
}

// MARK: - Appearance tab

/// Particles (count, speed, opacity) and per-weather-type colour controls.
private struct AppearanceTab: View {
    @Environment(WeatherSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SettingsTabHeader("Particles", icon: "circle.dotted")

                VStack(spacing: 10) {
                    SliderRow(label: "Amount",
                              value: "\(settings.flakeCount) \(settings.particleUnit)") {
                        Slider(value: Binding(
                            get: { Double(settings.flakeCount) },
                            set: { settings.flakeCount = Int($0) }
                        ), in: 20...400, step: 10)
                    }
                    .disabled(settings.liveWeatherEnabled)

                    SliderRow(label: "Speed",
                              value: speedLabelForType(settings.weatherType, settings.speedMultiplier)) {
                        Slider(value: Binding(
                            get: { settings.speedMultiplier },
                            set: { settings.speedMultiplier = $0 }
                        ), in: 0.25...3.0, step: 0.05)
                    }
                    .disabled(settings.liveWeatherEnabled)

                    SliderRow(label: "Opacity", value: settings.particleOpacityLabel) {
                        Slider(value: Binding(
                            get: { settings.particleOpacity },
                            set: { settings.particleOpacity = $0 }
                        ), in: 0.2...1.5, step: 0.05)
                    }

                    if settings.weatherType == .snow {
                        SliderRow(label: "Melt Rate", value: snowMeltLabel) {
                            Slider(value: Binding(
                                get: { settings.snowMeltRate },
                                set: { settings.snowMeltRate = $0 }
                            ), in: 0.02...0.2, step: 0.01)
                        }
                    }

                    if settings.weatherType == .aiStorm {
                        SliderRow(label: "Effect Density", value: aiStormDensityLabel) {
                            Slider(value: Binding(
                                get: { settings.aiStormDensity },
                                set: { settings.aiStormDensity = $0 }
                            ), in: 0.25...3.0, step: 0.05)
                        }
                    }
                }

                Divider()

                SettingsTabHeader("Colors", icon: "paintpalette.fill")

                switch settings.weatherType {
                case .snow:
                    ColorSliderRow(label: "Snow Tint", hue: $settings.snowTintHue)
                case .rain, .thunderstorm:
                    ColorSliderRow(label: "Rain Tint", hue: $settings.rainTintHue)
                case .aiStorm:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neon Palette")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $settings.aiStormPalette) {
                            ForEach(0..<ColorTheme.aiStormPaletteNames.count, id: \.self) { i in
                                Text(ColorTheme.aiStormPaletteNames[i]).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                case .fog:
                    ColorSliderRow(label: "Fog Tint", hue: $settings.fogTintHue)
                case .aurora:
                    ColorSliderRow(label: "Aurora Tint", hue: $settings.fogTintHue)
                }
            }
            .padding(20)
        }
    }

    // MARK: Label helpers

    private func speedLabelForType(_ type: WeatherType, _ v: Double) -> String {
        switch type {
        case .rain, .thunderstorm: return rainSpeedLabel(v)
        case .aiStorm:             return aiStormSpeedLabel(v)
        default:                   return speedLabel(v)
        }
    }

    private func speedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Gentle"
        case ..<1.0:  return "Light"
        case ..<1.5:  return "Normal"
        case ..<2.2:  return "Heavy"
        default:      return "Blizzard"
        }
    }

    private func rainSpeedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Mist"
        case ..<1.0:  return "Drizzle"
        case ..<1.5:  return "Shower"
        case ..<2.2:  return "Downpour"
        default:      return "Monsoon"
        }
    }

    private func aiStormSpeedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Flicker"
        case ..<1.0:  return "Glitch"
        case ..<1.5:  return "Surge"
        case ..<2.2:  return "Overload"
        default:      return "Singularity"
        }
    }

    private var snowMeltLabel: String {
        switch settings.snowMeltRate {
        case ..<0.04: return "Slow"
        case ..<0.08: return "Normal"
        case ..<0.14: return "Fast"
        default:      return "Rapid"
        }
    }

    private var aiStormDensityLabel: String {
        switch settings.aiStormDensity {
        case ..<0.5:  return "Sparse"
        case ..<1.0:  return "Normal"
        case ..<2.0:  return "Dense"
        default:      return "Chaotic"
        }
    }
}

// MARK: - Environment tab

/// Wind direction/strength/angle and atmosphere controls (clouds, accumulation, lightning).
private struct EnvironmentTab: View {
    @Environment(WeatherSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SettingsTabHeader("Wind", icon: "wind")

                VStack(spacing: 8) {
                    SliderRow(label: "Strength", value: windLabel(settings.windStrength)) {
                        Slider(value: $settings.windStrength, in: 0.0...1.0, step: 0.05)
                    }

                    if settings.windStrength > 0 {
                        Picker("Direction", selection: $settings.windDirection) {
                            Text("\u{2190} Left").tag(WindDirection.left)
                            Text("Natural").tag(WindDirection.natural)
                            Text("Right \u{2192}").tag(WindDirection.right)
                        }
                        .pickerStyle(.segmented)
                        .font(.caption)
                    }

                    SliderRow(label: "Fall Angle", value: "\(Int(settings.windAngle))\u{00B0}") {
                        Slider(value: Binding(
                            get: { settings.windAngle },
                            set: { settings.windAngle = $0 }
                        ), in: -45...45, step: 1)
                    }
                }
                .disabled(settings.liveWeatherEnabled)

                Divider()

                SettingsTabHeader("Atmosphere", icon: "cloud.fill")

                VStack(alignment: .leading, spacing: 12) {
                    // Clouds
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.cloudsEnabled) {
                            HStack {
                                Text("Clouds").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.cloudsEnabled ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        if settings.cloudsEnabled {
                            SliderRow(label: "Size", value: settings.cloudSizeLabel) {
                                Slider(value: $settings.cloudSize, in: 0.5...1.5, step: 0.1)
                            }
                            SliderRow(label: "Speed", value: settings.cloudSpeedLabel) {
                                Slider(value: $settings.cloudSpeed, in: 0.25...3.0, step: 0.05)
                            }
                            SliderRow(label: "Cloud Opacity", value: cloudOpacityLabel) {
                                Slider(value: Binding(
                                    get: { settings.cloudOpacity },
                                    set: { settings.cloudOpacity = $0 }
                                ), in: 0.3...2.0, step: 0.05)
                            }
                        }
                    }

                    Divider()

                    // Accumulation / Puddles
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.accumulationEnabled) {
                            HStack {
                                Text(settings.accumulationLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.accumulationEnabled ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        if settings.accumulationEnabled {
                            Text(settings.accumulationDescription)
                                .font(.caption2).foregroundStyle(.tertiary)
                        }

                        if settings.weatherType == .snow && settings.accumulationEnabled {
                            SliderRow(label: "Drift Depth", value: settings.driftDepthLabel) {
                                Slider(value: Binding(
                                    get: { Double(settings.maxAccumulationHeight) },
                                    set: { settings.maxAccumulationHeight = Int($0) }
                                ), in: 20...300, step: 10)
                            }
                        }
                    }

                    // Lightning (rain & thunderstorm only)
                    if settings.weatherType == .rain || settings.weatherType == .thunderstorm {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: $settings.lightningEnabled) {
                                HStack {
                                    Text("Lightning").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(settings.lightningEnabled ? "On" : "Off")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            if settings.lightningEnabled {
                                SliderRow(label: "Frequency", value: settings.lightningFrequencyLabel) {
                                    Slider(value: $settings.lightningFrequency, in: 0.25...3.0, step: 0.05)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var cloudOpacityLabel: String {
        switch settings.cloudOpacity {
        case ..<0.5:  return "Faint"
        case ..<0.9:  return "Light"
        case ..<1.2:  return "Normal"
        case ..<1.6:  return "Thick"
        default:      return "Dense"
        }
    }

    private func windLabel(_ v: Double) -> String {
        switch v {
        case ..<0.05: return "Calm"
        case ..<0.25: return "Breeze"
        case ..<0.5:  return "Blustery"
        case ..<0.75: return "Gusty"
        case ..<0.9:  return "Gale"
        default:      return "Storm"
        }
    }
}

// MARK: - Presets tab

/// Save, load, export, and import named weather presets.
private struct PresetsTab: View {
    @Environment(WeatherSettings.self) private var settings
    @State private var showSavePreset = false
    @State private var newPresetName  = ""
    private var presetStore: PresetStore { PresetStore.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    SettingsTabHeader("Presets", icon: "star.fill")
                    Spacer()
                    Button {
                        newPresetName = ""
                        showSavePreset.toggle()
                    } label: {
                        Label("Save Current", systemImage: "plus.circle").font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Menu {
                        Button("Export Presets\u{2026}") { presetStore.exportPresets() }
                        Button("Import Presets\u{2026}") { presetStore.importPresets() }
                    } label: {
                        Image(systemName: "square.and.arrow.up.on.square").font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                }

                if showSavePreset {
                    HStack(spacing: 4) {
                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit { saveNewPreset() }
                        Button("Save") { saveNewPreset() }
                            .font(.caption)
                            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if presetStore.allPresets.filter({ !$0.isBuiltIn }).isEmpty {
                    Text("Tap + to save your current settings as a preset")
                        .font(.caption2).foregroundStyle(.tertiary).padding(.top, 2)
                }

                FlowLayout(spacing: 4) {
                    ForEach(presetStore.allPresets) { preset in
                        PresetPill(
                            preset: preset,
                            onTap: { settings.apply(preset) },
                            onDelete: preset.isBuiltIn ? nil : { presetStore.delete(named: preset.name) }
                        )
                    }
                }
            }
            .padding(20)
        }
    }

    private func saveNewPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = settings.snapshot(named: name)
        presetStore.save(preset)
        newPresetName    = ""
        showSavePreset   = false
    }
}

// MARK: - Behavior tab

/// System integration, automation, and performance options.
private struct BehaviorTab: View {
    @Environment(WeatherSettings.self) private var settings
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        @Bindable var settings = settings
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                SettingsTabHeader("Behavior", icon: "gearshape")

                VStack(alignment: .leading, spacing: 10) {
                    // Launch at Login
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $launchAtLogin) {
                            HStack {
                                Text("Launch at Login").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(launchAtLogin ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register()   }
                                else       { try SMAppService.mainApp.unregister() }
                            } catch {
                                launchAtLogin = (SMAppService.mainApp.status == .enabled)
                            }
                        }
                        if launchAtLogin {
                            Text("wthrr will start automatically when you log in")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    // Seasonal auto-switch
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.seasonalEnabled) {
                            HStack {
                                Text("Seasonal Weather").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.seasonalEnabled ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.seasonalEnabled) { _, enabled in
                            if enabled { settings.applySeasonalWeather() }
                        }
                        if settings.seasonalEnabled {
                            Text("Auto-switches weather type with the seasons")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }

                    // Night dimming
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.timeDimmingEnabled) {
                            HStack {
                                Text("Night Dimming").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.timeDimmingEnabled ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.timeDimmingEnabled) { _, _ in
                            settings.updateTimeDimming()
                        }
                        if settings.timeDimmingEnabled {
                            Text("Subtly dims effects at night (10pm\u{2013}5am)")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    // Low Power
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $settings.lowPowerMode) {
                            HStack {
                                Text("Low Power Mode").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.lowPowerMode ? "On" : "Off")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        if settings.lowPowerMode {
                            Text("Limits animation to ~30 fps to reduce CPU usage")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }

                Divider()

                // About / links
                SettingsTabHeader("About", icon: "info.circle")

                AboutView()

                HStack(spacing: 8) {
                    Button {
                        AppDelegate.shared?.showSplashScreen(manual: true)
                    } label: {
                        Label("About", systemImage: "info.circle").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        AppDelegate.shared?.showOnboarding()
                    } label: {
                        Label("Onboarding", systemImage: "hand.wave").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        AppDelegate.shared?.showWhatsNew()
                    } label: {
                        Label("What's New", systemImage: "sparkles").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Shared helper views

/// A labeled row with a value readout on the right and a slider below.
struct SliderRow<S: View>: View {
    let label: String
    let value: String
    @ViewBuilder let slider: () -> S

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            slider()
        }
    }
}

/// A hue slider with a colour-preview swatch and a "Reset" / "Default" label.
struct ColorSliderRow: View {
    let label: String
    @Binding var hue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if hue >= 0 {
                    Button("Reset") { hue = -1 }.font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Default").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hue >= 0
                          ? Color(hue: hue, saturation: 0.6, brightness: 0.9)
                          : Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary, lineWidth: 1))
                Slider(value: Binding(
                    get: { hue < 0 ? 0.55 : hue },
                    set: { hue = $0 }
                ), in: 0...1, step: 0.01)
            }
        }
    }
}

/// Small icon + title header used at the top of each settings tab section.
private struct SettingsTabHeader: View {
    let title: String
    let icon:  String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon  = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }
}
