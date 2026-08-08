// PerformanceMonitor.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Foundation
import OSLog
import QuartzCore

// MARK: - Performance monitor

/// Measures wthrr's own rendering cost — how long each overlay frame takes and how
/// many frames actually reach the screen — and emits Instruments signposts for the
/// same intervals.
///
/// This is deliberately distinct from `AdaptiveQualityMonitor`, which samples
/// *system-wide* conditions (total CPU, battery). This type measures only the work
/// wthrr itself does, which is the number that matters when tuning the renderer.
///
/// Instruments usage:
///   Profile with the **Time Profiler** or **Animation Hitches** template, then add
///   the **os_signpost** instrument. Intervals are emitted under subsystem
///   `<bundle id>` / category `render` with names `frame` and `physics`.
///
/// Hot-path storage is `@ObservationIgnored` on purpose: recording a sample must not
/// invalidate any SwiftUI view, or the monitor would drive the very redraws it measures.
/// Aggregates are published at most once per second.
@Observable
@MainActor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    // MARK: Published aggregates (recomputed at most once per second)

    /// Median time spent inside one overlay frame (physics + draw), in milliseconds.
    private(set) var frameTimeP50Ms: Double = 0

    /// 99th-percentile frame time in milliseconds — the number that predicts visible hitches.
    private(set) var frameTimeP99Ms: Double = 0

    /// Frames per second actually rendered, averaged per active overlay canvas.
    private(set) var effectiveFPS: Double = 0

    /// Number of overlay canvases that rendered during the last publish window.
    private(set) var activeCanvasCount: Int = 0

    /// Particle count reported by the most recent frame.
    private(set) var particleCount: Int = 0

    /// True once at least one full publish window has elapsed, so the UI can show
    /// a placeholder instead of misleading zeros.
    private(set) var hasData: Bool = false

    // MARK: Signposts

    @ObservationIgnored
    private let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.todddube.wthrr",
        category: "render"
    )

    // MARK: Hot-path storage — never observed, never triggers a redraw

    /// Ring buffer of per-frame durations in milliseconds.
    @ObservationIgnored private var durations = [Double](repeating: 0, count: sampleCapacity)
    @ObservationIgnored private var writeIndex = 0
    @ObservationIgnored private var filled = 0

    @ObservationIgnored private var framesSincePublish = 0
    @ObservationIgnored private var canvasesThisWindow = Set<Int>()
    @ObservationIgnored private var lastPublish: CFTimeInterval = 0
    @ObservationIgnored private var pendingParticleCount = 0

    /// Scratch buffer reused by `publish` so the once-a-second aggregation allocates nothing.
    @ObservationIgnored private var sortScratch = [Double]()

    private static let sampleCapacity = 240

    private init() {
        sortScratch.reserveCapacity(Self.sampleCapacity)
    }

    // MARK: - Frame instrumentation

    /// Opaque handle tying a `beginFrame` call to its matching `endFrame`.
    struct FrameToken {
        fileprivate let interval: OSSignpostIntervalState?
        fileprivate let start: CFTimeInterval
        fileprivate let canvasID: Int
    }

    /// Marks the start of one overlay frame.
    /// - Parameter canvasID: Stable identifier for the calling canvas, so per-canvas
    ///   frame rates can be separated when several displays are active.
    func beginFrame(canvasID: Int) -> FrameToken {
        let interval = signposter.isEnabled
            ? signposter.beginInterval("frame", id: signposter.makeSignpostID())
            : nil
        return FrameToken(interval: interval, start: CACurrentMediaTime(), canvasID: canvasID)
    }

    /// Marks the end of one overlay frame and records its duration.
    func endFrame(_ token: FrameToken, particleCount: Int) {
        let end = CACurrentMediaTime()
        if let interval = token.interval {
            signposter.endInterval("frame", interval)
        }

        durations[writeIndex] = (end - token.start) * 1000
        writeIndex = (writeIndex + 1) % Self.sampleCapacity
        filled = min(filled + 1, Self.sampleCapacity)

        framesSincePublish += 1
        canvasesThisWindow.insert(token.canvasID)
        pendingParticleCount = particleCount

        if lastPublish == 0 {
            lastPublish = end
        } else if end - lastPublish >= 1.0 {
            publish(now: end)
        }
    }

    /// Runs `body` inside a `physics` signpost interval and returns its result.
    /// Separating physics from the enclosing `frame` interval shows, in Instruments,
    /// how the cost splits between simulation and drawing.
    func measurePhysics<T>(_ body: () -> T) -> T {
        guard signposter.isEnabled else { return body() }
        let interval = signposter.beginInterval("physics", id: signposter.makeSignpostID())
        defer { signposter.endInterval("physics", interval) }
        return body()
    }

    // MARK: - Aggregation

    /// Recomputes the published percentiles and frame rate. Called at most once per second.
    private func publish(now: CFTimeInterval) {
        let elapsed = now - lastPublish
        lastPublish = now

        guard filled > 0, elapsed > 0 else { return }

        // Indices 0..<filled always hold the most recent samples: while the ring is
        // filling they are exactly the samples written, and once it has wrapped the
        // whole buffer is the last `sampleCapacity` samples. Order is irrelevant here
        // because we sort.
        sortScratch.removeAll(keepingCapacity: true)
        sortScratch.append(contentsOf: durations[0..<filled])
        sortScratch.sort()

        frameTimeP50Ms = sortScratch[sortScratch.count / 2]
        let p99Index = min(sortScratch.count - 1, Int(Double(sortScratch.count) * 0.99))
        frameTimeP99Ms = sortScratch[p99Index]

        let canvases = max(1, canvasesThisWindow.count)
        effectiveFPS = Double(framesSincePublish) / elapsed / Double(canvases)
        activeCanvasCount = canvases
        particleCount = pendingParticleCount
        hasData = true

        if signposter.isEnabled {
            signposter.emitEvent("stats", "fps=\(self.effectiveFPS, format: .fixed(precision: 1)) p50=\(self.frameTimeP50Ms, format: .fixed(precision: 2))ms p99=\(self.frameTimeP99Ms, format: .fixed(precision: 2))ms canvases=\(canvases) particles=\(self.particleCount)")
        }

        framesSincePublish = 0
        canvasesThisWindow.removeAll(keepingCapacity: true)
    }

    /// Clears all samples and aggregates. Called when rendering suspends so a resumed
    /// overlay doesn't report a frame rate averaged across the idle gap.
    func reset() {
        writeIndex = 0
        filled = 0
        framesSincePublish = 0
        canvasesThisWindow.removeAll(keepingCapacity: true)
        lastPublish = 0
        frameTimeP50Ms = 0
        frameTimeP99Ms = 0
        effectiveFPS = 0
        activeCanvasCount = 0
        hasData = false
    }
}
