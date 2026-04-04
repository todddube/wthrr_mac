// WeatherPreviewView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI

// MARK: - Weather preview view

/// Full-size preview window for taking clean screenshots of each weather effect.
/// Renders the active weather against a solid black background with a bottom toolbar
/// for switching weather types. Open via right-click → "Screenshot Preview…".
struct WeatherPreviewView: View {
    @Environment(WeatherSettings.self) private var settings
    var onClose: () -> Void

    private struct TypeOption: Identifiable {
        let id: WeatherType
        let icon: String
        let label: String
    }

    private let options: [TypeOption] = [
        .init(id: .snow,         icon: "snowflake",            label: "Snow"),
        .init(id: .rain,         icon: "cloud.rain.fill",      label: "Rain"),
        .init(id: .thunderstorm, icon: "cloud.bolt.rain.fill", label: "Thunderstorm"),
        .init(id: .fog,          icon: "cloud.fog.fill",       label: "Fog"),
        .init(id: .aiStorm,      icon: "cpu",                  label: "AI Storm"),
        .init(id: .aurora,       icon: "aqi.medium",           label: "Aurora"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            WeatherView()
                .environment(settings)
                .environment(ScreenGeometry())

            // Bottom toolbar: weather type switcher + screenshot hint + close
            HStack(spacing: 2) {
                ForEach(options) { opt in
                    let isActive = settings.weatherType == opt.id
                    Button {
                        settings.weatherType = opt.id
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 16))
                            Text(opt.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(width: 70, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isActive ? Color.white.opacity(0.16) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isActive ? .white : .white.opacity(0.45))
                    .help(opt.label)
                }

                Spacer()

                Text("Tip: ⌘⇧4 then click this window")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.trailing, 10)

                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.80))
        }
        .preferredColorScheme(.dark)
    }
}
