// WeatherSettings.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather type

/// Selects the active weather effect shown on overlay windows.
enum WeatherType: String, CaseIterable {
    case snow    = "snow"      // Snowflakes with optional drift accumulation
    case rain    = "rain"      // Raindrops with splashes and optional puddles
    case aiStorm = "aiStorm"   // Digital glitch storm with neon particles and data bolts
}

// MARK: - Display mode

/// Determines which physical displays the weather overlay appears on.
enum DisplayMode: String, CaseIterable {
    case all      = "all"       // Show weather on every connected display
    case selected = "selected"  // Show weather only on user-chosen displays
}

// MARK: - Wind direction

/// Biases the wind to always blow in a fixed horizontal direction.
enum WindDirection: String, CaseIterable {
    case left    = "left"     // Wind always blows left
    case natural = "natural"  // Wind direction varies naturally
    case right   = "right"    // Wind always blows right
}

// MARK: - Weather settings

/// Observable singleton that holds all weather simulation settings.
/// Every property persists its value to UserDefaults via `didSet` so settings
/// survive app restarts. Shared via `.environment(WeatherSettings.shared)`.
@Observable
class WeatherSettings {
    /// Shared instance used by both the menu bar popover and the overlay windows.
    static let shared = WeatherSettings()

    // MARK: Weather type

    /// The currently active weather effect. Switching rebuilds the particle system.
    /// Posts `.weatherTypeChanged` so AppDelegate can sync the status item icon.
    var weatherType: WeatherType {
        didSet {
            UserDefaults.standard.set(weatherType.rawValue, forKey: "weatherType")
            NotificationCenter.default.post(name: .weatherTypeChanged, object: nil)
        }
    }

    // MARK: Particle physics

    /// Number of particles rendered per screen. Range: 20-400.
    var flakeCount: Int {
        didSet { UserDefaults.standard.set(flakeCount, forKey: "flakeCount") }
    }

    /// Multiplier applied to all particle fall speeds. Range: 0.25 (very slow) - 3.0 (blizzard).
    var speedMultiplier: Double {
        didSet { UserDefaults.standard.set(speedMultiplier, forKey: "speedMultiplier") }
    }

    /// Seed that drives per-particle randomness via SeededRNG. Changing this value
    /// causes the entire particle population to be re-generated with new positions,
    /// sizes, speeds, and wobble characteristics.
    var randomSeed: Int {
        didSet { UserDefaults.standard.set(randomSeed, forKey: "randomSeed") }
    }

    /// Maximum wind strength. 0 = dead calm, 1 = full gale.
    /// Controls both peak gust speed (15-140 pts/s) and gust interval frequency.
    var windStrength: Double {
        didSet { UserDefaults.standard.set(windStrength, forKey: "windStrength") }
    }

    /// Biases wind to blow in a fixed direction. Natural lets the simulation vary freely.
    var windDirection: WindDirection {
        didSet { UserDefaults.standard.set(windDirection.rawValue, forKey: "windDirection") }
    }

    /// When true, snow accumulates at the screen bottom or rain forms puddles.
    var accumulationEnabled: Bool {
        didSet { UserDefaults.standard.set(accumulationEnabled, forKey: "accumulationEnabled") }
    }

    /// Maximum height the snow drift can reach before melt kicks in, in points.
    /// Range: 20 (light dusting) - 300 (deep snow). Default 120.
    var maxAccumulationHeight: Int {
        didSet { UserDefaults.standard.set(maxAccumulationHeight, forKey: "maxAccumulationHeight") }
    }

    /// When true, random lightning bolts flash across the screen during rain mode.
    /// Has no effect in snow mode.
    var lightningEnabled: Bool {
        didSet { UserDefaults.standard.set(lightningEnabled, forKey: "lightningEnabled") }
    }

    /// How often lightning strikes relative to the default 8–25 s interval.
    /// Range: 0.25 (rare) – 3.0 (frequent). Default 1.0.
    var lightningFrequency: Double {
        didSet { UserDefaults.standard.set(lightningFrequency, forKey: "lightningFrequency") }
    }

    /// Global opacity multiplier applied to all particles. Range: 0.2 (ghost) – 1.5 (vivid).
    var particleOpacity: Double {
        didSet { UserDefaults.standard.set(particleOpacity, forKey: "particleOpacity") }
    }

    /// When true, limits animation to ~30 fps to reduce CPU usage.
    var lowPowerMode: Bool {
        didSet { UserDefaults.standard.set(lowPowerMode, forKey: "lowPowerMode") }
    }

    // MARK: Live weather

    /// When true, Open-Meteo pulls real conditions and auto-applies weather type + intensity.
    /// Manual controls are disabled while this is active.
    var liveWeatherEnabled: Bool {
        didSet { UserDefaults.standard.set(liveWeatherEnabled, forKey: "liveWeatherEnabled") }
    }

