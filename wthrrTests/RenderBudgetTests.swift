// RenderBudgetTests.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Testing
@testable import wthrr

// MARK: - Render budget

/// `RenderBudget.resolve` gates every frame wthrr draws, so a mistake here either
/// burns energy forever or leaves the user staring at a frozen overlay.
@Suite("RenderBudget")
struct RenderBudgetTests {

    /// Everything running normally: visible, awake, on AC, no power saving.
    private func resolve(
        isPaused: Bool = false,
        screensAsleep: Bool = false,
        isVisible: Bool = true,
        maxFrameRate: Int = 60,
        appLowPowerMode: Bool = false,
        systemLowPowerMode: Bool = false,
        adaptiveQualityEnabled: Bool = true,
        isCharging: Bool = true,
        batteryPercent: Int? = 100,
        batteryThreshold: Int = 20
    ) -> RenderBudget {
        RenderBudget.resolve(
            isPaused: isPaused,
            screensAsleep: screensAsleep,
            isVisible: isVisible,
            maxFrameRate: maxFrameRate,
            appLowPowerMode: appLowPowerMode,
            systemLowPowerMode: systemLowPowerMode,
            adaptiveQualityEnabled: adaptiveQualityEnabled,
            isCharging: isCharging,
            batteryPercent: batteryPercent,
            batteryThreshold: batteryThreshold
        )
    }

    // MARK: Suspension

    @Test("Rendering suspends when paused, occluded, or the display sleeps")
    func suspensionCases() {
        #expect(resolve(isPaused: true).paused)
        #expect(resolve(screensAsleep: true).paused)
        #expect(resolve(isVisible: false).paused)
    }

    @Test("Each suspension reason is reported distinctly")
    func suspensionReasons() {
        #expect(resolve(isPaused: true).suspensionReason == "Paused")
        #expect(resolve(screensAsleep: true).suspensionReason == "Display asleep")
        #expect(resolve(isVisible: false).suspensionReason == "Occluded")
    }

    @Test("A normally visible overlay renders")
    func visibleOverlayRenders() {
        let budget = resolve()
        #expect(!budget.paused)
        #expect(budget.suspensionReason == nil)
    }

    // MARK: Frame rate

    @Test("The configured cap becomes the minimum frame interval")
    func frameRateCap() {
        #expect(resolve(maxFrameRate: 30).minimumInterval == 1.0 / 30.0)
        #expect(resolve(maxFrameRate: 60).minimumInterval == 1.0 / 60.0)
        #expect(resolve(maxFrameRate: 120).minimumInterval == 1.0 / 120.0)
    }

    @Test("Zero means display native — no interval constraint")
    func displayNative() {
        #expect(resolve(maxFrameRate: 0).minimumInterval == nil)
    }

    @Test("Low power clamps to 30 fps from any setting, including display native")
    func lowPowerClamps() {
        #expect(resolve(maxFrameRate: 120, appLowPowerMode: true).minimumInterval == 1.0 / 30.0)
        #expect(resolve(maxFrameRate: 0, appLowPowerMode: true).minimumInterval == 1.0 / 30.0)
        #expect(resolve(maxFrameRate: 120, systemLowPowerMode: true).minimumInterval == 1.0 / 30.0)
    }

    @Test("Low power never raises a frame rate that is already lower")
    func lowPowerDoesNotRaise() {
        // A user who explicitly asked for 30 should not be pushed anywhere.
        #expect(resolve(maxFrameRate: 30, appLowPowerMode: true).minimumInterval == 1.0 / 30.0)
    }

    // MARK: Battery

    @Test("Low battery on mains power does not throttle")
    func chargingIgnoresBattery() {
        let budget = resolve(maxFrameRate: 120, isCharging: true, batteryPercent: 5)
        #expect(budget.minimumInterval == 1.0 / 120.0)
    }

    @Test("Low battery off mains throttles to 30 fps")
    func lowBatteryThrottles() {
        let budget = resolve(maxFrameRate: 120, isCharging: false, batteryPercent: 10)
        #expect(budget.minimumInterval == 1.0 / 30.0)
    }

    @Test("Battery throttling only applies when adaptive quality is on")
    func batteryRespectsAdaptiveSetting() {
        let budget = resolve(
            maxFrameRate: 120,
            adaptiveQualityEnabled: false,
            isCharging: false,
            batteryPercent: 5
        )
        #expect(budget.minimumInterval == 1.0 / 120.0)
    }

    @Test("A Mac with no battery is never battery-throttled")
    func desktopMacHasNoBattery() {
        let budget = resolve(maxFrameRate: 120, isCharging: false, batteryPercent: nil)
        #expect(budget.minimumInterval == 1.0 / 120.0)
    }

    @Test("Suspension wins over frame-rate settings")
    func suspensionTakesPrecedence() {
        let budget = resolve(isPaused: true, maxFrameRate: 120)
        #expect(budget.paused)
        #expect(budget.minimumInterval == nil)
    }
}
