// wthrrApp.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

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
    /// Timer that cycles the menu bar icon through its animation frames.
    private var iconAnimationTimer: Timer?
    /// Current frame index (0-2) within the 3-frame menu bar icon animation.
    private var iconAnimationFrame: Int = 0
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
        } else {
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
        startIconAnimation()

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

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(togglePopover), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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
        startIconAnimation()
    }

    /// Syncs the status bar button image to the current weather type and pause state.
    /// Public so `AppDelegate` can call it after a weather-type notification fires.
    func updateStatusItemIcon() {
        let iconName: String
        if WeatherSettings.shared.isPaused {
            iconName = "pause.circle"
        } else {
            switch WeatherSettings.shared.weatherType {
            case .rain:
                let frames = ["cloud.rain", "cloud.rain.fill", "cloud.heavyrain.fill"]
                iconName = frames[iconAnimationFrame % frames.count]
            case .aiStorm:
                let frames = ["bolt.fill", "bolt.trianglebadge.exclamationmark.fill", "bolt.circle.fill"]
                iconName = frames[iconAnimationFrame % frames.count]
            case .snow:
                let frames = ["snowflake", "cloud.snow.fill", "snowflake.circle"]
                iconName = frames[iconAnimationFrame % frames.count]
            case .thunderstorm:
                let frames = ["cloud.bolt.rain", "cloud.bolt.rain.fill", "cloud.bolt.fill"]
                iconName = frames[iconAnimationFrame % frames.count]
            case .fog:
                let frames = ["cloud.fog", "cloud.fog.fill", "cloud"]
                iconName = frames[iconAnimationFrame % frames.count]
            case .aurora:
                let frames = ["aqi.low", "aqi.medium", "aqi.high"]
                iconName = frames[iconAnimationFrame % frames.count]
            }
        }
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: "wthrr") {
            statusItem?.button?.image = img
        }
    }

    /// Starts a 2-second repeating timer that cycles the menu bar icon through 3 animation frames.
    private func startIconAnimation() {
        stopIconAnimation()
        iconAnimationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.advanceIconFrame()
        }
    }

    /// Invalidates the animation timer and resets the frame counter to 0.
    private func stopIconAnimation() {
        iconAnimationTimer?.invalidate()
        iconAnimationTimer = nil
        iconAnimationFrame = 0
    }

    /// Advances to the next icon frame (wraps at 3) and refreshes the status item image.
    private func advanceIconFrame() {
        iconAnimationFrame = (iconAnimationFrame + 1) % 3
        updateStatusItemIcon()
    }

    @objc private func togglePauseFromMenu() {
        WeatherSettings.shared.togglePause()
    }

    @objc private func showAboutFromMenu() {
        showSplashScreen(manual: true)
    }

    /// Responds to `weatherPauseChanged` notifications: stops/starts icon animation and
    /// immediately syncs the icon to the new pause state.
    @objc private func pauseStateDidChange() {
        if WeatherSettings.shared.isPaused { stopIconAnimation() } else { startIconAnimation() }
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
        splashWindow = window
    }

    // MARK: - Lifecycle

    /// Cleans up all app resources on quit: icon animation, hotkey monitors,
    /// overlay windows, and the status bar item.
    func applicationWillTerminate(_ notification: Notification) {
        stopIconAnimation()
        tearDownHotkeyMonitors()
        overlayWindowController?.tearDown()
        overlayWindowController = nil
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
