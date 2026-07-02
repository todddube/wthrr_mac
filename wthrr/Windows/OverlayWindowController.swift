// OverlayWindowController.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import AppKit
import SwiftUI

// MARK: - Overlay window controller

/// Manages a pool of borderless, click-through overlay windows — one per active display.
/// Each window hosts a `WeatherView` that covers the entire screen and sits just
/// below the normal window level so it remains behind all application windows.
@MainActor
class OverlayWindowController {
    /// Maps CGDirectDisplayID string -> its corresponding overlay window.
    private var windowsByDisplay:  [String: NSWindow]       = [:]

    /// Maps CGDirectDisplayID string -> the screen geometry object injected into
    /// each window's hosted SwiftUI view hierarchy.
    private var geometryByDisplay: [String: ScreenGeometry] = [:]

    /// Creates overlay windows for all currently enabled displays and registers
    /// for screen configuration change notifications so the pool stays in sync.
    func showWindows() {
        applySettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Reconciles the live set of overlay windows against the current display
    /// selection in `WeatherSettings`. Removes windows for disabled displays and
    /// creates new windows for displays that have just become enabled.
    func applySettings() {
        let settings    = WeatherSettings.shared
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

    /// Constructs a single borderless, transparent, non-interactive overlay window
    /// sized to exactly cover the given screen.
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
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = true

        let geometry = ScreenGeometry()
        geometry.update(screen: screen)
        geometryByDisplay[screen.displayID] = geometry

        let rootView = WeatherView()
            .environment(WeatherSettings.shared)
            .environment(geometry)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }

    /// Updates dock insets and window frames for all existing displays without
    /// tearing down windows.
    private func refreshGeometries() {
        for screen in NSScreen.screens {
            let id = screen.displayID
            geometryByDisplay[id]?.update(screen: screen)
            windowsByDisplay[id]?.setFrame(screen.frame, display: false)
        }
    }

    /// Hides and closes all overlay windows and removes the screen-change observer.
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
    /// Dock resize/move). Refreshes geometry in-place if displays are unchanged,
    /// otherwise performs a full rebuild.
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
