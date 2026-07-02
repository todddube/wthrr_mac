// ScreenGeometry.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import AppKit

// MARK: - Screen geometry

/// Carries per-display screen geometry from the window controller down to each
/// `WeatherView` via the SwiftUI environment. Being `@Observable` means any
/// view reading its properties automatically redraws when they change.
@Observable
class ScreenGeometry {
    /// The full physical screen rectangle (includes Dock and menu bar area).
    var screenFrame: CGRect = .zero

    /// The user-visible screen rectangle (excludes Dock and menu bar).
    var visibleFrame: CGRect = .zero

    /// Points by which the Dock raises the bottom of the visible area (Dock on bottom).
    var dockBottomInset: CGFloat { max(0, visibleFrame.minY - screenFrame.minY) }

    /// Points by which the Dock insets the left edge (Dock on left).
    var dockLeftInset: CGFloat { max(0, visibleFrame.minX - screenFrame.minX) }

    /// Points by which the Dock insets the right edge (Dock on right).
    var dockRightInset: CGFloat { max(0, screenFrame.maxX - visibleFrame.maxX) }

    /// Refreshes both frames from the given screen, triggering downstream redraws.
    func update(screen: NSScreen) {
        screenFrame  = screen.frame
        visibleFrame = screen.visibleFrame
    }
}
