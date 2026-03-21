// WhatsNewView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - What's New view

/// A lightweight changelog overlay shown once after an app update.
/// Version-gated by CFBundleVersion — only shows when the build number changes.
struct WhatsNewView: View {
    var onDismiss: () -> Void

    @State private var appeared = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Changelog entries for the current version.
    /// Update this array each release.
    private var entries: [(icon: String, text: String)] {
        [
            // Weather modes
            ("aqi.medium",            "Aurora Borealis — rippling color bands across all your displays"),
            ("cloud.bolt.rain.fill",  "Thunderstorm — dark clouds, heavy rain, and forced lightning"),
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
        ]
    }

    var body: some View {
        ZStack {
            // Blurred dark background
            Color.black.opacity(0.7)

            VStack(spacing: 0) {
                Spacer().frame(height: 28)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                    Text("What's New")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("v\(appVersion)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 20)

                // Changelog entries — scrollable so they always fit
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: entry.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .frame(width: 22, alignment: .center)
                                    .padding(.top, 1)

                                Text(entry.text)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -15)
                            .animation(.easeOut(duration: 0.35).delay(0.2 + Double(index) * 0.06), value: appeared)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
                }

                Spacer().frame(height: 16)

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule().fill(.white.opacity(0.2))
                                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
            }
        }
        .frame(width: 380, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
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