    /// Real temperature string set by LiveWeatherService after each fetch.
    /// Not persisted — re-fetched on next launch if live mode is on.
    var liveTemperatureText: String?

    // MARK: Clouds

    /// When true, translucent clouds drift across the top of the screen.
    var cloudsEnabled: Bool {
        didSet { UserDefaults.standard.set(cloudsEnabled, forKey: "cloudsEnabled") }
    }

    /// Multiplier for cloud size. Range: 0.5 (small) - 1.5 (large, capped internally).
    var cloudSize: Double {
        didSet { UserDefaults.standard.set(cloudSize, forKey: "cloudSize") }
    }

    /// Multiplier for cloud drift speed. Range: 0.25 (glacial) – 3.0 (stormy). Default 1.0.
    var cloudSpeed: Double {
        didSet { UserDefaults.standard.set(cloudSpeed, forKey: "cloudSpeed") }
    }

    // MARK: Display selection

    /// Whether to show weather on all displays or only the manually selected ones.
    var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    /// CGDirectDisplayIDs (stored as strings) of screens that should show weather
    /// when `displayMode == .selected`.
    var selectedDisplayIDs: Set<String> {
        didSet {
            let arr = Array(selectedDisplayIDs)
            UserDefaults.standard.set(arr, forKey: "selectedDisplayIDs")
        }
    }

    // MARK: Init

