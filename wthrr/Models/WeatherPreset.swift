// WeatherPreset.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Weather preset

/// A named snapshot of weather settings that can be saved, loaded, and shared.
struct WeatherPreset: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let weatherType: WeatherType
    let flakeCount: Int
    let speedMultiplier: Double
    let windStrength: Double
    let windDirection: WindDirection
    let particleOpacity: Double
    let accumulationEnabled: Bool
    let cloudsEnabled: Bool
    let lightningEnabled: Bool
    let lightningFrequency: Double
    let cloudSize: Double
    let cloudSpeed: Double

    /// Whether this is a built-in preset (cannot be deleted).
    var isBuiltIn: Bool { Self.builtInNames.contains(name) }

    private static let builtInNames: Set<String> = [
        "Blizzard", "Light Flurry", "Spring Rain", "Monsoon", "Thunderstorm", "Foggy Morning", "Glitch Overload", "Digital Ghost", "Aurora Borealis"
    ]
}

// MARK: - Codable conformance for enums used in presets

extension WeatherType: Codable {}
extension WindDirection: Codable {}

// MARK: - Built-in presets

/// Built-in preset definitions. These are read-only (cannot be deleted) and are always
/// shown first in the presets list ahead of user-saved presets.
extension WeatherPreset {
    /// Heavy snowstorm with blizzard-speed wind and deep accumulation.
    static let blizzard = WeatherPreset(
        name: "Blizzard",
        weatherType: .snow,
        flakeCount: 380,
        speedMultiplier: 2.5,
        windStrength: 0.85,
        windDirection: .natural,
        particleOpacity: 1.2,
        accumulationEnabled: true,
        cloudsEnabled: true,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.3,
        cloudSpeed: 2.5
    )

    /// Gentle, sparse snowfall with low wind and no accumulation.
    static let lightFlurry = WeatherPreset(
        name: "Light Flurry",
        weatherType: .snow,
        flakeCount: 60,
        speedMultiplier: 0.5,
        windStrength: 0.15,
        windDirection: .natural,
        particleOpacity: 0.7,
        accumulationEnabled: false,
        cloudsEnabled: false,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 0.5
    )

    /// Moderate rain with puddles and light cloud cover.
    static let springRain = WeatherPreset(
        name: "Spring Rain",
        weatherType: .rain,
        flakeCount: 150,
        speedMultiplier: 1.0,
        windStrength: 0.2,
        windDirection: .natural,
        particleOpacity: 0.8,
        accumulationEnabled: true,
        cloudsEnabled: true,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 0.8
    )

    /// Extreme rain with high wind, frequent lightning, and heavy puddle formation.
    static let monsoon = WeatherPreset(
        name: "Monsoon",
        weatherType: .rain,
        flakeCount: 400,
        speedMultiplier: 2.8,
        windStrength: 0.9,
        windDirection: .natural,
        particleOpacity: 1.3,
        accumulationEnabled: true,
        cloudsEnabled: true,
        lightningEnabled: true,
        lightningFrequency: 2.5,
        cloudSize: 1.4,
        cloudSpeed: 2.8
    )

    /// Full thunderstorm: dark clouds, heavy rain, forced lightning, and puddles.
    static let thunderstorm = WeatherPreset(
        name: "Thunderstorm",
        weatherType: .thunderstorm,
        flakeCount: 350,
        speedMultiplier: 2.5,
        windStrength: 0.85,
        windDirection: .natural,
        particleOpacity: 1.1,
        accumulationEnabled: true,
        cloudsEnabled: true,
        lightningEnabled: true,
        lightningFrequency: 2.2,
        cloudSize: 1.4,
        cloudSpeed: 2.5
    )

    /// Calm, low-speed fog with minimal wind — ideal for early morning ambience.
    static let foggyMorning = WeatherPreset(
        name: "Foggy Morning",
        weatherType: .fog,
        flakeCount: 40,
        speedMultiplier: 0.4,
        windStrength: 0.1,
        windDirection: .natural,
        particleOpacity: 0.8,
        accumulationEnabled: false,
        cloudsEnabled: false,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 0.5
    )

