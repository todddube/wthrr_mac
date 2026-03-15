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

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var splashWindow: NSWindow?

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

        showSplashScreen()

        // Keep the icon in sync with the weather type setting.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherTypeDidChange),
            name: .weatherTypeChanged,
            object: nil
        )
        updateStatusItemIcon()

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
        p.animates = true
        p.contentSize   = NSSize(width: 280, height: 520)
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Builds and pops up the right-click context menu below the status bar button.
    private func showContextMenu() {
        // Close the popover first so it doesn't overlap the menu.
        popover?.performClose(nil)

        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(togglePopover), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    func updateStatusItemIcon() {
        let name = WeatherSettings.shared.weatherType == .rain ? "cloud.rain.fill" : "cloud.snow.fill"
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: "wthrr") {
            statusItem?.button?.image = img
        }
    }

    // MARK: - Splash screen

    /// Creates and displays a centred splash window with live weather animation.
    /// The window auto-dismisses after 20 seconds or when the user clicks close.
    private func showSplashScreen() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 540),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
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
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.close()
        })
    }

    // MARK: - Lifecycle

    func applicationWillTerminate(_ notification: Notification) {
        overlayWindowController?.tearDown()
        overlayWindowController = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static var sigTermKey = 0
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted by WeatherSettings when weatherType changes, so AppDelegate can sync the icon.
    static let weatherTypeChanged = Notification.Name("wthrr.weatherTypeChanged")
}
