// AdaptiveQualityMonitor.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import AppKit
import Foundation
import QuartzCore
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

    /// Latest CPU utilisation **by wthrr itself**, expressed as a fraction of one
    /// core's worth of work divided across all logical cores (0.0–1.0), so it is
    /// directly comparable to `cpuThreshold`.
    ///
    /// This deliberately measures our own process rather than the whole machine.
    /// The previous implementation sampled `host_processor_info`, so adaptive quality
    /// fired whenever *anything else* — a build, a browser, a video call — loaded the
    /// CPU, and never fired when wthrr was itself the expensive process. That is
    /// backwards from what the feature promises.
    private(set) var cpuUsage: Double = 0

    /// System-wide CPU utilisation, 0.0–1.0. Retained as a secondary signal so wthrr
    /// can still back off when the machine as a whole is under pressure.
    private(set) var systemCPUUsage: Double = 0

    /// Battery percentage (0–100), or nil on desktop Macs with no battery.
    private(set) var batteryPercent: Int? = nil

    /// True when the Mac is on AC power (charging or trickle-charged).
    private(set) var isCharging: Bool = true

    /// True when macOS itself is in Low Power Mode. Tracked independently of `start()`
    /// and `stop()` so wthrr always honours the system setting, even with adaptive
    /// quality switched off.
    private(set) var isSystemLowPower: Bool = false

    /// True while the displays are asleep. Overlay rendering suspends entirely in
    /// this state — nothing is on screen to see.
    private(set) var screensAreAsleep: Bool = false

    /// Whether the polling loop is currently running.
    var isRunning: Bool { pollTask != nil }

    private var pollTask: Task<Void, Never>?

    /// Notification tokens for the always-on system-state observers.
    private var systemObservers: [NSObjectProtocol] = []

    /// Per-core tick snapshot from the previous poll, used to compute deltas.
    private var prevTicks: [(user: Double, sys: Double, idle: Double, nice: Double)] = []

    private init() {
        isSystemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        observeSystemState()
    }

    // MARK: - Always-on system state

    /// Registers observers for system Low Power Mode and display sleep. These are
    /// independent of `start()`/`stop()` — they cost nothing when idle and both
    /// signals should be honoured regardless of the adaptive quality setting.
    private func observeSystemState() {
        let center = NotificationCenter.default
        systemObservers.append(center.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AdaptiveQualityMonitor.shared.isSystemLowPower =
                    ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        systemObservers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AdaptiveQualityMonitor.shared.screensAreAsleep = true
                PerformanceMonitor.shared.reset()
            }
        })
        systemObservers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AdaptiveQualityMonitor.shared.screensAreAsleep = false
            }
        })
    }

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
        systemCPUUsage = 0
        prevProcessCPUSeconds = 0
        prevProcessSampleTime = 0
        batteryPercent = nil
        isCharging     = true
        prevTicks      = []
    }

    // MARK: - Poll

    private func poll() {
        cpuUsage       = measureOwnCPU()
        systemCPUUsage = measureSystemCPU()
        let batt   = readBattery()
        batteryPercent = batt?.percent
        isCharging     = batt?.isCharging ?? true
    }

    // MARK: - Own-process CPU measurement

    /// Total CPU time consumed by this process at the previous poll, in seconds.
    private var prevProcessCPUSeconds: Double = 0

    /// Wall-clock time of the previous own-CPU sample.
    private var prevProcessSampleTime: CFTimeInterval = 0

    /// Returns wthrr's own CPU utilisation as a fraction of total machine capacity.
    ///
    /// `TASK_BASIC_INFO` reports cumulative CPU time for terminated threads only, so
    /// this walks the live thread list and adds their running totals — that is the
    /// only way to get an accurate figure for a process whose threads are long-lived,
    /// which ours are. The result is normalised by elapsed wall time and core count so
    /// 1.0 means "wthrr is saturating every core".
    private func measureOwnCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else { return cpuUsage }

        defer {
            for i in 0..<Int(threadCount) {
                mach_port_deallocate(mach_task_self_, threads[i])
            }
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: threads)),
                          vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size))
        }

        var totalSeconds = 0.0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            // THREAD_BASIC_INFO_COUNT is a C macro and isn't imported into Swift.
            var count = mach_msg_type_number_t(
                MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size
            )
            let kr = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            guard kr == KERN_SUCCESS, info.flags & TH_FLAGS_IDLE == 0 else { continue }
            totalSeconds += Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
            totalSeconds += Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
        }

        let now = CACurrentMediaTime()
        defer {
            prevProcessCPUSeconds = totalSeconds
            prevProcessSampleTime = now
        }

        // First sample establishes a baseline; there is nothing to diff against yet.
        guard prevProcessSampleTime > 0 else { return 0 }

        let elapsed = now - prevProcessSampleTime
        guard elapsed > 0 else { return cpuUsage }

        let cores = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
        let used = max(0, totalSeconds - prevProcessCPUSeconds)
        return min(1.0, used / elapsed / cores)
    }

    // MARK: - System CPU measurement

    /// Returns CPU utilisation across all logical cores as a fraction 0.0–1.0.
    /// Uses the delta between successive `host_processor_info` tick snapshots so
    /// the first call always returns 0 (no previous baseline yet).
    private func measureSystemCPU() -> Double {
        var numCPUs:   natural_t               = 0
        var rawInfo:   processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t  = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &numCPUs, &rawInfo, &infoCount)
        guard kr == KERN_SUCCESS, let info = rawInfo else { return systemCPUUsage }

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
            return systemCPUUsage
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
        return totalAll > 0 ? min(1.0, totalUsed / totalAll) : systemCPUUsage
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