    /// Loads all settings from UserDefaults, falling back to sensible defaults
    /// if a key has never been written (first launch).
    init() {
        let savedWeatherTypeRaw = UserDefaults.standard.string(forKey: "weatherType") ?? ""
        weatherType = WeatherType(rawValue: savedWeatherTypeRaw) ?? .snow

        let savedCount = UserDefaults.standard.integer(forKey: "flakeCount")
        flakeCount = savedCount > 0 ? savedCount : 180

        let savedSpeed = UserDefaults.standard.double(forKey: "speedMultiplier")
        speedMultiplier = savedSpeed > 0 ? savedSpeed : 1.0

        let savedSeed = UserDefaults.standard.integer(forKey: "randomSeed")
        randomSeed = savedSeed > 0 ? savedSeed : 42

        let savedWind = UserDefaults.standard.double(forKey: "windStrength")
        // UserDefaults returns 0.0 for a missing key, so treat 0 as "not set" -> default 0.5
        windStrength = UserDefaults.standard.object(forKey: "windStrength") != nil ? savedWind : 0.5

        let savedWindDir = UserDefaults.standard.string(forKey: "windDirection") ?? ""
        windDirection = WindDirection(rawValue: savedWindDir) ?? .natural

        accumulationEnabled = UserDefaults.standard.object(forKey: "accumulationEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "accumulationEnabled")
            : false

        let savedMaxH = UserDefaults.standard.integer(forKey: "maxAccumulationHeight")
        maxAccumulationHeight = savedMaxH > 0 ? savedMaxH : 120

        lightningEnabled = UserDefaults.standard.object(forKey: "lightningEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "lightningEnabled")
            : false

        let savedLightFreq = UserDefaults.standard.double(forKey: "lightningFrequency")
        lightningFrequency = savedLightFreq > 0 ? savedLightFreq : 1.0

        let savedOpacity = UserDefaults.standard.double(forKey: "particleOpacity")
        particleOpacity = savedOpacity > 0 ? savedOpacity : 1.0

        lowPowerMode = UserDefaults.standard.object(forKey: "lowPowerMode") != nil
            ? UserDefaults.standard.bool(forKey: "lowPowerMode")
            : false

        liveWeatherEnabled = UserDefaults.standard.object(forKey: "liveWeatherEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "liveWeatherEnabled")
            : false

        cloudsEnabled = UserDefaults.standard.object(forKey: "cloudsEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "cloudsEnabled")
            : false

        let savedCloudSize = UserDefaults.standard.double(forKey: "cloudSize")
        cloudSize = savedCloudSize > 0 ? savedCloudSize : 1.0

        let savedCloudSpeed = UserDefaults.standard.double(forKey: "cloudSpeed")
        cloudSpeed = savedCloudSpeed > 0 ? savedCloudSpeed : 1.0

        let savedMode = UserDefaults.standard.string(forKey: "displayMode") ?? ""
        displayMode = DisplayMode(rawValue: savedMode) ?? .all

        let savedIDs = UserDefaults.standard.stringArray(forKey: "selectedDisplayIDs") ?? []
        selectedDisplayIDs = Set(savedIDs)
    }

    // MARK: Helpers

    /// Assigns a new random seed, causing the particle population to be fully
    /// regenerated with different sizes, positions, and motion characteristics.
    func reroll() {
        randomSeed = Int.random(in: 1...999_999)
    }

    // MARK: Weather-type display helpers

    /// SF Symbol name for the current weather type, used in the header and menu bar.
    var weatherIcon: String {
        switch weatherType {
        case .rain:    return "cloud.rain.fill"
        case .aiStorm: return "bolt.trianglebadge.exclamationmark.fill"
        case .snow:    return "cloud.snow.fill"
        }
    }

    /// Temperature string shown in the header.
    /// Returns the live-fetched value when live mode is on; falls back to decorative defaults.
    var temperatureText: String {
        if liveWeatherEnabled, let live = liveTemperatureText { return live }
        switch weatherType {
        case .rain:    return "52\u{00B0}F"
        case .aiStorm: return "??\u{00B0}?"
        case .snow:    return "28\u{00B0}F"
        }
    }

    /// Human-readable name of the current weather type.
    var weatherLabel: String {
        switch weatherType {
        case .rain:    return "Rain"
        case .aiStorm: return "AI Storm"
        case .snow:    return "Snow"
        }
    }

    /// Unit name for a single particle ("flakes" for snow, "drops" for rain).
    var particleUnit: String {
        switch weatherType {
        case .rain:    return "drops"
        case .aiStorm: return "glitches"
        case .snow:    return "flakes"
        }
    }

    /// Label for the accumulation toggle (context-aware per weather type).
    var accumulationLabel: String {
        switch weatherType {
        case .rain:    return "Puddles"
        case .aiStorm: return "Corruption"
        case .snow:    return "Accumulation"
        }
    }

    /// Description shown below the accumulation toggle when it is enabled.
    var accumulationDescription: String {
        switch weatherType {
        case .rain:    return "Puddles form and grow at the bottom of the screen"
        case .aiStorm: return "Static patches corrupt regions of the screen"
        case .snow:    return "Flakes pile up and go around the Dock"
        }
    }

    /// Human-readable label for the current accumulation depth setting.
    var driftDepthLabel: String {
        switch maxAccumulationHeight {
        case ..<50:   return "Dusting"
        case ..<100:  return "Light"
        case ..<160:  return "Normal"
        case ..<230:  return "Deep"
        default:      return "Blizzard"
        }
    }

    /// Label for the re-randomise button (context-aware per weather type).
    var rerollLabel: String {
        switch weatherType {
        case .rain:    return "Re-randomise Drops"
        case .aiStorm: return "Re-randomise Glitches"
        case .snow:    return "Re-randomise Flakes"
        }
    }

    /// Human-readable label for the current cloud speed setting.
    var cloudSpeedLabel: String {
        switch cloudSpeed {
        case ..<0.6:  return "Glacial"
        case ..<1.2:  return "Drifting"
        case ..<2.0:  return "Breezy"
        default:      return "Stormy"
        }
    }

    /// Human-readable label for the current lightning frequency setting.
    var lightningFrequencyLabel: String {
        switch lightningFrequency {
        case ..<0.6:  return "Rare"
        case ..<1.4:  return "Occasional"
        case ..<2.2:  return "Frequent"
        default:      return "Storm"
        }
    }

    /// Human-readable label for the current particle opacity setting.
    var particleOpacityLabel: String {
        switch particleOpacity {
        case ..<0.45: return "Ghost"
        case ..<0.85: return "Faint"
        case ..<1.15: return "Normal"
        case ..<1.35: return "Bold"
        default:      return "Vivid"
        }
    }

    /// Human-readable label for the current cloud size setting.
    var cloudSizeLabel: String {
        switch cloudSize {
        case ..<0.7:  return "Small"
        case ..<1.1:  return "Medium"
        default:      return "Large"
        }
    }

    /// Returns `true` if weather should be rendered on the given screen based on
    /// the current `displayMode` and `selectedDisplayIDs`.
    func isEnabled(for screen: NSScreen) -> Bool {
        switch displayMode {
        case .all:
            return true
        case .selected:
            return selectedDisplayIDs.contains(screen.displayID)
        }
    }

    /// Toggles the given screen in or out of `selectedDisplayIDs`.
    func toggleDisplay(_ screen: NSScreen) {
        let id = screen.displayID
        if selectedDisplayIDs.contains(id) {
            selectedDisplayIDs.remove(id)
        } else {
            selectedDisplayIDs.insert(id)
        }
    }
}

// MARK: - NSScreen convenience

extension NSScreen {
    /// The screen's stable CGDirectDisplayID expressed as a String,
    /// suitable for persisting to UserDefaults. Falls back to `localizedName`
    /// if the display ID cannot be read from the device description dictionary.
    var displayID: String {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return localizedName
        }
        return String(id)
    }
}
