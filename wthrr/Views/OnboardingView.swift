// OnboardingView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Onboarding view

/// A 3-step first-launch walkthrough: welcome, pick weather, set intensity.
/// Shown once on first launch, then never again (gated by UserDefaults).
struct OnboardingView: View {
    @Environment(WeatherSettings.self) private var settings
    var onComplete: () -> Void

    @State private var step = 0
    @State private var appeared = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Live weather background
            WeatherView()
                .environment(settings)
                .environment(ScreenGeometry())
                .opacity(0.4)

            // Dark overlay for readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.75),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

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
                .offset(y: appeared ? 0 : 15)

                Spacer()

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 16)

                // Next / Done button
                Button {
                    if step < totalSteps - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appeared = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            step += 1
                            withAnimation(.easeOut(duration: 0.35)) {
                                appeared = true
                            }
                        }
                    } else {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        onComplete()
                    }
                } label: {
                    Text(step < totalSteps - 1 ? "Next" : "Get Started")
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

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.snow.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Text("Welcome to wthrr")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Animated weather effects\nfor your macOS desktop")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "sparkles", text: "Snow, rain, fog, storms & more")
                featureRow(icon: "display.2", text: "Works across all displays")
                featureRow(icon: "slider.horizontal.3", text: "Fully customizable")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 2: Pick weather

    private var weatherPickerStep: some View {
        @Bindable var settings = settings
        return VStack(spacing: 16) {
            Image(systemName: settings.weatherIcon)
                .font(.system(size: 48))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Text("Pick Your Weather")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("You can change this anytime\nfrom the menu bar")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                weatherButton(.snow, icon: "cloud.snow.fill", label: "Snow")
                weatherButton(.rain, icon: "cloud.rain.fill", label: "Rain")
                weatherButton(.thunderstorm, icon: "cloud.bolt.rain.fill", label: "Thunderstorm")
                weatherButton(.fog, icon: "cloud.fog.fill", label: "Fog")
                weatherButton(.aiStorm, icon: "bolt.trianglebadge.exclamationmark.fill", label: "AI Storm")
                weatherButton(.aurora, icon: "aqi.medium", label: "Aurora Borealis")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step 3: Set intensity

    private var intensityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 48))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Text("Set the Intensity")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("How much weather\ndo you want?")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                intensityButton("Light", description: "Subtle and gentle",
                                count: 60, speed: 0.5, wind: 0.15, opacity: 0.7)
                intensityButton("Medium", description: "Balanced and natural",
                                count: 180, speed: 1.0, wind: 0.5, opacity: 1.0)
                intensityButton("Heavy", description: "Dramatic and immersive",
                                count: 350, speed: 2.2, wind: 0.8, opacity: 1.2)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func weatherButton(_ type: WeatherType, icon: String, label: String) -> some View {
        Button {
            settings.weatherType = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Spacer()
                if settings.weatherType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(settings.weatherType == type ? .white.opacity(0.2) : .white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(settings.weatherType == type ? 0.4 : 0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func intensityButton(_ title: String, description: String,
                                  count: Int, speed: Double, wind: Double, opacity: Double) -> some View {
        let isSelected = settings.flakeCount == count && settings.speedMultiplier == speed
        return Button {
            settings.flakeCount = count
            settings.speedMultiplier = speed
            settings.windStrength = wind
            settings.particleOpacity = opacity
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(description)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? .white.opacity(0.2) : .white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(isSelected ? 0.4 : 0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
