import SwiftUI

/// Which displays should show snow.
enum DisplayMode: String, CaseIterable {
    case all      = "all"
    case selected = "selected"
}

/// Persisted snow simulation settings shared across the whole app.
@Observable
class SnowSettings {
    /// Shared instance used by both the menu bar popover and the overlay windows.
    static let shared = SnowSettings()

    // MARK: - Snow physics

    /// Number of snowflakes per screen. Range: 20–400.
    var flakeCount: Int {
        didSet { UserDefaults.standard.set(flakeCount, forKey: "flakeCount") }
    }

    /// Multiplier on all fall speeds. Range: 0.25 (very slow) – 3.0 (blizzard).
    var speedMultiplier: Double {
        didSet { UserDefaults.standard.set(speedMultiplier, forKey: "speedMultiplier") }
    }

    /// Seed that drives per-flake randomness. Changing this re-randomises everything.
    var randomSeed: Int {
        didSet { UserDefaults.standard.set(randomSeed, forKey: "randomSeed") }
    }

    /// Maximum wind strength. 0 = dead calm, 1 = full gale.
    /// Controls both how hard gusts blow and how frequently they change direction.
    var windStrength: Double {
        didSet { UserDefaults.standard.set(windStrength, forKey: "windStrength") }
    }

    // MARK: - Display selection

    /// Whether to show snow on all displays or only the selected ones.
    var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    /// CGDirectDisplayIDs (as strings) of the screens that should show snow
    /// when displayMode == .selected.
    var selectedDisplayIDs: Set<String> {
        didSet {
            let arr = Array(selectedDisplayIDs)
            UserDefaults.standard.set(arr, forKey: "selectedDisplayIDs")
        }
    }

    // MARK: - Init

    init() {
        let savedCount = UserDefaults.standard.integer(forKey: "flakeCount")
        flakeCount = savedCount > 0 ? savedCount : 180

        let savedSpeed = UserDefaults.standard.double(forKey: "speedMultiplier")
        speedMultiplier = savedSpeed > 0 ? savedSpeed : 1.0

        let savedSeed = UserDefaults.standard.integer(forKey: "randomSeed")
        randomSeed = savedSeed > 0 ? savedSeed : 42

        let savedWind = UserDefaults.standard.double(forKey: "windStrength")
        // UserDefaults returns 0.0 for a missing key, so treat 0 as "not set" → default 0.5
        windStrength = UserDefaults.standard.object(forKey: "windStrength") != nil ? savedWind : 0.5

        let savedMode = UserDefaults.standard.string(forKey: "displayMode") ?? ""
        displayMode = DisplayMode(rawValue: savedMode) ?? .all

        let savedIDs = UserDefaults.standard.stringArray(forKey: "selectedDisplayIDs") ?? []
        selectedDisplayIDs = Set(savedIDs)
    }

    // MARK: - Helpers

    func reroll() {
        randomSeed = Int.random(in: 1...999_999)
    }

    /// Returns true if snow should be shown on the given screen.
    func isEnabled(for screen: NSScreen) -> Bool {
        switch displayMode {
        case .all:
            return true
        case .selected:
            return selectedDisplayIDs.contains(screen.displayID)
        }
    }

    /// Toggle a specific screen's selection on/off.
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
    /// Stable CGDirectDisplayID as a String — persisted to UserDefaults.
    var displayID: String {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return localizedName   // fallback
        }
        return String(id)
    }
}
