// ContentView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import ServiceManagement

// MARK: - Content view

/// Root view shown inside the `MenuBarExtra` popover.
struct ContentView: View {
    @Environment(WeatherSettings.self) private var settings
    @State private var screens: [NSScreen] = NSScreen.screens
    @State private var showSavePreset = false
    @State private var newPresetName = ""
    @State private var isRecordingHotkey = false
    @State private var pendingHotkey: HotkeyBinding?
    @State private var pauseRowHovered = false
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    private var liveWeather: LiveWeatherService { LiveWeatherService.shared }
    private var presetStore: PresetStore { PresetStore.shared }

    // Persisted section expand/collapse state
    @AppStorage("section.presets")     private var presetsExpanded = false
    @AppStorage("section.particles")   private var particlesExpanded = true
    @AppStorage("section.wind")        private var windExpanded = true
    @AppStorage("section.displays")    private var displaysExpanded = false
    @AppStorage("section.colors")      private var colorsExpanded = false
    @AppStorage("section.performance") private var performanceExpanded = false

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────
                HStack(spacing: 8) {
                    // Weather icon + info (left)
                    headerSection

                    Spacer()

                    // Reroll + Pause (right)
                    Button {
                        settings.reroll()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(settings.rerollLabel)

                    pauseRow
                }
                .padding(.top, 14)
                .padding(.horizontal, 20)

                Divider().padding(.vertical, 8)

                // ── Live mini preview ────────────────────────
                ZStack {
                    Color.black.opacity(0.35)
                    WeatherView()
                        .environment(settings)
                        .environment(ScreenGeometry())
                        .id(settings.weatherType)
                        .transition(.opacity)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                .animation(.easeInOut(duration: 0.4), value: settings.weatherType)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── Always-visible controls ─────────────────
                VStack(spacing: 12) {
                    liveWeatherSection

                    Picker(selection: $settings.weatherType) {
                        Image(systemName: "snowflake").help("Snow").tag(WeatherType.snow)
                        Image(systemName: "cloud.rain.fill").help("Rain").tag(WeatherType.rain)
                        Image(systemName: "cloud.bolt.rain.fill").help("Thunderstorm").tag(WeatherType.thunderstorm)
                        Image(systemName: "cloud.fog.fill").help("Fog").tag(WeatherType.fog)
                        Image(systemName: "cpu").help("AI Storm").tag(WeatherType.aiStorm)
                        Image(systemName: "aqi.medium").help("Aurora").tag(WeatherType.aurora)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.liveWeatherEnabled)

                    intensityQuickTaps
                }
                .padding(.horizontal, 20)

                Divider().padding(.vertical, 10)

                // ── Collapsible sections ────────────────────
                VStack(spacing: 0) {
                    // Particles
                    SettingsSection("Particles", icon: "circle.dotted",
                                    isExpanded: $particlesExpanded) {
                        particlesContent
                    }

                    sectionDivider

                    // Environment (Wind + Atmosphere)
                    SettingsSection("Environment", icon: "wind",
                                    isExpanded: $windExpanded,
                                    badge: environmentBadge) {
                        environmentContent
                    }

                    sectionDivider

                    // Colors
                    SettingsSection("Colors", icon: "paintpalette.fill",
                                    isExpanded: $colorsExpanded,
                                    badge: colorsBadge) {
                        colorsContent
                    }

                    sectionDivider

                    // Displays
                    SettingsSection("Displays", icon: "display",
                                    isExpanded: $displaysExpanded,
                                    badge: displaysBadge) {
                        displaysContent
                    }

                    sectionDivider

                    // Presets
                    SettingsSection("Presets", icon: "star.fill",
                                    isExpanded: $presetsExpanded) {
                        presetsContent
                    }

                    sectionDivider

                    // Behavior & Performance
                    SettingsSection("Behavior", icon: "gearshape",
                                    isExpanded: $performanceExpanded,
                                    badge: behaviorBadge) {
                        behaviorContent
                    }
                }
                .padding(.horizontal, 20)

                Divider().padding(.vertical, 10)

                // ── Footer ──────────────────────────────────
                HStack(spacing: 12) {
                    Button {
                        AppDelegate.shared?.showSplashScreen(manual: true)
                    } label: {
                        Label("About", systemImage: "info.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button {
                        AppDelegate.shared?.showOnboarding()
                    } label: {
                        Label("Onboarding", systemImage: "hand.wave")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button {
                        AppDelegate.shared?.showWhatsNew()
                    } label: {
                        Label("What's New", systemImage: "sparkles")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit wthrr", systemImage: "power")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut("q")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                Divider().padding(.vertical, 6)

                AboutView()
                    .padding(.bottom, 14)

            } // VStack
        } // ScrollView
        .frame(width: 375)
        .frame(maxHeight: 720)
        .background(.regularMaterial)
        .onAppear {
            screens = NSScreen.screens
            if settings.liveWeatherEnabled && !liveWeather.isRunning {
                liveWeather.start()
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            screens = NSScreen.screens
            applyDisplaySettings()
        }
    }

    // MARK: - Thin divider between sections

    private var sectionDivider: some View {
        Divider().padding(.vertical, 2)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.isPaused ? "pause.circle" : settings.weatherIcon)
                .font(.system(size: 36))
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 2) {
                if settings.liveWeatherEnabled {
                    // Live mode: show real temperature prominently
                    Text(settings.temperatureText)
                        .font(.system(size: 26, weight: .light, design: .rounded))
                    Text(settings.isPaused ? "Paused" : settings.weatherLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    // Manual mode: show weather name prominently, no fake temp
                    Text(settings.isPaused ? "Paused" : settings.weatherLabel)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Decorative · Manual")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Pause row

    private var pauseRow: some View {
        VStack(spacing: 4) {
            Button {
                settings.togglePause()
            } label: {
                Label(settings.isPaused ? "Resume" : "Pause",
                      systemImage: settings.isPaused ? "play.fill" : "pause.fill")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if pauseRowHovered || isRecordingHotkey {
                ShortcutBadge(
                    binding: settings.pauseHotkey,
                    isRecording: $isRecordingHotkey,
                    pendingHotkey: $pendingHotkey,
                    onAccept: {
                        if let hotkey = pendingHotkey {
                            settings.pauseHotkey = hotkey
                        }
                        pendingHotkey = nil
                        isRecordingHotkey = false
                    },
                    onCancel: {
                        pendingHotkey = nil
                        isRecordingHotkey = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                pauseRowHovered = hovering
            }
        }
    }

    // MARK: - Intensity quick-taps

    private var intensityQuickTaps: some View {
        HStack(spacing: 6) {
            ForEach(Intensity.allCases) { intensity in
                Button {
                    applyIntensity(intensity)
                } label: {
                    Text(intensity.rawValue)
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(currentIntensity == intensity ? .accentColor : nil)
            }

            if currentIntensity == nil {
                Text("Custom")
                    .font(.caption2.italic())
                    .foregroundStyle(.tertiary)
            }
        }
        .disabled(settings.liveWeatherEnabled)
    }

    // MARK: - Live weather section

    private var liveWeatherSection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $settings.liveWeatherEnabled) {
                HStack {
                    Text("Live Weather")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.liveWeatherEnabled ? "Auto" : "Manual")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: settings.liveWeatherEnabled) { _, enabled in
                if enabled { liveWeather.start() } else { liveWeather.stop() }
            }

            if settings.liveWeatherEnabled {
                HStack(spacing: 6) {
                    if liveWeather.isLoading {
                        ProgressView().controlSize(.mini)
                    } else if let err = liveWeather.errorMessage {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if !liveWeather.locationName.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(liveWeather.locationName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        liveWeather.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(liveWeather.isLoading)
                }
                Text("Type and intensity are set automatically")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Section: Presets

    private var presetsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Button {
                    newPresetName = ""
                    showSavePreset.toggle()
                } label: {
                    Label("Save Current", systemImage: "plus.circle")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Menu {
                    Button("Export Presets\u{2026}") { presetStore.exportPresets() }
                    Button("Import Presets\u{2026}") { presetStore.importPresets() }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.caption)
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
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
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
    }

    // MARK: - Section: Particles

    private var particlesContent: some View {
        VStack(spacing: 10) {
            sliderRow(label: "Amount",
                      value: "\(settings.flakeCount) \(settings.particleUnit)") {
                Slider(value: Binding(
                    get: { Double(settings.flakeCount) },
                    set: { settings.flakeCount = Int($0) }
                ), in: 20...400, step: 10)
            }
            .disabled(settings.liveWeatherEnabled)

            sliderRow(label: "Speed",
                      value: speedLabelForType(settings.weatherType, settings.speedMultiplier)) {
                Slider(value: Binding(
                    get: { settings.speedMultiplier },
                    set: { settings.speedMultiplier = $0 }
                ), in: 0.25...3.0, step: 0.05)
            }
            .disabled(settings.liveWeatherEnabled)

            sliderRow(label: "Opacity", value: settings.particleOpacityLabel) {
                Slider(value: Binding(
                    get: { settings.particleOpacity },
                    set: { settings.particleOpacity = $0 }
                ), in: 0.2...1.5, step: 0.05)
            }
        }
    }

    // MARK: - Section: Environment (Wind + Atmosphere)

    private var environmentBadge: String? {
        var parts: [String] = []
        if let w = windBadge { parts.append(w) }
        if let a = atmosphereBadge { parts.append(a) }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var environmentContent: some View {
        VStack(spacing: 0) {
            windContent
            Divider().padding(.vertical, 8)
            atmosphereContent
        }
    }

    // MARK: - Wind

    private var windBadge: String? {
        settings.windStrength < 0.05 ? "Calm" : windLabel(settings.windStrength)
    }

    private var windContent: some View {
        @Bindable var settings = settings
        return VStack(spacing: 8) {
            sliderRow(label: "Strength", value: windLabel(settings.windStrength)) {
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

            sliderRow(label: "Fall Angle", value: "\(Int(settings.windAngle))\u{00B0}") {
                Slider(value: Binding(
                    get: { settings.windAngle },
                    set: { settings.windAngle = $0 }
                ), in: -45...45, step: 1)
            }
        }
        .disabled(settings.liveWeatherEnabled)
    }

    // MARK: - Section: Atmosphere

    private var atmosphereBadge: String? {
        var parts: [String] = []
        if settings.cloudsEnabled { parts.append("Clouds") }
        if settings.accumulationEnabled { parts.append(settings.weatherType == .rain || settings.weatherType == .thunderstorm ? "Puddles" : "Drift") }
        if (settings.weatherType == .rain || settings.weatherType == .thunderstorm) && settings.lightningEnabled { parts.append("Lightning") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var atmosphereContent: some View {
        @Bindable var settings = settings
        return VStack(spacing: 10) {
            // Clouds
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.cloudsEnabled) {
                    HStack {
                        Text("Clouds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.cloudsEnabled ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if settings.cloudsEnabled {
                    sliderRow(label: "Size", value: settings.cloudSizeLabel) {
                        Slider(value: $settings.cloudSize, in: 0.5...1.5, step: 0.1)
                    }
                    sliderRow(label: "Speed", value: settings.cloudSpeedLabel) {
                        Slider(value: $settings.cloudSpeed, in: 0.25...3.0, step: 0.05)
                    }
                    sliderRow(label: "Cloud Opacity", value: cloudOpacityLabel) {
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.accumulationEnabled ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if settings.accumulationEnabled {
                    Text(settings.accumulationDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Drift depth (snow-only)
                if settings.weatherType == .snow && settings.accumulationEnabled {
                    sliderRow(label: "Drift Depth", value: settings.driftDepthLabel) {
                        Slider(value: Binding(
                            get: { Double(settings.maxAccumulationHeight) },
                            set: { settings.maxAccumulationHeight = Int($0) }
                        ), in: 20...300, step: 10)
                    }
                }
            }

            // Lightning (rain & thunderstorm)
            if settings.weatherType == .rain || settings.weatherType == .thunderstorm {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $settings.lightningEnabled) {
                        HStack {
                            Text("Lightning")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.lightningEnabled ? "On" : "Off")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if settings.lightningEnabled {
                        sliderRow(label: "Frequency", value: settings.lightningFrequencyLabel) {
                            Slider(value: $settings.lightningFrequency, in: 0.25...3.0, step: 0.05)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section: Colors

    private var colorsBadge: String? {
        let type = settings.weatherType
        if type == .snow && settings.snowTintHue >= 0 { return "Tinted" }
        if (type == .rain || type == .thunderstorm) && settings.rainTintHue >= 0 { return "Tinted" }
        if type == .aiStorm && settings.aiStormPalette != 0 {
            return ColorTheme.aiStormPaletteNames[settings.aiStormPalette]
        }
        if type == .fog && settings.fogTintHue >= 0 { return "Tinted" }
        return nil
    }

    private var colorsContent: some View {
        @Bindable var settings = settings
        return VStack(spacing: 10) {
            switch settings.weatherType {
            case .snow:
                colorSlider(label: "Snow Tint", hue: $settings.snowTintHue)
            case .rain, .thunderstorm:
                colorSlider(label: "Rain Tint", hue: $settings.rainTintHue)
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
                colorSlider(label: "Fog Tint", hue: $settings.fogTintHue)
            case .aurora:
                colorSlider(label: "Aurora Tint", hue: $settings.fogTintHue)
            }
        }
    }

    /// A hue slider with a "Default" reset button. Value of -1 means default.
    private func colorSlider(label: String, hue: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if hue.wrappedValue >= 0 {
                    Button("Reset") { hue.wrappedValue = -1 }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Default")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Color preview + slider
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hue.wrappedValue >= 0
                          ? Color(hue: hue.wrappedValue, saturation: 0.6, brightness: 0.9)
                          : Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary, lineWidth: 1))

                Slider(value: Binding(
                    get: { hue.wrappedValue < 0 ? 0.55 : hue.wrappedValue },
                    set: { hue.wrappedValue = $0 }
                ), in: 0...1, step: 0.01)
            }
        }
    }

    // MARK: - Section: Displays

    private var displaysBadge: String? {
        settings.displayMode == .all ? "All" : "\(settings.selectedDisplayIDs.count) selected"
    }

    private var displaysContent: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $settings.displayMode) {
                Text("All Displays").tag(DisplayMode.all)
                Text("Choose...").tag(DisplayMode.selected)
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.displayMode) { _, _ in
                applyDisplaySettings()
            }

            if settings.displayMode == .selected {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(screens, id: \.displayID) { screen in
                        let isOn = settings.selectedDisplayIDs.contains(screen.displayID)
                        Button {
                            settings.toggleDisplay(screen)
                            applyDisplaySettings()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isOn ? .blue : .secondary)
                                Text(screen.localizedName)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    if screens.isEmpty {
                        Text("No screens detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Section: Behavior & Performance

    private var behaviorBadge: String? {
        var parts: [String] = []
        if launchAtLogin { parts.append("Auto-start") }
        if settings.seasonalEnabled { parts.append("Seasonal") }
        if settings.timeDimmingEnabled { parts.append("Night Dim") }
        if settings.lowPowerMode { parts.append("Low Power") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var behaviorContent: some View {
        @Bindable var settings = settings
        return VStack(spacing: 10) {
            // Launch at Login
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $launchAtLogin) {
                    HStack {
                        Text("Launch at Login")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(launchAtLogin ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Revert the toggle if the system call fails
                        launchAtLogin = (SMAppService.mainApp.status == .enabled)
                    }
                }

                if launchAtLogin {
                    Text("wthrr will start automatically when you log in")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            // Seasonal auto-switch
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.seasonalEnabled) {
                    HStack {
                        Text("Seasonal Weather")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.seasonalEnabled ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: settings.seasonalEnabled) { _, enabled in
                    if enabled { settings.applySeasonalWeather() }
                }

                if settings.seasonalEnabled {
                    Text("Auto-switches weather type with the seasons")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Time-of-day dimming
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.timeDimmingEnabled) {
                    HStack {
                        Text("Night Dimming")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.timeDimmingEnabled ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: settings.timeDimmingEnabled) { _, _ in
                    settings.updateTimeDimming()
                }

                if settings.timeDimmingEnabled {
                    Text("Subtly dims effects at night (10pm\u{2013}5am)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Snow melt rate (snow only)
            if settings.weatherType == .snow {
                sliderRow(label: "Melt Rate", value: snowMeltLabel) {
                    Slider(value: Binding(
                        get: { settings.snowMeltRate },
                        set: { settings.snowMeltRate = $0 }
                    ), in: 0.02...0.2, step: 0.01)
                }
            }

            // AI Storm density (AI storm only)
            if settings.weatherType == .aiStorm {
                sliderRow(label: "Effect Density", value: aiStormDensityLabel) {
                    Slider(value: Binding(
                        get: { settings.aiStormDensity },
                        set: { settings.aiStormDensity = $0 }
                    ), in: 0.25...3.0, step: 0.05)
                }
            }

            Divider()

            // Low Power mode
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $settings.lowPowerMode) {
                    HStack {
                        Text("Low Power Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.lowPowerMode ? "On" : "Off")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if settings.lowPowerMode {
                    Text("Limits animation to ~30 fps to reduce CPU usage")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Reusable components

    private func sliderRow<S: View>(label: String, value: String,
                                     @ViewBuilder slider: () -> S) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            slider()
        }
    }

    // MARK: - Intensity

    private enum Intensity: String, CaseIterable, Identifiable {
        case light  = "Light"
        case medium = "Medium"
        case heavy  = "Heavy"
        var id: String { rawValue }
    }

    private var currentIntensity: Intensity? {
        let count = settings.flakeCount
        let speed = settings.speedMultiplier
        if count <= 80 && speed <= 0.65 { return .light }
        if count >= 250 && speed >= 1.8 { return .heavy }
        if (100...220).contains(count) && (0.8...1.4).contains(speed) { return .medium }
        return nil
    }

    private func applyIntensity(_ intensity: Intensity) {
        switch intensity {
        case .light:
            settings.flakeCount = 60
            settings.speedMultiplier = 0.5
            settings.windStrength = 0.15
            settings.particleOpacity = 0.7
        case .medium:
            settings.flakeCount = 180
            settings.speedMultiplier = 1.0
            settings.windStrength = 0.5
            settings.particleOpacity = 1.0
        case .heavy:
            settings.flakeCount = 350
            settings.speedMultiplier = 2.2
            settings.windStrength = 0.8
            settings.particleOpacity = 1.2
        }
    }

    // MARK: - Preset helpers

    private func saveNewPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = settings.snapshot(named: name)
        presetStore.save(preset)
        newPresetName = ""
        showSavePreset = false
    }

    // MARK: - Helpers

    private func applyDisplaySettings() {
        AppDelegate.shared?.overlayWindowController?.applySettings()
    }

    private func speedLabelForType(_ type: WeatherType, _ v: Double) -> String {
        switch type {
        case .rain:         return rainSpeedLabel(v)
        case .thunderstorm: return rainSpeedLabel(v)
        case .aiStorm:      return aiStormSpeedLabel(v)
        case .fog:          return speedLabel(v)
        case .aurora:       return speedLabel(v)
        case .snow:         return speedLabel(v)
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

    private var cloudOpacityLabel: String {
        switch settings.cloudOpacity {
        case ..<0.5:  return "Faint"
        case ..<0.9:  return "Light"
        case ..<1.2:  return "Normal"
        case ..<1.6:  return "Thick"
        default:      return "Dense"
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

// MARK: - Collapsible settings section

/// A styled collapsible section with icon, title, optional summary badge, and chevron.
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let badge: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String, icon: String,
         isExpanded: Binding<Bool>,
         badge: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.badge = badge
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)

                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)

                    if let badge, !isExpanded {
                        Text(badge)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible body
            if isExpanded {
                content()
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .padding(.leading, 20) // indent under icon
            }
        }
    }
}

// MARK: - Shortcut badge

/// Tappable badge showing the current hotkey. Tap to enter recording mode,
/// press a new shortcut, then accept or cancel.
struct ShortcutBadge: View {
    let binding: HotkeyBinding
    @Binding var isRecording: Bool
    @Binding var pendingHotkey: HotkeyBinding?
    let onAccept: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if isRecording {
            HStack(spacing: 6) {
                Text(pendingHotkey?.displayString ?? "Press keys\u{2026}")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(pendingHotkey != nil ? .primary : .tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    )
                    .background(
                        KeyEventCatcher { event in
                            if let hotkey = HotkeyBinding.from(event: event) {
                                pendingHotkey = hotkey
                            }
                        }
                    )

                if pendingHotkey != nil {
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Accept new shortcut")
                }

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
        } else {
            Button {
                isRecording = true
                pendingHotkey = nil
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text(binding.displayString)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Click to change shortcut")
        }
    }
}

// MARK: - Key event catcher

/// An invisible NSView-backed view that becomes first responder to capture key events
/// during shortcut recording.
struct KeyEventCatcher: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    class KeyCatcherView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}

// MARK: - Preset pill

/// Compact pill button for loading a preset.
struct PresetPill: View {
    let preset: WeatherPreset
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Image(systemName: iconForType(preset.weatherType))
                    .font(.system(size: 8))
                Text(preset.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func iconForType(_ type: WeatherType) -> String {
        switch type {
        case .snow:         return "snowflake"
        case .rain:         return "cloud.rain"
        case .thunderstorm: return "cloud.bolt.rain"
        case .fog:          return "cloud.fog"
        case .aiStorm:      return "bolt"
        case .aurora:       return "aqi.medium"
        }
    }
}

// MARK: - Flow layout

/// Simple horizontal wrapping layout for preset pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x,
                                               y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
        }

        return ArrangeResult(positions: positions,
                             size: CGSize(width: totalWidth, height: y + rowHeight))
    }
}

// MARK: - About view

struct AboutView: View {
    private let repoURL = URL(string: "https://github.com/todddube/wthrr_mac")!

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("wthrr  \(appVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("by Todd Dube  \u{00B7}")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    NSWorkspace.shared.open(repoURL)
                } label: {
                    Text("GitHub")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .help("Open wthrr_mac on GitHub")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WeatherSettings())
}
