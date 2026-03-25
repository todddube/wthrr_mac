// HotkeyBinding.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import AppKit

// MARK: - Hotkey binding

/// A persistable representation of a keyboard shortcut (modifiers + key character).
struct HotkeyBinding: Codable, Equatable {
    /// Raw value of NSEvent.ModifierFlags (command, shift, option, control).
    var modifierRawValue: UInt
    /// The key character, ignoring modifiers (lowercased).
    var key: String

    /// The default pause hotkey: Cmd+Shift+P.
    static let `default` = HotkeyBinding(
        modifierRawValue: NSEvent.ModifierFlags([.command, .shift]).rawValue,
        key: "p"
    )

    /// Reconstructs the strongly-typed `NSEvent.ModifierFlags` value from the persisted raw value.
    /// The intersection with the four recognised modifiers strips any unexpected bits that could
    /// accumulate across OS versions.
    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue)
            .intersection([.command, .shift, .option, .control])
    }

    /// Returns true if the given event matches this hotkey binding.
    func matches(_ event: NSEvent) -> Bool {
        let eventMods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard eventMods == modifiers else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == key
    }

    /// Human-readable display string (e.g. "⌘⇧P").
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option)  { parts.append("\u{2325}") }
        if modifiers.contains(.shift)   { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }
        parts.append(key.uppercased())
        return parts.joined(separator: " ")
    }

    /// Creates a binding from an NSEvent captured during recording.
    static func from(event: NSEvent) -> HotkeyBinding? {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        // Require at least one modifier key
        guard !mods.isEmpty else { return nil }
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              !chars.isEmpty,
              chars.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            return nil
        }
        return HotkeyBinding(modifierRawValue: mods.rawValue, key: chars)
    }
}
