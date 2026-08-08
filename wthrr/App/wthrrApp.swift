// wthrrApp.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI
import Darwin
import AppKit

// MARK: - App entry point

/// App entry point. All menu bar UI is driven by AppDelegate so we get full
/// control over left-click (popover) and right-click (context menu) behaviour.
@main
struct wthrrApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // No window scenes — the entire UI lives in the NSStatusItem managed by AppDelegate.
        Settings { EmptyView() }
    }
}

// MARK: - App delegate

/// Manages the NSStatusItem, NSPopover (settings), and right-click NSMenu.
/// Left-click toggles the popover; right/control-click shows a compact context menu
/// with a "Settings" item that opens the same popover, plus "Quit".
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private(set) var overlayWindowController: OverlayWindowController?

    // MARK: Status item & popover

    /// The system status item (menu bar icon).
    private var statusItem: NSStatusItem?
    /// The NSPopover that hosts `ContentView`. Shown on left-click.
    private var popover: NSPopover?
    /// The floating window currently showing splash, onboarding, or What's New. One at a time.
    private var splashWindow: NSWindow?
    /// The persistent settings window (Appearance / Environment / Displays / Presets / Behavior tabs).
    private var settingsWindow: NSWindow?
    /// The screenshot preview window (black background + weather canvas + type switcher).
    private var previewWindow: NSWindow?
    /// True when the splash was triggered manually via the settings button,
    /// meaning menu-bar interactions should NOT auto-dismiss it.
    private var splashIsManual = false
    /// Global hotkey monitor for pause/resume (fires even when the app is not focused).
    private var globalHotkeyMonitor: Any?
    /// Local hotkey monitor for when the app is focused (e.g. popover open).
    private var localHotkeyMonitor: Any?

    /// Builds the NSStatusItem and NSPopover, then starts the overlay.
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Enforce single instance.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            NSApplication.shared.terminate(nil)
            return
        }

        setupStatusItem()

        overlayWindowController = OverlayWindowController()
        overlayWindowController?.showWindows()

        // Show onboarding on first launch, or What's New after update, or splash
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        } else if WhatsNewView.shouldShow {
            showWhatsNew()
        } else if WeatherSettings.shared.showSplashOnStartup {
            showSplashScreen()
        }

        // Keep the icon in sync with the weather type and pause state.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherTypeDidChange),
            name: .weatherTypeChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseStateDidChange),
            name: .weatherPauseChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyBindingDidChange),
            name: .hotkeyBindingChanged,
            object: nil
        )
        updateStatusItemIcon()
        setupGlobalHotkey()

        // Start adaptive quality polling if the feature is enabled.
        if WeatherSettings.shared.adaptiveQualityEnabled {
            AdaptiveQualityMonitor.shared.start()
        }

        // Clean SIGTERM → NSApp.terminate so applicationWillTerminate fires.
        signal(SIGTERM, SIG_IGN)
        let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigTermSource.setEventHandler { NSApplication.shared.terminate(nil) }
        sigTermSource.resume()
        objc_setAssociatedObject(self, &AppDelegate.sigTermKey, sigTermSource, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: - Status item setup

    /// Creates the NSStatusItem with a button that responds to both left and right clicks.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.action = #selector(statusButtonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.target = self
        statusItem = item

        let p = NSPopover()
        p.contentSize   = NSSize(width: 360, height: 680)
        p.behavior      = .transient
        p.animates      = true
        p.contentViewController = NSHostingController(
            rootView: ContentView().environment(WeatherSettings.shared)
        )
        popover = p
    }

    /// Routes left-click to the popover toggle and right/control-click to the context menu.
    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp ||
           event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    /// Shows or hides the settings popover relative to the status bar button.
    @objc func togglePopover(_ sender: Any? = nil) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if !splashIsManual { dismissSplashScreen() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Builds and pops up the right-click context menu below the status bar button.
    private func showContextMenu() {
        // Close the popover first so it doesn't overlap the menu.
        popover?.performClose(nil)
        if !splashIsManual { dismissSplashScreen() }

        let menu = NSMenu()

        let pauseTitle = WeatherSettings.shared.isPaused ? "Resume" : "Pause"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePauseFromMenu), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let popoverItem = NSMenuItem(title: "Open wthrr", action: #selector(togglePopover), keyEquivalent: "")
        popoverItem.target = self
        menu.addItem(popoverItem)

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let previewItem = NSMenuItem(title: "Screenshot Preview\u{2026}", action: #selector(openPreviewWindow), keyEquivalent: "")
        previewItem.target = self
        menu.addItem(previewItem)

        let aboutItem = NSMenuItem(title: "About wthrr", action: #selector(showAboutFromMenu), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit wthrr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Clear the menu so future left-clicks still route through our action handler.
        statusItem?.menu = nil
    }

    // MARK: - Icon sync

    /// Updates the status item icon to match the current weather type.
    @objc private func weatherTypeDidChange() {
        updateStatusItemIcon()
    }

    /// Syncs the status bar button image to the current weather type and pause state.
    func updateStatusItemIcon() {
        let iconName: String
        if WeatherSettings.shared.isPaused {
            iconName = "pause.circle"
        } else {
            switch WeatherSettings.shared.weatherType {
            case .clear:        iconName = "sun.max.fill"
            case .snow:         iconName = "snowflake"
            case .rain:         iconName = "cloud.rain.fill"
            case .thunderstorm: iconName = "cloud.bolt.rain.fill"
            case .fog:          iconName = "cloud.fog.fill"
            case .aiStorm:      iconName = "bolt.fill"
            case .aurora:       iconName = "aqi.medium"
            }
        }
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: "wthrr") {
            statusItem?.button?.image = img
        }
    }

    @objc private func togglePauseFromMenu() {
        WeatherSettings.shared.togglePause()
    }

    @objc private func openSettingsWindow() {
        showSettingsWindow()
    }

    @objc private func openPreviewWindow() {
        showPreviewWindow()
    }

    @objc private func showAboutFromMenu() {
        showSplashScreen(manual: true)
    }

    /// Responds to `weatherPauseChanged` notifications and syncs the icon to the new pause state.
    @objc private func pauseStateDidChange() {
        updateStatusItemIcon()
    }

    // MARK: - Global hotkey

    /// Registers the global and local hotkey monitors.
    private func setupGlobalHotkey() {
        tearDownHotkeyMonitors()
        // Global monitor (when app is not focused)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkeyEvent(event)
        }
        // Local monitor (when app is focused, e.g. popover open)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkeyEvent(event) == true { return nil }
            return event
        }
    }

    /// Removes both the global and local event monitors, releasing their resources.
    private func tearDownHotkeyMonitors() {
        if let monitor = globalHotkeyMonitor { NSEvent.removeMonitor(monitor); globalHotkeyMonitor = nil }
        if let monitor = localHotkeyMonitor { NSEvent.removeMonitor(monitor); localHotkeyMonitor = nil }
    }

    @objc private func hotkeyBindingDidChange() {
        // Re-register monitors (the matching logic reads the binding dynamically,
        // so we just need to ensure monitors are active).
        setupGlobalHotkey()
    }

    /// Returns true if the event matched the user-configured pause hotkey.
    @discardableResult
    private func handleHotkeyEvent(_ event: NSEvent) -> Bool {
        guard WeatherSettings.shared.pauseHotkey.matches(event) else {
            return false
        }
        WeatherSettings.shared.togglePause()
        return true
    }

    // MARK: - Settings window

    /// Opens the tabbed settings window, or brings it to front if already open.
    /// Dismisses the popover first to avoid focus conflicts between the popover
    /// and the new key window.
    func showSettingsWindow() {
        // Dismiss the popover first so it doesn't compete for key-window status.
        popover?.performClose(nil)

        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "wthrr Settings"
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsWindowView().environment(WeatherSettings.shared)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Screenshot preview window

    /// Opens a 1280×800 preview window with a black background and weather canvas,
    /// useful for taking clean screenshots of each weather type.
    func showPreviewWindow() {
        popover?.performClose(nil)

        if let win = previewWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "wthrr Preview"
        window.center()
        window.contentView = NSHostingView(
            rootView: WeatherPreviewView { [weak self] in
                self?.previewWindow?.close()
                self?.previewWindow = nil
            }
            .environment(WeatherSettings.shared)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewWindow = window
    }

    // MARK: - Splash screen

    /// Creates and displays a centred splash window with live weather animation.
    /// The window auto-dismisses after the countdown or when the user clicks close.
    /// Pass `manual: true` when triggered from the settings panel so that
    /// opening the menu bar popover does not immediately dismiss the splash.
    func showSplashScreen(manual: Bool = false) {
        splashIsManual = manual
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "About wthrr"
        window.level = .floating
        window.center()

        let splashView = SplashView { [weak self] in
            self?.dismissSplashScreen()
        }
        .environment(WeatherSettings.shared)

        window.contentView = NSHostingView(rootView: splashView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        splashWindow = window
    }

    /// Fades out and closes the splash window.
    func dismissSplashScreen() {
        guard let window = splashWindow else { return }
        splashWindow = nil
        splashIsManual = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.close()
        })
    }

    // MARK: - Onboarding

    /// Shows the first-launch onboarding walkthrough.
    func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Welcome to wthrr"
        window.level = .floating
        window.center()

        let onboardingView = OnboardingView { [weak self] in
            self?.dismissSplashScreen()
        }
        .environment(WeatherSettings.shared)

        window.contentView = NSHostingView(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        splashWindow = window
    }

    // MARK: - What's New

    /// Shows the post-update changelog screen.
    func showWhatsNew() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "What's New in wthrr"
        window.level = .floating
        window.center()

        let whatsNewView = WhatsNewView { [weak self] in
            WhatsNewView.markAsSeen()
            self?.dismissSplashScreen()
        }

        window.contentView = NSHostingView(rootView: whatsNewView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        splashWindow = window
    }

    // MARK: - Lifecycle

    /// Cleans up all app resources on quit: AdaptiveQualityMonitor polling,
    /// icon animation, hotkey monitors, overlay windows, and the status bar item.
    func applicationWillTerminate(_ notification: Notification) {
        AdaptiveQualityMonitor.shared.stop()
        tearDownHotkeyMonitors()
        overlayWindowController?.tearDown()
        overlayWindowController = nil
        settingsWindow?.close()
        settingsWindow = nil
        previewWindow?.close()
        previewWindow = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    /// Returns `false` so closing the splash/about window does not terminate the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Key used with `objc_setAssociatedObject` to retain the SIGTERM dispatch source.
    private static var sigTermKey = 0
}

// MARK: - Keyable borderless window

/// A borderless NSWindow subclass that can become the key window.
/// Used for the splash screen so `makeKeyAndOrderFront` works without warnings.
private class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted by WeatherSettings when weatherType changes, so AppDelegate can sync the icon.
    static let weatherTypeChanged = Notification.Name("wthrr.weatherTypeChanged")
    /// Posted by WeatherSettings when isPaused changes, so AppDelegate can sync the icon.
    static let weatherPauseChanged = Notification.Name("wthrr.weatherPauseChanged")
    /// Posted by WeatherSettings when the pause hotkey binding changes.
    static let hotkeyBindingChanged = Notification.Name("wthrr.hotkeyBindingChanged")
}
