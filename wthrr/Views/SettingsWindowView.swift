// SettingsWindowView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Settings window root

/// Settings window with a persistent icon toolbar (System Preferences style).
/// Four tabs — Appearance, Environment, Presets, Behavior — each designed
/// to fit their content without scrolling.
struct SettingsWindowView: View {
    @State private var selectedTab: SettingsTab = .appearance
    @State private var settingsWindow: NSWindow?

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

        /// Target window height for each tab (toolbar + weather picker + content + footer).
        var preferredWindowHeight: CGFloat {
            switch self {
            case .appearance:  return 540
            case .environment: return 640
            case .presets:     return 640
            case .behavior:    return 560
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

            // ── Weather type picker — persistent across all tabs ──
            WeatherTypePicker()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

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

            Divider()

            // ── Persistent footer — visible on every tab ──────
            VStack(spacing: 6) {
                // App info row: version + GitHub link
                AboutView()

                // Action buttons row
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .background(WindowAccessor(window: $settingsWindow))
        .onAppear {
            resizeWindow(to: selectedTab.preferredWindowHeight, animate: false)
        }
        .onChange(of: selectedTab) { _, tab in
            resizeWindow(to: tab.preferredWindowHeight, animate: true)
        }
    }

    private func resizeWindow(to height: CGFloat, animate: Bool) {
        guard let win = settingsWindow else { return }
        var frame = win.frame
        let dy = height - frame.height
        frame.origin.y -= dy          // keep top-left anchor fixed
        frame.size.height = height
        win.setFrame(frame, display: true, animate: animate)
    }
}

// MARK: - Weather type picker (persistent, shown on every tab)

/// Six icon+label buttons — one per weather type — that let the user switch
/// the active weather directly from within the settings window. Disabled when
/// Live Weather is on. Selecting a type updates the live overlay immediately,
/// and the tab-specific controls (Melt Rate, Bird settings, etc.) update to match.
private struct WeatherTypePicker: View {
    @Environment(WeatherSettings.self) private var settings

    private struct WeatherOption {
        let type:  WeatherType
        let icon:  String
        let label: String
    }

    private let options: [WeatherOption] = [
        .init(type: .snow,         icon: "snowflake",            label: "Snow"),
        .init(type: .rain,         icon: "cloud.rain.fill",      label: "Rain"),
        .init(type: .thunderstorm, icon: "cloud.bolt.rain.fill", label: "Storm"),
        .init(type: .fog,          icon: "cloud.fog.fill",       label: "Fog"),
        .init(type: .aurora,       icon: "aqi.medium",           label: "Aurora"),
        .init(type: .aiStorm,      icon: "cpu",                  label: "AI Storm"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.type) { opt in
                let selected = settings.weatherType == opt.type
                Button {
                    settings.weatherType = opt.type
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.multicolor)
                        Text(opt.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected
                                  ? Color.accentColor.opacity(0.14)
                                  : Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor.opacity(0.4) : Color.clear,
                                    lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(settings.liveWeatherEnabled)
        .opacity(settings.liveWeatherEnabled ? 0.4 : 1.0)
        .overlay(alignment: .trailing) {
            if settings.liveWeatherEnabled {
                Text("Live Weather active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 2)
            }
        }
    }
}

// MARK: - Appearance tab

/// Particles (count, speed, opacity) and per-weather-type colour controls.
private struct AppearanceTab: View {
    @Environment(WeatherSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {

            SettingsTabHeader("Particles", icon: "circle.dotted")

            VStack(spacing: 8) {
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

                if settings.weatherType == .aurora {
                    SliderRow(label: "Bird Count", value: auroraBirdCountLabel) {
                        Slider(value: Binding(
                            get: { Double(settings.auroraBirdCount) },
                            set: { settings.auroraBirdCount = Int($0) }
                        ), in: 0...20, step: 1)
                    }
                    SliderRow(label: "Bird Size", value: auroraBirdSizeLabel) {
                        Slider(value: Binding(
                            get: { settings.auroraBirdSize },
                            set: { settings.auroraBirdSize = $0 }
                        ), in: 0.5...3.0, step: 0.1)
                    }
                    SliderRow(label: "Wildness", value: auroraBirdWildnessLabel) {
                        Slider(value: Binding(
                            get: { settings.auroraBirdWildness },
                            set: { settings.auroraBirdWildness = $0 }
                        ), in: 0.0...1.0, step: 0.05)
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

            Spacer()
        }
        .padding(16)
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

    private var auroraBirdCountLabel: String {
        switch settings.auroraBirdCount {
        case 0:       return "Off"
        case 1...3:   return "Few"
        case 4...8:   return "Flock"
        case 9...14:  return "Many"
        default:      return "Murmur"
        }
    }

    private var auroraBirdSizeLabel: String {
        switch settings.auroraBirdSize {
        case ..<0.8:  return "Tiny"
        case ..<1.2:  return "Small"
        case ..<1.7:  return "Medium"
        case ..<2.3:  return "Large"
        default:      return "Huge"
        }
    }

    private var auroraBirdWildnessLabel: String {
        switch settings.auroraBirdWildness {
        case ..<0.2:  return "Uniform"
        case ..<0.45: return "Calm"
        case ..<0.7:  return "Varied"
        default:      return "Wild"
        }
    }
}

// MARK: - Environment tab

/// Wind direction/strength/angle and atmosphere controls (clouds, accumulation, lightning).
private struct EnvironmentTab: View {
    @Environment(WeatherSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {

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

            VStack(alignment: .leading, spacing: 8) {
                // Clouds
                VStack(alignment: .leading, spacing: 8) {
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
                VStack(alignment: .leading, spacing: 8) {
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

                    VStack(alignment: .leading, spacing: 8) {
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

            Spacer()
        }
        .padding(16)
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

    private let columns = [GridItem(.adaptive(minimum: 128), spacing: 8)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ───────────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    SettingsTabHeader("Presets", icon: "star.fill")
                    Spacer()
                    Button {
                        newPresetName = ""
                        showSavePreset.toggle()
                    } label: {
                        Label("Save Current", systemImage: "plus.circle").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Menu {
                        Button("Export Presets\u{2026}") { presetStore.exportPresets() }
                        Button("Import Presets\u{2026}") { presetStore.importPresets() }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 26)
                    .foregroundStyle(.secondary)
                }

                // ── Instructions ─────────────────────────────────
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tap a preset to instantly apply its settings.")
                        Text("Use \u{201C}Save Current\u{201D} to snapshot what you\u{2019}ve configured.")
                        Text("Right-click your own presets to delete them.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                // ── Save-preset field ─────────────────────────────
                if showSavePreset {
                    HStack(spacing: 6) {
                        TextField("Name your preset\u{2026}", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit { saveNewPreset() }
                        Button("Save") { saveNewPreset() }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button {
                            showSavePreset = false
                        } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Built-in presets ──────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("BUILT-IN")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(presetStore.allPresets.filter { $0.isBuiltIn }) { preset in
                            PresetCard(
                                preset: preset,
                                onTap: { settings.apply(preset) },
                                onDelete: nil
                            )
                        }
                    }
                }

                // ── Your presets ──────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR PRESETS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)

                    let userPresets = presetStore.allPresets.filter { !$0.isBuiltIn }
                    if userPresets.isEmpty {
                        Text("Nothing saved yet — hit \u{201C}Save Current\u{201D} to create your first preset.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 6)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(userPresets) { preset in
                                PresetCard(
                                    preset: preset,
                                    onTap: { settings.apply(preset) },
                                    onDelete: { presetStore.delete(named: preset.name) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .animation(.easeInOut(duration: 0.18), value: showSavePreset)
        }
    }

    private func saveNewPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = settings.snapshot(named: name)
        presetStore.save(preset)
        newPresetName  = ""
        showSavePreset = false
    }
}

// MARK: - Preset card

/// Grid card for a named preset. Shows a weather icon, type colour, and name.
/// Supports context-menu delete for user presets.
private struct PresetCard: View {
    let preset:   WeatherPreset
    let onTap:    () -> Void
    let onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Image(systemName: iconForType(preset.weatherType))
                    .font(.system(size: 22))
                    .foregroundStyle(colorForType(preset.weatherType))
                    .frame(height: 26)
                Text(preset.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete Preset", systemImage: "trash")
                }
            } else {
                Text("Built-in preset").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func iconForType(_ type: WeatherType) -> String {
        switch type {
        case .snow:         return "snowflake"
        case .rain:         return "cloud.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .fog:          return "cloud.fog.fill"
        case .aiStorm:      return "bolt.fill"
        case .aurora:       return "aqi.medium"
        }
    }

    private func colorForType(_ type: WeatherType) -> Color {
        switch type {
        case .snow:         return .cyan
        case .rain:         return .blue
        case .thunderstorm: return .purple
        case .fog:          return .gray
        case .aiStorm:      return .green
        case .aurora:       return .teal
        }
    }
}

// MARK: - Behavior tab

/// System integration, automation, and performance options.
/// Covers Launch at Login, Seasonal Weather, Night Dimming, Low Power Mode,
/// and Adaptive Quality (CPU + battery throttling with live status indicator).
private struct BehaviorTab: View {
    @Environment(WeatherSettings.self) private var settings
    // Deferred to .task to avoid blocking the main thread on tab switch
    @State private var launchAtLogin: Bool = false

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {

            SettingsTabHeader("Behavior", icon: "gearshape")

            VStack(alignment: .leading, spacing: 8) {
                // Launch at Login
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

                Divider()

                // Seasonal auto-switch
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

                // Night dimming
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

                Divider()

                // Low Power
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

                Divider()

                // Adaptive Quality
                Toggle(isOn: $settings.adaptiveQualityEnabled) {
                    HStack {
                        Text("Adaptive Quality").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.adaptiveQualityEnabled ? "On" : "Off")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: settings.adaptiveQualityEnabled) { _, enabled in
                    if enabled { AdaptiveQualityMonitor.shared.start() }
                    else       { AdaptiveQualityMonitor.shared.stop()  }
                }

                if settings.adaptiveQualityEnabled {
                    SliderRow(label: "CPU Threshold",
                              value: "\(Int(settings.cpuThreshold * 100))%") {
                        Slider(value: $settings.cpuThreshold, in: 0.40...0.95, step: 0.05)
                    }

                    if AdaptiveQualityMonitor.shared.batteryPercent != nil {
                        SliderRow(label: "Battery Threshold",
                                  value: "\(settings.batteryThreshold)%") {
                            Slider(value: Binding(
                                get: { Double(settings.batteryThreshold) },
                                set: { settings.batteryThreshold = Int($0) }
                            ), in: 5...50, step: 5)
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(AdaptiveQualityMonitor.shared.isRunning
                                  ? (AdaptiveQualityMonitor.shared.cpuUsage >= settings.cpuThreshold
                                     || (!AdaptiveQualityMonitor.shared.isCharging
                                         && (AdaptiveQualityMonitor.shared.batteryPercent ?? 100) <= settings.batteryThreshold)
                                     ? Color.orange : Color.green)
                                  : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(adaptiveStatusText(settings: settings))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .task {
            // SMAppService.mainApp.status is a blocking system call — defer it so
            // the Behavior tab renders immediately without a visible stutter.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// Returns a human-readable status string describing the current adaptive quality state:
    /// "Not monitoring", "Normal · CPU X%", or a "Throttling: …" reason when limits are exceeded.
    private func adaptiveStatusText(settings: WeatherSettings) -> String {
        let monitor = AdaptiveQualityMonitor.shared
        guard monitor.isRunning else { return "Not monitoring" }
        let cpuHigh = monitor.cpuUsage >= settings.cpuThreshold
        let battLow = !monitor.isCharging && (monitor.batteryPercent ?? 100) <= settings.batteryThreshold
        if cpuHigh && battLow { return "Throttling: high CPU + low battery" }
        if cpuHigh            { return "Throttling: CPU \(Int(monitor.cpuUsage * 100))%" }
        if battLow            { return "Throttling: battery \(monitor.batteryPercent ?? 0)%" }
        let cpu = monitor.cpuUsage > 0 ? " · CPU \(Int(monitor.cpuUsage * 100))%" : ""
        return "Normal\(cpu)"
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

// MARK: - Window accessor

/// Zero-size NSViewRepresentable that captures the hosting NSWindow reference.
/// Used by SettingsWindowView to programmatically resize the window per tab.
private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.window = view.window }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { self.window = view.window }
    }
}
