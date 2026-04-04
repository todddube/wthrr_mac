// WeatherSettings.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather type

/// Selects the active weather effect shown on overlay windows.
enum WeatherType: String, CaseIterable {
    case snow         = "snow"          // Snowflakes with optional drift accumulation
    case rain         = "rain"          // Raindrops with splashes and optional puddles
    case aiStorm      = "aiStorm"       // Digital glitch storm with neon particles and data bolts
    case thunderstorm = "thunderstorm"  // Composite: heavy rain + lightning + dark clouds + screen flash
    case fog          = "fog"           // Slow-drifting translucent gradient bands
    case aurora       = "aurora"        // Slow rippling vertical colour bands
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
@MainActor
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

    // MARK: Tuning knobs

    /// Snow melt rate per frame. Range: 0.02 (slow) – 0.2 (fast). Default 0.08.
    var snowMeltRate: Double {
        didSet { UserDefaults.standard.set(snowMeltRate, forKey: "snowMeltRate") }
    }

    /// AI Storm effect density multiplier. Scales spawn rates for bolts, patches, fractures.
    /// Range: 0.25 (sparse) – 3.0 (chaotic). Default 1.0.
    var aiStormDensity: Double {
        didSet { UserDefaults.standard.set(aiStormDensity, forKey: "aiStormDensity") }
    }

    /// Cloud opacity multiplier. Range: 0.3 (faint) – 2.0 (opaque). Default 1.0.
    var cloudOpacity: Double {
        didSet { UserDefaults.standard.set(cloudOpacity, forKey: "cloudOpacity") }
    }

    /// Wind angle in degrees from vertical. 0 = straight down, positive = tilted right.
    /// Range: -45 – 45. Default 0.
    var windAngle: Double {
        didSet { UserDefaults.standard.set(windAngle, forKey: "windAngle") }
    }

    /// When true, limits animation to ~30 fps to reduce CPU usage.
    var lowPowerMode: Bool {
        didSet { UserDefaults.standard.set(lowPowerMode, forKey: "lowPowerMode") }
    }

    /// When true, auto-reduces particle count when CPU is above `cpuThreshold`
    /// and drops to 30 fps when battery is below `batteryThreshold` on battery power.
    var adaptiveQualityEnabled: Bool {
        didSet { UserDefaults.standard.set(adaptiveQualityEnabled, forKey: "adaptiveQualityEnabled") }
    }

    /// CPU utilisation fraction (0.0–1.0) above which adaptive quality halves the particle count.
    /// Default 0.70 (70%).
    var cpuThreshold: Double {
        didSet { UserDefaults.standard.set(cpuThreshold, forKey: "cpuThreshold") }
    }

