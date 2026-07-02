// AdaptiveQualityMonitor.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation
import IOKit.ps
import Darwin

// MARK: - Adaptive quality monitor

/// Polls CPU utilisation and battery state every 5 seconds and publishes the
/// results so WeatherAnimationModel can apply a soft particle-count cap when
/// the CPU is over threshold, and a 30 fps frame-rate limit when the battery
/// is below threshold and not charging.
///
/// Usage:
///   AdaptiveQualityMonitor.shared.start()   // called once on launch if enabled
///   AdaptiveQualityMonitor.shared.stop()    // called when feature is disabled
///
/// WeatherAnimationModel reads `cpuUsage`, `batteryPercent`, and `isCharging`
/// directly — the "should throttle" logic lives in the model, not here.
@Observable
@MainActor
final class AdaptiveQualityMonitor {
    static let shared = AdaptiveQualityMonitor()

    /// Latest CPU utilisation across all logical cores, 0.0–1.0.
    /// Updated every poll interval; 0 until the second poll (delta-based).
    private(set) var cpuUsage: Double = 0

    /// Battery percentage (0–100), or nil on desktop Macs with no battery.
    private(set) var batteryPercent: Int? = nil

    /// True when the Mac is on AC power (charging or trickle-charged).
    private(set) var isCharging: Bool = true

    /// Whether the polling loop is currently running.
    var isRunning: Bool { pollTask != nil }

    private var pollTask: Task<Void, Never>?

    /// Per-core tick snapshot from the previous poll, used to compute deltas.
    private var prevTicks: [(user: Double, sys: Double, idle: Double, nice: Double)] = []

    private init() {}

    // MARK: - Lifecycle

    /// Starts the 5-second polling loop. Safe to call multiple times; no-ops if already running.
    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.poll()
            }
        }
    }

    /// Stops the polling loop and resets all published values to neutral.
    func stop() {
        pollTask?.cancel()
        pollTask = nil
        cpuUsage       = 0
        batteryPercent = nil
        isCharging     = true
        prevTicks      = []
    }

    // MARK: - Poll

    private func poll() {
        cpuUsage = measureCPU()
        let batt   = readBattery()
        batteryPercent = batt?.percent
        isCharging     = batt?.isCharging ?? true
    }

    // MARK: - CPU measurement

    /// Returns CPU utilisation across all logical cores as a fraction 0.0–1.0.
    /// Uses the delta between successive `host_processor_info` tick snapshots so
    /// the first call always returns 0 (no previous baseline yet).
    private func measureCPU() -> Double {
        var numCPUs:   natural_t               = 0
        var rawInfo:   processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t  = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &numCPUs, &rawInfo, &infoCount)
        guard kr == KERN_SUCCESS, let info = rawInfo else { return cpuUsage }

        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        // Snapshot all per-core tick counts into a Swift value type.
        var current: [(user: Double, sys: Double, idle: Double, nice: Double)] = []
        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            current.append((
                user: Double(info[base + Int(CPU_STATE_USER)]),
                sys:  Double(info[base + Int(CPU_STATE_SYSTEM)]),
                idle: Double(info[base + Int(CPU_STATE_IDLE)]),
                nice: Double(info[base + Int(CPU_STATE_NICE)])
            ))
        }

        // First call: store baseline and return the previous cached value (0 on first run).
        guard prevTicks.count == current.count else {
            prevTicks = current
            return cpuUsage
        }

        // Delta across all cores since the last poll.
        var totalUsed = 0.0
        var totalAll  = 0.0
        for i in current.indices {
            let dUser = current[i].user - prevTicks[i].user
            let dSys  = current[i].sys  - prevTicks[i].sys
            let dNice = current[i].nice - prevTicks[i].nice
            let dIdle = current[i].idle - prevTicks[i].idle
            let used  = max(0, dUser + dSys + dNice)
            let all   = used + max(0, dIdle)
            totalUsed += used
            totalAll  += all
        }

        prevTicks = current
        return totalAll > 0 ? min(1.0, totalUsed / totalAll) : cpuUsage
    }

    // MARK: - Battery

    private struct BatteryInfo {
        let percent:    Int
        let isCharging: Bool
    }

    /// Reads battery percentage and charging state via IOKit Power Sources API.
    /// Returns nil on desktop Macs or when IOKit reports no internal battery.
    private func readBattery() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as? [String: Any],
                  let type     = desc[kIOPSTypeKey] as? String,
                  type         == kIOPSInternalBatteryType,
                  let capacity = desc[kIOPSCurrentCapacityKey] as? Int
            else { continue }

            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return BatteryInfo(percent: capacity, isCharging: onAC)
        }
        return nil
    }
}
