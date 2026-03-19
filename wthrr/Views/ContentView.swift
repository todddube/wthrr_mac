// ContentView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Content view

/// Root view shown inside the `MenuBarExtra` popover.
/// Provides the weather summary header, all simulation controls (amount, speed,
/// wind, display selection), a re-randomise button, quit button, and the about footer.
/// A semi-transparent `WeatherView` floats behind all controls as a visual flourish.
struct ContentView: View {
    @Environment(WeatherSettings.self) private var settings
    @State private var screens: [NSScreen] = NSScreen.screens

    var body: some View {
        @Bindable var settings = settings

        ZStack {
            // Animated weather background — floats behind all controls.
            WeatherView()
                .environment(settings)
                .environment(ScreenGeometry())
                .opacity(0.35)
                .allowsHitTesting(false)

            VStack(spacing: 0) {

                // MARK: Weather summary
                VStack(spacing: 8) {
                    Image(systemName: settings.weatherIcon)
                        .font(.system(size: 44))
                        .symbolRenderingMode(.multicolor)

                    Text(settings.temperatureText)
                        .font(.system(size: 34, weight: .light, design: .rounded))

                    Text(settings.weatherLabel)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

                Divider()
                    .padding(.vertical, 12)

                // MARK: Settings
                VStack(spacing: 16) {

                    // Weather type picker
                    Picker("Weather", selection: $settings.weatherType) {
                        Text("Snow").tag(WeatherType.snow)
                        Text("Rain").tag(WeatherType.rain)
                        Text("AI Storm").tag(WeatherType.aiStorm)
                    }
                    .pickerStyle(.segmented)

                    // Particle count
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(settings.flakeCount) \(settings.particleUnit)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.flakeCount) },
                            set: { settings.flakeCount = Int($0) }
                        ), in: 20...400, step: 10)
                    }

                    // Fall speed
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Speed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(speedLabelForType(settings.weatherType, settings.speedMultiplier))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.speedMultiplier, in: 0.25...3.0, step: 0.05)
                    }

                    // Wind strength
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Wind")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(windLabel(settings.windStrength))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.windStrength, in: 0.0...1.0, step: 0.05)
                    }

                    // Clouds toggle + size
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
                            Text("Translucent clouds drift across the top of the screen")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            HStack {
                                Text("Cloud Size")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.cloudSizeLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.cloudSize, in: 0.5...1.5, step: 0.1)
                        }
                    }

                    // Accumulation / Puddles toggle
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
                    }

                    // Lightning toggle (rain-only)
                    if settings.weatherType == .rain {
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
                                Text("Random bolts flash across the screen")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // Drift depth (snow-only, visible when accumulation is on)
                    if settings.weatherType == .snow && settings.accumulationEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Drift Depth")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(settings.driftDepthLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(settings.maxAccumulationHeight) },
                                set: { settings.maxAccumulationHeight = Int($0) }
                            ), in: 20...300, step: 10)
                        }
                    }

                    // Display selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Displays")
                            .font(.caption)
                            .foregroundStyle(.secondary)

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

                    // Re-randomise
                    Button {
                        settings.reroll()
                    } label: {
                        Label(settings.rerollLabel, systemImage: "shuffle")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)

                Divider()
                    .padding(.vertical, 12)

                // MARK: Quit
                Button("Quit wthrr") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .padding(.bottom, 8)

                Divider()
                    .padding(.vertical, 8)

                // MARK: About
                AboutView()
                    .padding(.bottom, 14)

            } // VStack
        } // ZStack
        .frame(width: 260)
        .onAppear {
            screens = NSScreen.screens
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            screens = NSScreen.screens
            applyDisplaySettings()
        }
    }

    // MARK: Helpers

    /// Forwards the current display selection to `OverlayWindowController` so
    /// overlay windows are added or removed to match the user's choice.
    private func applyDisplaySettings() {
        AppDelegate.shared?.overlayWindowController?.applySettings()
    }

    /// Returns the appropriate speed label for the given weather type and multiplier.
    private func speedLabelForType(_ type: WeatherType, _ v: Double) -> String {
        switch type {
        case .rain:    return rainSpeedLabel(v)
        case .aiStorm: return aiStormSpeedLabel(v)
        case .snow:    return speedLabel(v)
        }
    }

    /// Maps a speed multiplier value to a human-readable snow intensity label.
    private func speedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Gentle"
        case ..<1.0:  return "Light"
        case ..<1.5:  return "Normal"
        case ..<2.2:  return "Heavy"
        default:      return "Blizzard"
        }
    }

    /// Maps a speed multiplier to a rain-specific intensity label.
    private func rainSpeedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Mist"
        case ..<1.0:  return "Drizzle"
        case ..<1.5:  return "Shower"
        case ..<2.2:  return "Downpour"
        default:      return "Monsoon"
        }
    }

    /// Maps a speed multiplier to an AI storm intensity label.
    private func aiStormSpeedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Flicker"
        case ..<1.0:  return "Glitch"
        case ..<1.5:  return "Surge"
        case ..<2.2:  return "Overload"
        default:      return "Singularity"
        }
    }

    /// Maps a wind strength value to a human-readable label.
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

// MARK: - About view

/// Footer view showing the app version string and a tappable GitHub link.
struct AboutView: View {
    private let repoURL = URL(string: "https://github.com/todddube/wthrr_mac")!

    /// Reads the marketing version and build number from the app bundle at runtime.
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
                Text("by Todd Dube  ·")
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