    /// Dense, fast AI storm with corruption patches enabled — maximum chaos.
    static let glitchOverload = WeatherPreset(
        name: "Glitch Overload",
        weatherType: .aiStorm,
        flakeCount: 350,
        speedMultiplier: 2.2,
        windStrength: 0.7,
        windDirection: .natural,
        particleOpacity: 1.4,
        accumulationEnabled: true,
        cloudsEnabled: false,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 1.0
    )

    /// Barely-visible AI storm at very low opacity — a subtle digital haunting.
    static let digitalGhost = WeatherPreset(
        name: "Digital Ghost",
        weatherType: .aiStorm,
        flakeCount: 40,
        speedMultiplier: 0.4,
        windStrength: 0.1,
        windDirection: .natural,
        particleOpacity: 0.35,
        accumulationEnabled: false,
        cloudsEnabled: false,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 1.0
    )

    /// Slow, translucent aurora bands at low opacity — calm and hypnotic.
    static let auroraBorealis = WeatherPreset(
        name: "Aurora Borealis",
        weatherType: .aurora,
        flakeCount: 20,
        speedMultiplier: 0.3,
        windStrength: 0.05,
        windDirection: .natural,
        particleOpacity: 0.6,
        accumulationEnabled: false,
        cloudsEnabled: false,
        lightningEnabled: false,
        lightningFrequency: 1.0,
        cloudSize: 1.0,
        cloudSpeed: 0.5
    )

    /// All built-in presets.
    static let builtIns: [WeatherPreset] = [
        .blizzard, .lightFlurry, .springRain, .monsoon, .thunderstorm, .foggyMorning, .glitchOverload, .digitalGhost, .auroraBorealis
    ]
}

// MARK: - Preset store

/// Manages user-saved presets, persisted to UserDefaults as JSON.
@Observable
@MainActor
final class PresetStore {
    static let shared = PresetStore()

    private(set) var userPresets: [WeatherPreset] = []

    /// All presets: built-in first, then user-saved.
    var allPresets: [WeatherPreset] {
        WeatherPreset.builtIns + userPresets
    }

    private let storageKey = "wthrr.userPresets"

    init() {
        loadFromDefaults()
    }

    /// Saves a new user preset. If a preset with the same name exists, it is replaced.
    func save(_ preset: WeatherPreset) {
        userPresets.removeAll { $0.name == preset.name }
        userPresets.append(preset)
        persist()
    }

    /// Deletes a user preset by name. Built-in presets cannot be deleted.
    func delete(named name: String) {
        userPresets.removeAll { $0.name == name }
        persist()
    }

    /// Encodes `userPresets` to JSON and writes it to `UserDefaults` under `storageKey`.
    /// Called after every mutation to keep persisted state in sync with in-memory state.
    private func persist() {
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Reads and decodes the JSON preset array from `UserDefaults`.
    /// Silently no-ops if the key is missing (first launch) or the data is unreadable.
    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let presets = try? JSONDecoder().decode([WeatherPreset].self, from: data) else { return }
        userPresets = presets
    }

    // MARK: JSON export/import

    /// Exports all user presets as a pretty-printed JSON file via a save panel.
    func exportPresets() {
        guard !userPresets.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export Presets"
        panel.nameFieldStringValue = "wthrr-presets.json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(userPresets) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Imports presets from a JSON file via an open panel. Merges with existing presets.
    func importPresets() {
        let panel = NSOpenPanel()
        panel.title = "Import Presets"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        guard let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder().decode([WeatherPreset].self, from: data) else { return }

        for preset in imported where !preset.isBuiltIn {
            userPresets.removeAll { $0.name == preset.name }
            userPresets.append(preset)
        }
        persist()
    }
}
