import AppKit
import SwiftUI

@MainActor
class SnowflakeWindowController {
    /// Maps CGDirectDisplayID string → its overlay window.
    private var windowsByDisplay: [String: NSWindow] = [:]

    func showWindows() {
        applySettings()

        // React to physical screen changes (plug/unplug/resolution)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Called whenever display selection settings change (from ContentView) or
    /// when the screen layout changes.
    func applySettings() {
        let settings = SnowSettings.shared
        let liveScreens = NSScreen.screens

        // Build the set of display IDs that should currently be active
        let desiredIDs = Set(liveScreens
            .filter { settings.isEnabled(for: $0) }
            .map { $0.displayID })

        // Remove windows for displays that are no longer wanted
        for id in Array(windowsByDisplay.keys) where !desiredIDs.contains(id) {
            windowsByDisplay[id]?.orderOut(nil)
            windowsByDisplay.removeValue(forKey: id)
        }

        // Add windows for displays that don't have one yet
        for screen in liveScreens where desiredIDs.contains(screen.displayID) {
            let id = screen.displayID
            if windowsByDisplay[id] == nil {
                let window = makeOverlayWindow(for: screen)
                windowsByDisplay[id] = window
                window.orderFront(nil)
            }
        }
    }

    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Position exactly over this screen in global AppKit coordinates
        window.setFrame(screen.frame, display: false)

        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = true

        let rootView = SnowflakeView().environment(SnowSettings.shared)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }

    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        for window in windowsByDisplay.values {
            window.orderOut(nil)
            window.close()
        }
        windowsByDisplay.removeAll()
    }

    @objc private func screensDidChange(_ notification: Notification) {
        // Tear down everything and rebuild; physical layout may have changed
        for window in windowsByDisplay.values { window.orderOut(nil) }
        windowsByDisplay.removeAll()
        applySettings()
    }
}
