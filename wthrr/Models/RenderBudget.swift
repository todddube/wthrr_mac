// RenderBudget.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation

// MARK: - Render budget

/// Resolves how often — and whether at all — an overlay canvas should redraw.
///
/// Every input that can suppress or slow rendering funnels through here so the
/// decision lives in one place and `WeatherView` can hand the result straight to
/// `TimelineView(.animation(minimumInterval:paused:))`.
///
/// Suspending the timeline (rather than merely skipping physics) is what actually
/// saves energy: a paused `TimelineView` stops requesting frames, so the Canvas
/// closure is never invoked and nothing is rasterised.
struct RenderBudget: Equatable {
    /// When true, the timeline stops requesting frames entirely.
    let paused: Bool

    /// Minimum seconds between frames, or nil to run at the display refresh rate.
    let minimumInterval: Double?

    /// Why rendering is suspended, for diagnostics. Empty when running.
    let suspensionReason: String?

    /// Computes the budget for one overlay canvas.
    ///
    /// - Parameters:
    ///   - settings: Current user settings.
    ///   - isVisible: False when the hosting window is fully occluded by other windows.
    @MainActor
    static func current(settings: WeatherSettings, isVisible: Bool) -> RenderBudget {
        let system = AdaptiveQualityMonitor.shared

        // Suspension — checked in the order the user would explain it.
        if settings.isPaused {
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Paused")
        }
        if system.screensAreAsleep {
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Display asleep")
        }
        if !isVisible {
            // The overlay sits below normal windows, so a maximised or full-screen app
            // covers it completely. Rendering underneath it is pure waste.
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Occluded")
        }

        // Frame-rate ceiling.
        var fps = settings.maxFrameRate

        let batteryLow = settings.adaptiveQualityEnabled
            && !system.isCharging
            && (system.batteryPercent ?? 100) <= settings.batteryThreshold

        if settings.lowPowerMode || system.isSystemLowPower || batteryLow {
            // 0 means "display native"; any explicit rate is clamped down to 30.
            fps = fps == 0 ? 30 : min(fps, 30)
        }

        return RenderBudget(
            paused: false,
            minimumInterval: fps > 0 ? 1.0 / Double(fps) : nil,
            suspensionReason: nil
        )
    }
}
