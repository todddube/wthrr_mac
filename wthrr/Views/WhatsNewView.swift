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
            ("aqi.medium", "Aurora Borealis — rippling color bands, no particles needed"),
            ("location.fill", "Live Weather — real conditions from Open-Meteo, auto-applied"),
            ("cpu", "AI Storm improvements — alien ships, fractures, 4 neon palettes"),
            ("rectangle.inset.filled", "Live preview strip in settings — see effects as you tune"),
            ("wind", "Environment section — Wind and Atmosphere unified"),
            ("shuffle", "Reroll button in header for instant randomization"),
            ("star.fill", "9 built-in presets with import/export support"),
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

                // Changelog entries
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 22, alignment: .center)

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

                Spacer()

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
        .frame(width: 380, height: 480)
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
