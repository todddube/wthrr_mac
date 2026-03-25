// OnboardingView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Onboarding view

/// A 3-step first-launch walkthrough: welcome, pick weather, set intensity.
/// Shown once on first launch, then never again (gated by UserDefaults key `hasCompletedOnboarding`).
/// The walkthrough is also accessible from the footer of `ContentView` as a reminder.
struct OnboardingView: View {
    @Environment(WeatherSettings.self) private var settings
    /// Called when the user taps "Get Started" on the final step.
    var onComplete: () -> Void

    /// Zero-based index of the currently displayed step (0 = welcome, 1 = picker, 2 = intensity).
    @State private var step = 0
    /// Controls the fade/slide-in animation of each step's content.
    @State private var appeared = false

    /// Total number of walkthrough steps (drives the progress dot row).
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: weatherPickerStep
                case 2: intensityStep
                default: EmptyView()
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom bar: progress dots + Next/Done button
            HStack {
                HStack(spacing: 7) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                Button {
                    if step < totalSteps - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) { appeared = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            step += 1
                            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
                        }
                    } else {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        onComplete()
                    }
                } label: {
                    Text(step < totalSteps - 1 ? "Next" : "Get Started")
                        .frame(width: 90)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 420)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "cloud.snow.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.multicolor)
                .padding(.top, 28)

            Text("Welcome to wthrr")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Animated weather effects for your macOS desktop")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "sparkles",          text: "Snow, rain, fog, aurora & more")
                featureRow(icon: "location.fill",     text: "Live weather or fully manual")
                featureRow(icon: "display.2",         text: "Works across all displays")
                featureRow(icon: "slider.horizontal.3", text: "9 presets — or tune your own")
            }
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Step 2: Pick weather

    private var weatherPickerStep: some View {
        @Bindable var settings = settings
        return VStack(spacing: 12) {
            Image(systemName: settings.weatherIcon)
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
                .padding(.top, 28)

            Text("Pick Your Weather")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("You can change this anytime from the menu bar")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                weatherButton(.snow,        icon: "cloud.snow.fill",              label: "Snow")
                weatherButton(.rain,        icon: "cloud.rain.fill",              label: "Rain")
                weatherButton(.thunderstorm, icon: "cloud.bolt.rain.fill",        label: "Thunderstorm")
                weatherButton(.fog,         icon: "cloud.fog.fill",              label: "Fog")
                weatherButton(.aiStorm,     icon: "bolt.trianglebadge.exclamationmark.fill", label: "AI Storm")
                weatherButton(.aurora,      icon: "aqi.medium",                  label: "Aurora Borealis")
            }
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Step 3: Set intensity

    private var intensityStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
                .padding(.top, 28)

            Text("Set the Intensity")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("How much weather do you want?")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                intensityButton("Light",  description: "Subtle and gentle",
                                count: 60,  speed: 0.5, wind: 0.15, opacity: 0.7)
                intensityButton("Medium", description: "Balanced and natural",
                                count: 180, speed: 1.0, wind: 0.5,  opacity: 1.0)
                intensityButton("Heavy",  description: "Dramatic and immersive",
                                count: 350, speed: 2.2, wind: 0.8,  opacity: 1.2)
            }
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Helpers

    /// A single icon + text feature row used in the welcome step.
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
        }
    }

    /// A full-width selectable button for choosing a weather type in the picker step.
    /// The selected button shows an accent background and a checkmark to confirm the choice.
    private func weatherButton(_ type: WeatherType, icon: String, label: String) -> some View {
        let selected = settings.weatherType == type
        return Button {
            settings.weatherType = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// A full-width selectable button for choosing a particle intensity preset in the final step.
    /// Tapping immediately applies `flakeCount`, `speedMultiplier`, `windStrength`, and
    /// `particleOpacity` to `WeatherSettings`, providing live feedback via the overlay windows.
    private func intensityButton(_ title: String, description: String,
                                  count: Int, speed: Double, wind: Double, opacity: Double) -> some View {
        let selected = settings.flakeCount == count && settings.speedMultiplier == speed
        return Button {
            settings.flakeCount = count
            settings.speedMultiplier = speed
            settings.windStrength = wind
            settings.particleOpacity = opacity
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
