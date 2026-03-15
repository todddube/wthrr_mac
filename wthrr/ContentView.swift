import SwiftUI

struct ContentView: View {
    @Environment(SnowSettings.self) private var settings
    @State private var screens: [NSScreen] = NSScreen.screens

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {

            // MARK: Weather summary
            VStack(spacing: 8) {
                Image(systemName: "cloud.snow.fill")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.multicolor)

                Text("28\u{00B0}F")
                    .font(.system(size: 34, weight: .light, design: .rounded))

                Text("Snow")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            Divider()
                .padding(.vertical, 12)

            // MARK: Settings
            VStack(spacing: 16) {

                // ── Flake count ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(settings.flakeCount) flakes")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.flakeCount) },
                        set: { settings.flakeCount = Int($0) }
                    ), in: 20...400, step: 10)
                }

                // ── Fall speed ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Speed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(speedLabel(settings.speedMultiplier))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.speedMultiplier, in: 0.25...3.0, step: 0.05)
                }

                // ── Wind strength ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Wind")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(windLabel(settings.windStrength))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.windStrength, in: 0.0...1.0, step: 0.05)
                }

                // ── Display selection ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Displays")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $settings.displayMode) {
                        Text("All Displays").tag(DisplayMode.all)
                        Text("Choose…").tag(DisplayMode.selected)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.displayMode) { _, _ in
                        applyDisplaySettings()
                    }

                    if settings.displayMode == .selected {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(screens, id: \.displayID) { screen in
                                let isOn = settings.selectedDisplayIDs.contains(screen.displayID)
                                Button {
                                    settings.toggleDisplay(screen)
                                    applyDisplaySettings()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(isOn ? .blue : .secondary)
                                        Text(screen.localizedName)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }

                            if screens.isEmpty {
                                Text("No screens detected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 4)
                    }
                }

                // ── Re-randomise ─────────────────────────────────────────────
                Button {
                    settings.reroll()
                } label: {
                    Label("Re-randomise Flakes", systemImage: "shuffle")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.vertical, 12)

            // MARK: Quit
            Button("Quit wthrr") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.bottom, 14)
        }
        .frame(width: 260)
        .onAppear {
            screens = NSScreen.screens
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            screens = NSScreen.screens
            applyDisplaySettings()
        }
    }

    // MARK: - Helpers

    private func applyDisplaySettings() {
        AppDelegate.shared?.snowflakeWindowController?.applySettings()
    }

    private func speedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.5:  return "Gentle"
        case ..<1.0:  return "Light"
        case ..<1.5:  return "Normal"
        case ..<2.2:  return "Heavy"
        default:      return "Blizzard"
        }
    }

    private func windLabel(_ v: Double) -> String {
        switch v {
        case ..<0.05: return "Calm"
        case ..<0.25: return "Breeze"
        case ..<0.5:  return "Blustery"
        case ..<0.75: return "Gusty"
        case ..<0.9:  return "Gale"
        default:      return "Storm"
        }
    }
}

#Preview {
    ContentView()
        .environment(SnowSettings())
}