    /// Battery percentage at or below which adaptive quality drops to 30 fps (on battery only).
    /// Default 20.
    var batteryThreshold: Int {
        didSet { UserDefaults.standard.set(batteryThreshold, forKey: "batteryThreshold") }
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

    // MARK: Pause

    /// When true, all weather animations are frozen. Not persisted — always starts unpaused.
    var isPaused: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .weatherPauseChanged, object: nil)
        }
    }

    // MARK: Hotkey

    /// The user-configurable global hotkey for pause/resume. Persisted to UserDefaults.
    var pauseHotkey: HotkeyBinding {
        didSet {
            if let data = try? JSONEncoder().encode(pauseHotkey) {
                UserDefaults.standard.set(data, forKey: "pauseHotkey")
            }
            NotificationCenter.default.post(name: .hotkeyBindingChanged, object: nil)
        }
    }

    // MARK: Color theming

    /// Snow tint hue: 0.0 = pure white, through blue, purple, gold. Stored as hue value 0-1.
    /// Special value -1 means "default" (white/light blue).
    var snowTintHue: Double {
        didSet { UserDefaults.standard.set(snowTintHue, forKey: "snowTintHue") }
    }

    /// Rain streak hue: -1 = default blue, otherwise 0-1 hue value.
    var rainTintHue: Double {
        didSet { UserDefaults.standard.set(rainTintHue, forKey: "rainTintHue") }
    }

    /// AI Storm palette index: 0 = Cyberpunk (cyan/magenta), 1 = Synthwave (purple/pink),
    /// 2 = Matrix (green), 3 = Fire (orange/red).
    var aiStormPalette: Int {
        didSet { UserDefaults.standard.set(aiStormPalette, forKey: "aiStormPalette") }
    }

    /// Fog tint hue: -1 = default (white/gray), otherwise 0-1 hue value.
    var fogTintHue: Double {
        didSet { UserDefaults.standard.set(fogTintHue, forKey: "fogTintHue") }
    }

    // MARK: Seasonal / Time-of-Day

    /// When true, auto-switches weather type based on the calendar month.
    var seasonalEnabled: Bool {
        didSet { UserDefaults.standard.set(seasonalEnabled, forKey: "seasonalEnabled") }
    }

    /// When true, dims particle opacity at night based on the system clock.
    var timeDimmingEnabled: Bool {
        didSet { UserDefaults.standard.set(timeDimmingEnabled, forKey: "timeDimmingEnabled") }
    }

    /// Opacity multiplier based on time of day: 1.0 during day, dimmed at night.
    /// Recalculated on init and can be refreshed periodically.
    var timeDimFactor: Double = 1.0

    /// Applies the seasonal weather type for the current month.
    func applySeasonalWeather() {
        guard seasonalEnabled, !liveWeatherEnabled else { return }
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2:   weatherType = .snow          // Winter
        case 3, 4, 5:    weatherType = .rain           // Spring
        case 6, 7, 8:    weatherType = .thunderstorm   // Summer storms
        case 9, 10, 11:  weatherType = .fog            // Autumn fog
        default:         break
        }
    }

    /// Recalculates the time-of-day dim factor.
    func updateTimeDimming() {
        guard timeDimmingEnabled else { timeDimFactor = 1.0; return }
        let hour = Calendar.current.component(.hour, from: Date())
        // Night (10pm-5am): dim to 0.5, Dusk/Dawn (6-7am, 8-9pm): 0.75, Day: 1.0
        switch hour {
        case 22, 23, 0, 1, 2, 3, 4, 5: timeDimFactor = 0.5
        case 6, 7, 20, 21:              timeDimFactor = 0.75
        default:                         timeDimFactor = 1.0
        }
    }

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

        adaptiveQualityEnabled = UserDefaults.standard.object(forKey: "adaptiveQualityEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "adaptiveQualityEnabled")
            : true

        let savedCPUThreshold = UserDefaults.standard.double(forKey: "cpuThreshold")
        cpuThreshold = savedCPUThreshold > 0 ? savedCPUThreshold : 0.70

        let savedBattThreshold = UserDefaults.standard.integer(forKey: "batteryThreshold")
        batteryThreshold = savedBattThreshold > 0 ? savedBattThreshold : 20

        let savedMelt = UserDefaults.standard.double(forKey: "snowMeltRate")
        snowMeltRate = savedMelt > 0 ? savedMelt : 0.08

        let savedDensity = UserDefaults.standard.double(forKey: "aiStormDensity")
        aiStormDensity = savedDensity > 0 ? savedDensity : 1.0

        let savedCloudOpacity = UserDefaults.standard.double(forKey: "cloudOpacity")
        cloudOpacity = savedCloudOpacity > 0 ? savedCloudOpacity : 1.0

        windAngle = UserDefaults.standard.object(forKey: "windAngle") != nil
            ? UserDefaults.standard.double(forKey: "windAngle") : 0

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

        if let hotkeyData = UserDefaults.standard.data(forKey: "pauseHotkey"),
           let saved = try? JSONDecoder().decode(HotkeyBinding.self, from: hotkeyData) {
            pauseHotkey = saved
        } else {
            pauseHotkey = .default
        }

        snowTintHue = UserDefaults.standard.object(forKey: "snowTintHue") != nil
            ? UserDefaults.standard.double(forKey: "snowTintHue") : -1
        rainTintHue = UserDefaults.standard.object(forKey: "rainTintHue") != nil
            ? UserDefaults.standard.double(forKey: "rainTintHue") : -1
        aiStormPalette = UserDefaults.standard.object(forKey: "aiStormPalette") != nil
            ? UserDefaults.standard.integer(forKey: "aiStormPalette") : 0
        fogTintHue = UserDefaults.standard.object(forKey: "fogTintHue") != nil
            ? UserDefaults.standard.double(forKey: "fogTintHue") : -1

        seasonalEnabled = UserDefaults.standard.object(forKey: "seasonalEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "seasonalEnabled")
            : false

        timeDimmingEnabled = UserDefaults.standard.object(forKey: "timeDimmingEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "timeDimmingEnabled")
            : false

        updateTimeDimming()
        if seasonalEnabled { applySeasonalWeather() }
    }

    // MARK: Helpers

    /// Assigns a new random seed, causing the particle population to be fully
    /// regenerated with different sizes, positions, and motion characteristics.
    func reroll() {
        randomSeed = Int.random(in: 1...999_999)
    }

    /// Toggles pause state. Called by the pause button and global hotkey.
    func togglePause() {
        isPaused.toggle()
    }

    // MARK: Presets

    /// Applies a preset's settings, overwriting current values.
    /// Uses direct UserDefaults writes to batch the persistence into a single pass
    /// instead of triggering 12 individual didSet handlers.
    func apply(_ preset: WeatherPreset) {
        let ud = UserDefaults.standard
        ud.set(preset.weatherType.rawValue, forKey: "weatherType")
        ud.set(preset.flakeCount, forKey: "flakeCount")
        ud.set(preset.speedMultiplier, forKey: "speedMultiplier")
        ud.set(preset.windStrength, forKey: "windStrength")
        ud.set(preset.windDirection.rawValue, forKey: "windDirection")
        ud.set(preset.particleOpacity, forKey: "particleOpacity")
        ud.set(preset.accumulationEnabled, forKey: "accumulationEnabled")
        ud.set(preset.cloudsEnabled, forKey: "cloudsEnabled")
        ud.set(preset.lightningEnabled, forKey: "lightningEnabled")
        ud.set(preset.lightningFrequency, forKey: "lightningFrequency")
        ud.set(preset.cloudSize, forKey: "cloudSize")
        ud.set(preset.cloudSpeed, forKey: "cloudSpeed")

        // Update in-memory values (triggers @Observable change tracking once)
        weatherType = preset.weatherType
        flakeCount = preset.flakeCount
        speedMultiplier = preset.speedMultiplier
        windStrength = preset.windStrength
        windDirection = preset.windDirection
        particleOpacity = preset.particleOpacity
        accumulationEnabled = preset.accumulationEnabled
        cloudsEnabled = preset.cloudsEnabled
        lightningEnabled = preset.lightningEnabled
        lightningFrequency = preset.lightningFrequency
        cloudSize = preset.cloudSize
        cloudSpeed = preset.cloudSpeed
    }

    /// Snapshots current settings into a preset with the given name.
    func snapshot(named name: String) -> WeatherPreset {
        WeatherPreset(
            name: name,
            weatherType: weatherType,
            flakeCount: flakeCount,
            speedMultiplier: speedMultiplier,
            windStrength: windStrength,
            windDirection: windDirection,
            particleOpacity: particleOpacity,
            accumulationEnabled: accumulationEnabled,
            cloudsEnabled: cloudsEnabled,
            lightningEnabled: lightningEnabled,
            lightningFrequency: lightningFrequency,
            cloudSize: cloudSize,
            cloudSpeed: cloudSpeed
        )
    }

    // MARK: Weather-type display helpers

    /// SF Symbol name for the current weather type, used in the header and menu bar.
    var weatherIcon: String {
        switch weatherType {
        case .rain:         return "cloud.rain.fill"
        case .aiStorm:      return "bolt.trianglebadge.exclamationmark.fill"
        case .snow:         return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .fog:          return "cloud.fog.fill"
        case .aurora:       return "aqi.medium"
        }
    }

    /// Temperature string shown in the header.
    /// Returns the live-fetched value when live mode is on; falls back to decorative defaults.
    var temperatureText: String {
        if liveWeatherEnabled, let live = liveTemperatureText { return live }
        switch weatherType {
        case .rain:         return "52\u{00B0}F"
        case .aiStorm:      return "??\u{00B0}?"
        case .snow:         return "28\u{00B0}F"
        case .thunderstorm: return "45\u{00B0}F"
        case .fog:          return "55\u{00B0}F"
        case .aurora:       return "20\u{00B0}F"
        }
    }

    /// Human-readable name of the current weather type.
    var weatherLabel: String {
        switch weatherType {
        case .rain:         return "Rain"
        case .aiStorm:      return "AI Storm"
        case .snow:         return "Snow"
        case .thunderstorm: return "Thunderstorm"
        case .fog:          return "Fog"
        case .aurora:       return "Aurora"
        }
    }

    /// Unit name for a single particle ("flakes" for snow, "drops" for rain).
    var particleUnit: String {
        switch weatherType {
        case .rain:         return "drops"
        case .aiStorm:      return "glitches"
        case .snow:         return "flakes"
        case .thunderstorm: return "drops"
        case .fog:          return "wisps"
        case .aurora:       return "bands"
        }
    }

    /// Label for the accumulation toggle (context-aware per weather type).
    var accumulationLabel: String {
        switch weatherType {
        case .rain:         return "Puddles"
        case .aiStorm:      return "Corruption"
        case .snow:         return "Accumulation"
        case .thunderstorm: return "Puddles"
        case .fog:          return "Mist Pools"
        case .aurora:       return "Ground Glow"
        }
    }

    /// Description shown below the accumulation toggle when it is enabled.
    var accumulationDescription: String {
        switch weatherType {
        case .rain:         return "Puddles form and grow at the bottom of the screen"
        case .aiStorm:      return "Static patches corrupt regions of the screen"
        case .snow:         return "Flakes pile up and go around the Dock"
        case .thunderstorm: return "Puddles form and grow at the bottom of the screen"
        case .fog:          return "Mist settles at the bottom of the screen"
        case .aurora:       return "Soft glow pools at the bottom of the screen"
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
        case .rain:         return "Re-randomise Drops"
        case .aiStorm:      return "Re-randomise Glitches"
        case .snow:         return "Re-randomise Flakes"
        case .thunderstorm: return "Re-randomise Drops"
        case .fog:          return "Re-randomise Wisps"
        case .aurora:       return "Re-randomise Bands"
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
