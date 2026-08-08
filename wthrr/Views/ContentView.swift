// ContentView.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI
import ServiceManagement

// MARK: - Content view

/// Compact popover shown on menu-bar left-click.
/// Contains only the controls a user touches on every visit:
/// weather type, intensity, live-weather toggle, and the preview strip.
/// A display-selection section lets users target All or individual screens.
/// The footer contains Settings/Quit buttons and a tappable version row
/// that opens the splash/About screen.
/// Advanced settings (particles, colours, environment, presets, behaviour)
/// live in the separate Settings window opened via the gear button.
struct ContentView: View {
    @Environment(WeatherSettings.self) private var settings
    /// True while the user is in hotkey-recording mode.
    @State private var isRecordingHotkey = false
    /// Holds the newly captured hotkey until the user accepts or cancels.
    @State private var pendingHotkey: HotkeyBinding?
    /// Tracks hover state on the pause row to show/hide the shortcut badge.
    @State private var pauseRowHovered = false
    /// Current list of connected screens, refreshed on display change notifications.
    @State private var screens: [NSScreen] = NSScreen.screens
    private var liveWeather: LiveWeatherService { LiveWeatherService.shared }

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────
                HStack(spacing: 8) {
                    headerSection
                    Spacer()
                    Button {
                        settings.reroll()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(settings.rerollLabel)
                    pauseRow
                }
                .padding(.top, 14)
                .padding(.horizontal, 20)

                Divider().padding(.vertical, 8)

                // ── Live mini preview ────────────────────────
                ZStack {
                    Color.black.opacity(0.35)
                    WeatherView()
                        .environment(settings)
                        .environment(ScreenGeometry())
                        .id(settings.weatherType)
                        .transition(.opacity)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                .animation(.easeInOut(duration: 0.4), value: settings.weatherType)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // ── Always-visible controls ─────────────────
                VStack(spacing: 12) {
                    liveWeatherSection

                    Picker(selection: $settings.weatherType) {
                        Image(systemName: "sun.max.fill").help("Clear Skies").tag(WeatherType.clear)
                        Image(systemName: "snowflake").help("Snow").tag(WeatherType.snow)
                        Image(systemName: "cloud.rain.fill").help("Rain").tag(WeatherType.rain)
                        Image(systemName: "cloud.bolt.rain.fill").help("Thunderstorm").tag(WeatherType.thunderstorm)
                        Image(systemName: "cloud.fog.fill").help("Fog").tag(WeatherType.fog)
                        Image(systemName: "cpu").help("AI Storm").tag(WeatherType.aiStorm)
                        Image(systemName: "aqi.medium").help("Aurora").tag(WeatherType.aurora)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.liveWeatherEnabled)

                    intensityQuickTaps
                }
                .padding(.horizontal, 20)

                Divider().padding(.vertical, 10)

                // ── Display selection ────────────────────────
                displaysSection
                    .padding(.horizontal, 20)

                Divider().padding(.vertical, 10)

                // ── Footer ──────────────────────────────────
                // VStack with two rows: (1) an HStack of Settings + Quit buttons,
                // and (2) a full-width tappable AboutView that opens the splash screen.
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            AppDelegate.shared?.showSettingsWindow()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut(",")

                        Spacer()

                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit wthrr", systemImage: "power")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("q")
                    }

                    Button {
                        AppDelegate.shared?.showSplashScreen(manual: true)
                    } label: {
                        AboutView()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .help("About wthrr")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            } // VStack
        } // ScrollView
        .frame(width: 350)
        .frame(maxHeight: 400)
        .background(.regularMaterial)
        .onAppear {
            if settings.liveWeatherEnabled && !liveWeather.isRunning {
                liveWeather.start()
            }
        }
    }

    // MARK: - Header

    /// Header row: current weather icon + temperature/label on the left.
    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.isPaused ? "pause.circle" : settings.weatherIcon)
                .font(.system(size: 36))
                .symbolRenderingMode(.multicolor)

            VStack(alignment: .leading, spacing: 2) {
                if settings.liveWeatherEnabled {
                    Text(settings.temperatureText)
                        .font(.system(size: 26, weight: .light, design: .rounded))
                    Text(settings.isPaused ? "Paused" : settings.weatherLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(settings.isPaused ? "Paused" : settings.weatherLabel)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Decorative \u{00B7} Manual")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Pause row

    /// Pause/resume button. Hover reveals a hotkey badge; tapping it enters recording mode.
    private var pauseRow: some View {
        VStack(spacing: 4) {
            Button {
                settings.togglePause()
            } label: {
                Label(settings.isPaused ? "Resume" : "Pause",
                      systemImage: settings.isPaused ? "play.fill" : "pause.fill")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if pauseRowHovered || isRecordingHotkey {
                ShortcutBadge(
                    binding: settings.pauseHotkey,
                    isRecording: $isRecordingHotkey,
                    pendingHotkey: $pendingHotkey,
                    onAccept: {
                        if let hotkey = pendingHotkey { settings.pauseHotkey = hotkey }
                        pendingHotkey    = nil
                        isRecordingHotkey = false
                    },
                    onCancel: {
                        pendingHotkey    = nil
                        isRecordingHotkey = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { pauseRowHovered = hovering }
        }
    }

    // MARK: - Live weather section

    private var liveWeatherSection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $settings.liveWeatherEnabled) {
                HStack {
                    Text("Live Weather")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.liveWeatherEnabled ? "Auto" : "Manual")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: settings.liveWeatherEnabled) { _, enabled in
                if enabled { liveWeather.start() } else { liveWeather.stop() }
            }

            if settings.liveWeatherEnabled {
                HStack(spacing: 6) {
                    if liveWeather.isLoading {
                        ProgressView().controlSize(.mini)
                    } else if let err = liveWeather.errorMessage {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2).foregroundStyle(.orange)
                        Text(err).font(.caption2).foregroundStyle(.secondary)
                    } else if !liveWeather.locationName.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(liveWeather.locationName)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        liveWeather.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise").font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(liveWeather.isLoading)
                }
                Text("Type and intensity are set automatically")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Display selection

    /// Compact All / Choose display picker with per-screen toggles when "Choose" is active.
    private var displaysSection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Displays")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $settings.displayMode) {
                Text("All Displays").tag(DisplayMode.all)
                Text("Choose\u{2026}").tag(DisplayMode.selected)
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.displayMode) { _, _ in
                AppDelegate.shared?.overlayWindowController?.applySettings()
            }

            if settings.displayMode == .selected {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(screens, id: \.displayID) { screen in
                        let isOn = settings.selectedDisplayIDs.contains(screen.displayID)
                        Button {
                            settings.toggleDisplay(screen)
                            AppDelegate.shared?.overlayWindowController?.applySettings()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isOn ? .blue : .secondary)
                                Text(screen.localizedName).font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    if screens.isEmpty {
                        Text("No screens detected")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            screens = NSScreen.screens
            AppDelegate.shared?.overlayWindowController?.applySettings()
        }
    }

    // MARK: - Intensity quick-taps

    /// Three-button row (Light / Medium / Heavy) for one-tap intensity presets.
    private var intensityQuickTaps: some View {
        HStack(spacing: 6) {
            ForEach(Intensity.allCases) { intensity in
                Button {
                    applyIntensity(intensity)
                } label: {
                    Text(intensity.rawValue)
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(currentIntensity == intensity ? .accentColor : nil)
            }
            if currentIntensity == nil {
                Text("Custom")
                    .font(.caption2.italic())
                    .foregroundStyle(.tertiary)
            }
        }
        .disabled(settings.liveWeatherEnabled)
    }

    // MARK: - Intensity helpers

    private enum Intensity: String, CaseIterable, Identifiable {
        case light  = "Light"
        case medium = "Medium"
        case heavy  = "Heavy"
        var id: String { rawValue }
    }

    private var currentIntensity: Intensity? {
        let count = settings.flakeCount
        let speed = settings.speedMultiplier
        if count <= 80 && speed <= 0.65                        { return .light  }
        if count >= 250 && speed >= 1.8                        { return .heavy  }
        if (100...220).contains(count) && (0.8...1.4).contains(speed) { return .medium }
        return nil
    }

    private func applyIntensity(_ intensity: Intensity) {
        switch intensity {
        case .light:
            settings.flakeCount       = 60
            settings.speedMultiplier  = 0.5
            settings.windStrength     = 0.15
            settings.particleOpacity  = 0.7
        case .medium:
            settings.flakeCount       = 180
            settings.speedMultiplier  = 1.0
            settings.windStrength     = 0.5
            settings.particleOpacity  = 1.0
        case .heavy:
            settings.flakeCount       = 350
            settings.speedMultiplier  = 2.2
            settings.windStrength     = 0.8
            settings.particleOpacity  = 1.2
        }
    }
}

// MARK: - Shortcut badge

/// Tappable badge showing the current hotkey. Tap to enter recording mode,
/// press a new shortcut, then accept or cancel.
struct ShortcutBadge: View {
    let binding: HotkeyBinding
    @Binding var isRecording: Bool
    @Binding var pendingHotkey: HotkeyBinding?
    let onAccept: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if isRecording {
            HStack(spacing: 6) {
                Text(pendingHotkey?.displayString ?? "Press keys\u{2026}")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(pendingHotkey != nil ? .primary : .tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    )
                    .background(
                        KeyEventCatcher { event in
                            if let hotkey = HotkeyBinding.from(event: event) {
                                pendingHotkey = hotkey
                            }
                        }
                    )

                if pendingHotkey != nil {
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Accept new shortcut")
                }

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
        } else {
            Button {
                isRecording   = true
                pendingHotkey = nil
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard").font(.system(size: 11))
                    Text(binding.displayString)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Click to change shortcut")
        }
    }
}

// MARK: - Key event catcher

/// An invisible NSView-backed view that becomes first responder to capture key events
/// during shortcut recording.
struct KeyEventCatcher: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    class KeyCatcherView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }
        override func keyDown(with event: NSEvent) { onKeyDown?(event) }
    }
}

// MARK: - Preset pill

/// Compact pill button for loading a preset. Long-press/right-click for Delete.
struct PresetPill: View {
    let preset:   WeatherPreset
    let onTap:    () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Image(systemName: iconForType(preset.weatherType)).font(.system(size: 8))
                Text(preset.name).font(.caption2).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func iconForType(_ type: WeatherType) -> String {
        switch type {
        case .snow:         return "snowflake"
        case .rain:         return "cloud.rain"
        case .thunderstorm: return "cloud.bolt.rain"
        case .fog:          return "cloud.fog"
        case .clear:        return "sun.max"
        case .aiStorm:      return "bolt"
        case .aurora:       return "aqi.medium"
        }
    }
}

// MARK: - Flow layout

/// Simple horizontal wrapping layout for preset pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x,
                                               y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private struct ArrangeResult { var positions: [CGPoint]; var size: CGSize }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions:   [CGPoint] = []
        var x:           CGFloat   = 0
        var y:           CGFloat   = 0
        var rowHeight:   CGFloat   = 0
        var totalWidth:  CGFloat   = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight   = max(rowHeight, size.height)
            x          += size.width + spacing
            totalWidth  = max(totalWidth, x - spacing)
        }
        return ArrangeResult(positions: positions,
                             size: CGSize(width: totalWidth, height: y + rowHeight))
    }
}

// MARK: - About view

/// Compact footer showing app version and a GitHub link.
/// Wrapped in a `.plain` Button inside `ContentView` so tapping anywhere
/// on this row opens the splash/About screen via `showSplashScreen(manual:)`.
struct AboutView: View {
    private let repoURL = URL(string: "https://github.com/todddube/wthrr_mac")!

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("wthrr  \(appVersion)")
                .font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("by Todd Dube  \u{00B7}")
                    .font(.caption2).foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.open(repoURL)
                } label: {
                    Text("GitHub").font(.caption2).foregroundStyle(.blue).underline()
                }
                .buttonStyle(.plain)
                .help("Open wthrr_mac on GitHub")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WeatherSettings())
}
