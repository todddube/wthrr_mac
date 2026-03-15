// WeatherSettings.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather type

/// Selects the active weather effect shown on overlay windows.
enum WeatherType: String, CaseIterable {
    case snow = "snow"   // Snowflakes with optional drift accumulation
    case rain = "rain"   // Raindrops with splashes and optional puddles
}

// MARK: - Display mode

/// Determines which physical displays the weather overlay appears on.
enum DisplayMode: String, CaseIterable {
    case all      = "all"       // Show weather on every connected display
    case selected = "selected"  // Show weather only on user-chosen displays
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

    /// When true, snow accumulates at the screen bottom or rain forms puddles.
    var accumulationEnabled: Bool {
        didSet { UserDefaults.standard.set(accumulationEnabled, forKey: "accumulationEnabled") }
    }

    /// Maximum height the snow drift can reach before melt kicks in, in points.
    /// Range: 20 (light dusting) - 300 (deep snow). Default 120.
    var maxAccumulationHeight: Int {
        didSet { UserDefaults.standard.set(maxAccumulationHeight, forKey: "maxAccumulationHeight") }
    }

    /// When true the overlay windows are raised above the Dock so weather effects
    /// appear on top of it. When false (default) the overlay sits below the Dock.
    var showOverDock: Bool {
        didSet { UserDefaults.standard.set(showOverDock, forKey: "showOverDock") }
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

        accumulationEnabled = UserDefaults.standard.object(forKey: "accumulationEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "accumulationEnabled")
            : false

        let savedMaxH = UserDefaults.standard.integer(forKey: "maxAccumulationHeight")
        maxAccumulationHeight = savedMaxH > 0 ? savedMaxH : 120

        showOverDock = UserDefaults.standard.object(forKey: "showOverDock") != nil
            ? UserDefaults.standard.bool(forKey: "showOverDock")
            : false

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
        weatherType == .rain ? "cloud.rain.fill" : "cloud.snow.fill"
    }

    /// Temperature string appropriate for the current weather type.
    var temperatureText: String {
        weatherType == .rain ? "52\u{00B0}F" : "28\u{00B0}F"
    }

    /// Human-readable name of the current weather type.
    var weatherLabel: String {
        weatherType == .rain ? "Rain" : "Snow"
    }

    /// Unit name for a single particle ("flakes" for snow, "drops" for rain).
    var particleUnit: String {
        weatherType == .rain ? "drops" : "flakes"
    }

    /// Label for the accumulation toggle (context-aware per weather type).
    var accumulationLabel: String {
        weatherType == .rain ? "Puddles" : "Accumulation"
    }

    /// Description shown below the accumulation toggle when it is enabled.
    var accumulationDescription: String {
        weatherType == .rain
            ? "Puddles form and grow at the bottom of the screen"
            : "Flakes pile up and go around the Dock"
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
        weatherType == .rain ? "Re-randomise Drops" : "Re-randomise Flakes"
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
