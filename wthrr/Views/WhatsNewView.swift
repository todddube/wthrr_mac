// WhatsNewView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - What's New view

/// A lightweight changelog overlay shown once after an app update.
/// Version-gated by `CFBundleVersion` — only shows when the build number changes since the last
/// launch. The `shouldShow` / `markAsSeen` static helpers manage the gating logic.
struct WhatsNewView: View {
    /// Called by the dismiss button and by `AppDelegate` after marking the version as seen.
    var onDismiss: () -> Void

    /// Controls the fade/slide-in animation for all entries.
    @State private var appeared = false

    /// The user-visible version string (e.g. "1.2.0"), read from the Info.plist at runtime.
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Changelog entries for the current version.
    /// Each entry is an (icon, text) pair shown as an SF Symbol + description row.
    /// Update this array each release.
    private var entries: [(icon: String, text: String)] {
        [
            // New in this build
            ("bird",                  "Aurora birds — animated silhouette birds drift across the aurora sky, flapping in sync with the light"),
            ("slider.horizontal.3",   "Bird controls — tune Bird Count, Bird Size, and Wildness per-bird variation right from Appearance settings"),
            ("switch.2",              "Settings weather picker — switch weather type directly from the settings window; controls update instantly"),

            // Weather modes
            ("aqi.medium",            "Aurora Borealis — rippling color bands across all your displays"),
            ("cloud.fog.fill",        "Fog — slow drifting translucent bands and soft wisp particles"),
            ("cpu",                   "AI Storm — alien ships, screen fractures, data bolts, and 4 neon palettes"),

            // Live data
            ("location.fill",         "Live Weather — pulls real conditions from Open-Meteo and auto-applies effect + intensity"),

            // Controls & UI
            ("rectangle.inset.filled","Live 64px preview strip — see every change in real time as you tune"),
            ("wind",                  "Environment section — Wind and Atmosphere controls unified in one place"),
            ("shuffle",               "Reroll button — instantly randomize a fresh look from the header"),
            ("bolt.fill",             "Intensity quick-taps — Light, Medium, Heavy set everything at once"),

            // Presets & customization
            ("star.fill",             "9 built-in presets — Blizzard, Monsoon, Aurora, Glitch Overload, and more"),
            ("square.and.arrow.up",   "Preset import/export — share your custom setups as JSON"),
            ("paintpalette.fill",     "Color theming — hue slider for Snow, Rain, and Fog; palette swap for AI Storm"),

            // Display & behavior
            ("display.2",             "Multi-display support — overlays span all connected monitors independently"),
            ("moon.stars.fill",       "Night dimming — subtly fades effects between 10pm and 5am"),
            ("calendar",              "Seasonal auto-switch — Snow in winter, Rain in spring, and so on"),
            ("tortoise.fill",         "Low Power Mode — caps animation to ~30 fps to save energy"),

            // App
            ("keyboard",              "Global hotkey — pause and resume from anywhere, fully customizable"),
            ("sparkles",              "Onboarding walkthrough — pick your weather and intensity on first launch"),
            ("arrow.up.right.circle.fill", "Launch at Login — start wthrr automatically when you log in"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
                    .padding(.top, 28)

                Text("What's New")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Version \(appVersion)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 28)

            // Changelog entries
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22, alignment: .center)
                                .padding(.top, 1)

                            Text(entry.text)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -12)
                        .animation(.easeOut(duration: 0.3).delay(0.15 + Double(index) * 0.04), value: appeared)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .frame(maxHeight: 380)

            Divider()
                .padding(.horizontal, 28)

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Text("Continue")
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
            .padding(.vertical, 16)
            .opacity(appeared ? 1 : 0)
        }
        .frame(width: 440)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    // MARK: - Version gating

    /// Returns true if the "What's New" screen should show (build number changed since last seen).
    static var shouldShow: Bool {
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let lastSeenBuild = UserDefaults.standard.string(forKey: "lastSeenWhatsNewBuild") ?? "0"
        return currentBuild != lastSeenBuild
    }

    /// Marks the current build as seen so "What's New" won't show again until next update.
    static func markAsSeen() {
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        UserDefaults.standard.set(currentBuild, forKey: "lastSeenWhatsNewBuild")
    }
}
