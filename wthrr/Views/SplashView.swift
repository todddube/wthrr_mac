// SplashView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Splash screen

/// A startup splash screen that displays the app name, version, author,
/// core feature highlights, and a live weather animation background.
/// Dismisses automatically after 20 seconds or when the user clicks the close button.
struct SplashView: View {
    @Environment(WeatherSettings.self) private var settings

    /// Called when the splash should close (timer or user action).
    var onDismiss: () -> Void

    /// Countdown seconds remaining before auto-dismiss.
    /// Countdown displayed in the "Close" button label. Decrements every second via `.task`.
    @State private var secondsRemaining: Int = 8
    /// Controls the fade/slide entrance animation for header and feature rows.
    @State private var appeared = false
    /// Whether the "What's New" sheet is currently presented over the splash.
    @State private var showingWhatsNew = false

    /// The user-visible version string read from Info.plist (e.g. "v1.2.0").
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(version)"
    }

    /// The monotonically-increasing build number from Info.plist (e.g. "42").
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Feature bullet points shown on the splash, adapted to highlight the active weather type's
    /// key capabilities so returning users see relevant information on every launch.
    private var features: [(icon: String, text: String)] {
        switch settings.weatherType {
        case .rain:
            return [
                ("cloud.rain.fill", "Wind-angled rain streaks"),
                ("drop.fill", "Impact splashes & puddles"),
                ("wind", "Dynamic gusting wind"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        case .aiStorm:
            return [
                ("bolt.fill", "Neon glitch particles"),
                ("cpu", "Circuit-trace data bolts"),
                ("barcode", "Scan line distortion"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        case .thunderstorm:
            return [
                ("cloud.bolt.rain.fill", "Heavy rain with lightning"),
                ("bolt.fill", "Continuous thunder strikes"),
                ("cloud.fill", "Dark storm clouds"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        case .fog:
            return [
                ("cloud.fog.fill", "Drifting fog bands"),
                ("circle.dotted", "Translucent wisp particles"),
                ("wind", "Gentle horizontal drift"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        case .snow:
            return [
                ("snowflake", "Three crystal shapes"),
                ("mountain.2.fill", "Snow drift accumulation"),
                ("wind", "Dynamic gusting wind"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        case .aurora:
            return [
                ("aqi.medium", "Rippling aurora bands"),
                ("paintpalette.fill", "Green, purple & teal"),
                ("sparkles", "Mesmerizing slow animation"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // App icon & name
            VStack(spacing: 6) {
                Image(systemName: settings.weatherIcon)
                    .font(.system(size: 48))
                    .symbolRenderingMode(.multicolor)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .padding(.top, 28)

                Text("wthrr")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Decorative Weather for macOS")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -10)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 28)

            // Feature list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22, alignment: .center)

                            Text(feature.text)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -20)
                        .animation(.easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.08), value: appeared)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }

            Divider()
                .padding(.horizontal, 28)

            // Author & version
            VStack(spacing: 6) {
                Text("by Todd Dube")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Link("thedubes.com", destination: URL(string: "https://www.thedubes.com")!)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    VersionBadge(label: "Version", value: appVersion)
                    VersionBadge(label: "Build", value: buildNumber)
                }
                .padding(.top, 4)
            }
            .opacity(appeared ? 1 : 0)
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 28)

            // "Don't show on startup" toggle — always visible, persisted via WeatherSettings.
            Toggle(isOn: Binding(
                get: { !settings.showSplashOnStartup },
                set: { settings.showSplashOnStartup = !$0 }
            )) {
                Text("Don't show on startup")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 28)
            .padding(.bottom, 4)

            // Action buttons — What's New + Close (with countdown).
            // Rendered outside the `appeared`-gated opacity blocks so both buttons
            // are immediately interactive regardless of the entrance animation state.
            HStack(spacing: 10) {
                Button {
                    showingWhatsNew = true
                } label: {
                    Label("What's New", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    onDismiss()
                } label: {
                    Text("Close (\(secondsRemaining))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 380)
        .onAppear {
            // Defer the entrance animation by one run-loop turn so the NSWindow's
            // Core Animation layer is fully composited before the SwiftUI animation
            // transaction commits — without this delay, `appeared` can stick at false
            // due to the CA layer not yet being attached when the view first renders.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            }
        }
        .task {
            // Auto-dismiss countdown
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
            onDismiss()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView { showingWhatsNew = false }
        }
    }
}

// MARK: - Version badge

/// A small labelled badge showing a version or build value.
/// Used in `SplashView` to display both the marketing version and the build number
/// side-by-side in a frosted-glass style card.
private struct VersionBadge: View {
    /// Short upper-case label above the value (e.g. "VERSION", "BUILD").
    let label: String
    /// The value displayed in large bold text (e.g. "v1.2.0", "42").
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(1.2)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
