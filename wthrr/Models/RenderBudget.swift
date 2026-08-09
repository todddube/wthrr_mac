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

    /// Computes the budget for one overlay canvas from live app state.
    ///
    /// - Parameters:
    ///   - settings: Current user settings.
    ///   - isVisible: False when the hosting window is fully occluded by other windows.
    @MainActor
    static func current(settings: WeatherSettings, isVisible: Bool) -> RenderBudget {
        let system = AdaptiveQualityMonitor.shared
        return resolve(
            isPaused: settings.isPaused,
            screensAsleep: system.screensAreAsleep,
            isVisible: isVisible,
            maxFrameRate: settings.maxFrameRate,
            appLowPowerMode: settings.lowPowerMode,
            systemLowPowerMode: system.isSystemLowPower,
            adaptiveQualityEnabled: settings.adaptiveQualityEnabled,
            isCharging: system.isCharging,
            batteryPercent: system.batteryPercent,
            batteryThreshold: settings.batteryThreshold
        )
    }

    /// The actual decision, expressed over plain values.
    ///
    /// Kept free of `WeatherSettings` and `AdaptiveQualityMonitor` so it can be tested
    /// directly — those are both `UserDefaults`-backed singletons, and a test that had
    /// to mutate them would be writing to the real app's saved settings.
    static func resolve(
        isPaused: Bool,
        screensAsleep: Bool,
        isVisible: Bool,
        maxFrameRate: Int,
        appLowPowerMode: Bool,
        systemLowPowerMode: Bool,
        adaptiveQualityEnabled: Bool,
        isCharging: Bool,
        batteryPercent: Int?,
        batteryThreshold: Int
    ) -> RenderBudget {
        // Suspension — checked in the order the user would explain it.
        if isPaused {
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Paused")
        }
        if screensAsleep {
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Display asleep")
        }
        if !isVisible {
            // The overlay sits below normal windows, so a maximised or full-screen app
            // covers it completely. Rendering underneath it is pure waste.
            return RenderBudget(paused: true, minimumInterval: nil, suspensionReason: "Occluded")
        }

        // Frame-rate ceiling.
        var fps = maxFrameRate

        let batteryLow = adaptiveQualityEnabled
            && !isCharging
            && (batteryPercent ?? 100) <= batteryThreshold

        if appLowPowerMode || systemLowPowerMode || batteryLow {
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
