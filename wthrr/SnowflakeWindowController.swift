// SnowflakeWindowController.swift
// wthrr — macOS decorative snowfall overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import AppKit
import SwiftUI

// MARK: - Screen geometry

/// Carries per-display screen geometry from the window controller down to each
/// `SnowflakeView` via the SwiftUI environment. Being `@Observable` means any
/// view reading its properties automatically redraws when they change.
/// Currently used to pass dock inset information for future visual effects.
@Observable
class ScreenGeometry {
    /// The full physical screen rectangle (includes Dock and menu bar area).
    var screenFrame: CGRect = .zero

    /// The user-visible screen rectangle (excludes Dock and menu bar).
    /// Apple advises not to cache this value as it can change at any time.
    var visibleFrame: CGRect = .zero

    /// Points by which the Dock raises the bottom of the visible area (Dock on bottom).
    var dockBottomInset: CGFloat { max(0, visibleFrame.minY - screenFrame.minY) }

    /// Points by which the Dock insets the left edge (Dock on left).
    var dockLeftInset:   CGFloat { max(0, visibleFrame.minX - screenFrame.minX) }

    /// Points by which the Dock insets the right edge (Dock on right).
    var dockRightInset:  CGFloat { max(0, screenFrame.maxX - visibleFrame.maxX) }

    /// Refreshes both frames from the given screen, triggering downstream redraws.
    func update(screen: NSScreen) {
        screenFrame  = screen.frame
        visibleFrame = screen.visibleFrame
    }
}

// MARK: - Window controller

/// Manages a pool of borderless, click-through overlay windows — one per active display.
/// Each window hosts a `SnowflakeView` that covers the entire screen and sits just
/// below the normal window level so it remains behind all application windows.
@MainActor
class SnowflakeWindowController {
    /// Maps CGDirectDisplayID string → its corresponding overlay window.
    private var windowsByDisplay:  [String: NSWindow]       = [:]

    /// Maps CGDirectDisplayID string → the screen geometry object injected into
    /// each window's hosted SwiftUI view hierarchy.
    private var geometryByDisplay: [String: ScreenGeometry] = [:]

    /// Creates overlay windows for all currently enabled displays and registers
    /// for screen configuration change notifications so the pool stays in sync
    /// when monitors are connected, disconnected, or reconfigured.
    func showWindows() {
        applySettings()

        // React to physical screen changes (plug/unplug/resolution/dock resize)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Reconciles the live set of overlay windows against the current display
    /// selection in `SnowSettings`. Removes windows for disabled displays and
    /// creates new windows for displays that have just become enabled.
    func applySettings() {
        let settings    = SnowSettings.shared
        let liveScreens = NSScreen.screens

        let desiredIDs = Set(liveScreens
            .filter { settings.isEnabled(for: $0) }
            .map    { $0.displayID })

        // Remove windows for displays that are no longer wanted
        for id in Array(windowsByDisplay.keys) where !desiredIDs.contains(id) {
            windowsByDisplay[id]?.orderOut(nil)
            windowsByDisplay.removeValue(forKey: id)
            geometryByDisplay.removeValue(forKey: id)
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

    /// Returns the appropriate window level based on the current `showOverDock` setting.
    /// Below normal (default): overlay sits under all app windows and the Dock.
    /// Status bar level: overlay floats above the Dock but still below system UI panels.
    private var overlayWindowLevel: NSWindow.Level {
        SnowSettings.shared.showOverDock
            ? .statusBar
            : NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
    }

    /// Re-applies the current window level to all live overlay windows without
    /// tearing them down. Called when the user toggles the "Over Dock" setting.
    func updateWindowLevels() {
        let level = overlayWindowLevel
        for window in windowsByDisplay.values {
            window.level = level
        }
    }

    /// Constructs a single borderless, transparent, non-interactive overlay window
    /// sized to exactly cover the given screen. Injects a `ScreenGeometry` instance
    /// so the hosted view can respond to dock/screen changes reactively.
    private func makeOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = overlayWindowLevel
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = true

        let geometry = ScreenGeometry()
        geometry.update(screen: screen)
        geometryByDisplay[screen.displayID] = geometry

        let rootView = SnowflakeView()
            .environment(SnowSettings.shared)
            .environment(geometry)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }

    /// Updates dock insets and window frames for all existing displays without
    /// tearing down windows. Called when the Dock is resized or moved.
    private func refreshGeometries() {
        for screen in NSScreen.screens {
            let id = screen.displayID
            geometryByDisplay[id]?.update(screen: screen)
            windowsByDisplay[id]?.setFrame(screen.frame, display: false)
        }
    }

    /// Hides and closes all overlay windows and removes the screen-change observer.
    /// Must be called before the app terminates to ensure a clean exit.
    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        for window in windowsByDisplay.values {
            window.orderOut(nil)
            window.close()
        }
        windowsByDisplay.removeAll()
        geometryByDisplay.removeAll()
    }

    /// Responds to screen configuration changes (monitor plug/unplug, resolution,
    /// Dock resize/move). If the display set is unchanged, refreshes geometry
    /// in-place. If displays were added or removed, performs a full rebuild.
    @objc private func screensDidChange(_ notification: Notification) {
        let currentIDs  = Set(NSScreen.screens.map { $0.displayID })
        let existingIDs = Set(windowsByDisplay.keys)

        if currentIDs == existingIDs {
            refreshGeometries()
        } else {
            for window in windowsByDisplay.values { window.orderOut(nil) }
            windowsByDisplay.removeAll()
            geometryByDisplay.removeAll()
            applySettings()
        }
    }
}
