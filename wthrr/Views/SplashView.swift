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
    @Environment(\.colorScheme) private var colorScheme

    /// Called when the splash should close (timer or user action).
    var onDismiss: () -> Void

    /// Countdown seconds remaining before auto-dismiss.
    @State private var secondsRemaining: Int = 8
    @State private var appeared = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(version)"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Features shown on the splash, adapted to the current weather type.
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
        case .snow:
            return [
                ("snowflake", "Three crystal shapes"),
                ("mountain.2.fill", "Snow drift accumulation"),
                ("wind", "Dynamic gusting wind"),
                ("display.2", "Multi-display support"),
                ("slider.horizontal.3", "Fully configurable"),
            ]
        }
    }

    var body: some View {
        ZStack {
            // Live weather animation background
            WeatherView()
                .environment(settings)
                .environment(ScreenGeometry())
                .opacity(0.4)

            // Gradient overlay for readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(spacing: 0) {

                Spacer().frame(height: 32)

                // App icon & name
                VStack(spacing: 8) {
                    Image(systemName: settings.weatherIcon)
                        .font(.system(size: 56))
                        .symbolRenderingMode(.multicolor)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

                    Text("wthrr")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)

                    Text("Decorative Weather for macOS")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)

                Spacer().frame(height: 24)

                // Version & build
                HStack(spacing: 12) {
                    VersionBadge(label: "Version", value: appVersion)
                    VersionBadge(label: "Build", value: buildNumber)
                }
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 28)

                // Feature list
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 20, alignment: .center)

                            Text(feature.text)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -20)
                        .animation(.easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.08), value: appeared)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Author
                VStack(spacing: 4) {
                    Text("by Todd Dube")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("2025")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 16)

                // Close button with animated countdown
                Button {
                    onDismiss()
                } label: {
                    Text("Close (\(secondsRemaining))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
            }
        }
        .frame(width: 380, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            startCountdown()
        }
    }

    /// Counts down from 20 seconds and fires `onDismiss` when reaching zero.
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            MainActor.assumeIsolated {
                secondsRemaining -= 1
                if secondsRemaining <= 0 {
                    timer.invalidate()
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Version badge

/// A small labelled badge showing a version or build value.
private struct VersionBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
