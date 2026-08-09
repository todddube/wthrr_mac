// WeatherAnimationModel.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI
import QuartzCore

// MARK: - Weather animation model

/// Drives weather particle physics and manages the per-column accumulation height map
/// and rain effects. The baseline is always the true screen bottom (screenSize.height);
/// snow piles upward from there. The Dock sits above our window level and naturally
/// occludes whatever is behind it.
///
/// Deliberately **not** `@Observable`. Redraws are driven by `WeatherView`'s
/// `TimelineView`, never by observation, so making this type observable would add an
/// Observation registrar access to every property read and write in the frame loop —
/// on the order of hundreds of thousands per second at high particle counts — for no
/// subscribers. `WeatherView` reads these properties from inside a Canvas closure that
/// is already scheduled by the timeline.
///
/// The frame rate at which `advance(settings:)` is called is decided by `RenderBudget`.
@MainActor
final class WeatherAnimationModel {
    private(set) var particles: [Particle] = []
    private var screenSize: CGSize = .zero
    private let wind = WindModel()

    private var lastTime: CFTimeInterval = 0

    /// Timeline tick the simulation was last advanced for. See `advance(settings:tick:)`.
    private var lastTick: Date?

    private var builtCount = 0
    private var builtSeed  = 0
    private var builtSpeed: Double = 0
    private var builtWeatherType: WeatherType?
    /// Tracks whether adaptive quality was throttling particles during the last build.
    /// A change in throttle state (on→off or off→on) triggers a particle rebuild
    /// so the effective count adjusts immediately without waiting for other changes.
    private var builtThrottled: Bool = false

    /// Internal frame counter for periodic operations (smoothing, melting).
    private var frameCount: Int = 0

    /// Current wind velocity exposed for Canvas rain-angle rendering (pts/s).
    private(set) var currentWindVelocity: CGFloat = 0

    // MARK: Rain effects

    /// Short-lived splash effects spawned when raindrops hit the ground.
    private(set) var splashes: [Splash] = []

    /// Persistent puddles that grow during rain + puddles mode.
    private(set) var puddles: [Puddle] = []

    /// Maps a horizontal bucket index to the nearest puddle. See `rebuildPuddleLookup`.
    private var puddleLookup: [Int] = []

    // MARK: Lightning

    /// The currently active lightning bolt, if any. Nil when no strike is in progress.
    private(set) var activeBolt: LightningBolt?

    /// Countdown in seconds until the next lightning strike.
    private var timeUntilNextStrike: CGFloat = 0

    // MARK: AI Storm effects

    /// Active horizontal distortion bands sweeping across the screen.
    private(set) var scanLines: [ScanLine] = []

    /// Active circuit-trace lightning bolts.
    private(set) var dataBolts: [DataBolt] = []

    /// Active rectangular static patches.
    private(set) var corruptionPatches: [CorruptionPatch] = []

    /// Alien ships currently flying across the screen.
    private(set) var alienShips: [AlienShip] = []

    /// Active screen fracture crack patterns.
    private(set) var screenFractures: [ScreenFracture] = []

    /// Countdown in seconds until the next data bolt strike.
    private var timeUntilNextDataBolt: CGFloat = 2.0

    /// Countdown in seconds until the next corruption patch spawns.
    private var timeUntilNextPatch: CGFloat = 1.0

    /// Countdown in seconds until the next screen fracture.
    private var timeUntilNextFracture: CGFloat = 6.0

    /// Frame counter for glitch teleport checks.
    private var glitchFrame: Int = 0

    // MARK: Fog effects

    /// Active fog gradient bands drifting across the screen.
    private(set) var fogBands: [FogBand] = []

    /// Elapsed time for aurora animation, advanced each frame.
    private(set) var auroraTime: CGFloat = 0

    /// Elapsed time for snow-mode animation (frost shimmer), advanced each frame.
    private(set) var snowTime: CGFloat = 0

    /// Elapsed time for clear-sky animation (ray drift, bird flight), advanced each frame.
    private(set) var clearTime: CGFloat = 0

    /// Sun/moon position for the current local time. Recomputed periodically rather
    /// than every frame — the sun moves 0.25° per minute, so reading the calendar
    /// 60 times a second would be pure waste.
    private(set) var sky: SkyState = .current

    /// Frames remaining until `sky` is refreshed.
    private var skyRefreshCountdown: Int = 0

    /// Unit vector pointing from the middle of the screen toward the light source.
    /// `CloudRenderer` uses it to light every cumulus from the same direction as the
    /// sun, which is what keeps the flock looking like one coherent scene.
    var sunDirection: CGPoint {
        let dx = sky.x - 0.5
        let dy = sky.y - 0.5
        let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
        return CGPoint(x: dx / len, y: dy / len)
    }

    // MARK: Clouds

    /// Active clouds drifting across the top of the screen.
    private(set) var clouds: [Cloud] = []

    /// Whether clouds were enabled last frame (to detect toggle changes).
    private var builtCloudsEnabled: Bool = false

    /// Cloud size multiplier last used to build the cloud population.
    private var builtCloudSize: Double = 0

    /// Whether the current cloud population is the large fair-weather kind. Switching
    /// into or out of Clear Skies has to rebuild, since the two styles differ in size,
    /// vertical spread, and opacity.
    private var builtCloudsFairWeather: Bool = false

    // MARK: Accumulation

    /// Column width in points for the height-map grid.
    let columnWidth: CGFloat = 4.0

    /// Accumulated snow height per column, measured upward from the baseline in points.
    private(set) var accumulationMap: [CGFloat] = []

    /// Ground level per column in Canvas coordinates (Y increases downward).
    private(set) var baselineMap: [CGFloat] = []

    /// Reusable destination buffer for `smoothAccumulation`, swapped rather than copied.
    private var smoothScratch: [CGFloat] = []

    private var lastScreenSize: CGSize = .zero

    // MARK: Configuration

    /// Rebuilds the particle array if key parameters changed since the last build.
    /// Detects changes to count, seed, speed, screen size, weather type,
    /// and adaptive quality throttle state.
    func configure(size: CGSize, settings: WeatherSettings) {
        guard size != .zero else { return }

        // Clouds are independent of the particle system — always check
        screenSize = screenSize == .zero ? size : screenSize
        configureClouds(settings: settings)

        // Determine whether adaptive quality is currently throttling particle count.
        //
        // Three independent triggers, in decreasing order of directness:
        //   1. We are missing our own frame budget — the signal that actually
        //      corresponds to visible stutter, measured from wthrr's own frames.
        //   2. wthrr's own CPU share is over the user's threshold.
        //   3. Battery is low and we are not on AC.
        let monitor = AdaptiveQualityMonitor.shared
        let perf = PerformanceMonitor.shared

        // Budget is one frame interval at the configured cap; allow 1.5× before
        // reacting so ordinary jitter doesn't oscillate the particle count.
        let targetFPS = settings.maxFrameRate > 0 ? Double(settings.maxFrameRate) : 60
        let frameBudgetMs = 1000.0 / targetFPS * 1.5
        let missingBudget = perf.hasData && perf.frameTimeP99Ms > frameBudgetMs

        let throttled = settings.adaptiveQualityEnabled && (
            missingBudget ||
            monitor.cpuUsage >= settings.cpuThreshold ||
            (!monitor.isCharging && (monitor.batteryPercent ?? 100) <= settings.batteryThreshold)
        )

        let needsRebuild = particles.isEmpty
            || size != screenSize
            || settings.flakeCount      != builtCount
            || settings.randomSeed      != builtSeed
            || settings.speedMultiplier != builtSpeed
            || settings.weatherType     != builtWeatherType
            || throttled                != builtThrottled

        guard needsRebuild else { return }

        let weatherChanged = settings.weatherType != builtWeatherType

        screenSize       = size
        builtCount       = settings.flakeCount
        builtSeed        = settings.randomSeed
        builtSpeed       = settings.speedMultiplier
        builtWeatherType = settings.weatherType
        builtThrottled   = throttled

        // When throttled, cap particles at 50% of the user-set value so the
        // user's slider position is preserved and restores automatically.
        let effectiveCount = throttled ? max(20, settings.flakeCount / 2) : settings.flakeCount

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(settings.randomSeed)))
        particles = (0..<effectiveCount).map { _ in
            makeParticle(
                startY: CGFloat(rng.next01()) * (size.height + 40) - 40,
                rng: &rng,
                weatherType: settings.weatherType
            )
        }

        if weatherChanged {
            clearRainEffects()
            clearAccumulation()
            clearAIStormEffects()
            clearFogEffects()
        }

        if settings.weatherType == .rain && puddles.isEmpty {
            initializePuddles()
        }

        if settings.weatherType == .thunderstorm && puddles.isEmpty {
            initializePuddles()
        }

        if settings.weatherType == .aiStorm && scanLines.isEmpty {
            initializeScanLines()
        }

        if settings.weatherType == .fog && fogBands.isEmpty {
            initializeFogBands()
        }

        rebuildBaseline()
    }

    // MARK: Accumulation helpers

    /// Fills the baseline and (if needed) the accumulation map.
    /// Every column's baseline is screenSize.height — the absolute screen floor.
    private func rebuildBaseline() {
        guard screenSize != .zero else { return }
        let count = max(1, Int(ceil(screenSize.width / columnWidth)))
        let h     = screenSize.height

        if accumulationMap.count != count {
            accumulationMap = Array(repeating: 0, count: count)
        }
        baselineMap = Array(repeating: h, count: count)
        lastScreenSize = screenSize
    }

    /// Zeros all accumulated snow. Called when the toggle is turned off or weather type changes.
    func clearAccumulation() {
        for i in accumulationMap.indices { accumulationMap[i] = 0 }
    }

    /// Box-blur pass to smooth the snow surface. Called every 30 frames.
    ///
    /// Uses a persistent scratch buffer rather than copying the height map each pass —
    /// on a 6K display that map is ~1500 elements and this ran every half second.
    private func smoothAccumulation() {
        let n = accumulationMap.count
        guard n > 2 else { return }

        if smoothScratch.count != n {
            smoothScratch = accumulationMap
        } else {
            smoothScratch.withUnsafeMutableBufferPointer { dst in
                accumulationMap.withUnsafeBufferPointer { src in
                    dst[0] = src[0]
                    dst[n - 1] = src[n - 1]
                }
            }
        }

        accumulationMap.withUnsafeBufferPointer { src in
            smoothScratch.withUnsafeMutableBufferPointer { dst in
                for i in 1..<(n - 1) {
                    dst[i] = (src[i - 1] + src[i] * 2 + src[i + 1]) / 4
                }
            }
        }
        swap(&accumulationMap, &smoothScratch)
    }

    // MARK: Rain effect helpers

    /// Empties the splashes and puddles arrays. Called when switching weather types.
    func clearRainEffects() {
        splashes.removeAll()
        puddles.removeAll()
        puddleLookup.removeAll()
    }

    /// Populates the puddles array with 8-12 randomly placed puddles across the screen width.
    private func initializePuddles() {
        guard screenSize != .zero else { return }
        let count = Int.random(in: 8...12)
        puddles = (0..<count).map { _ in
            let w = CGFloat.random(in: 80...220)
            return Puddle(
                x:             CGFloat.random(in: w / 2...(screenSize.width - w / 2)),
                width:         w,
                height:        0,
                opacity:       Double.random(in: 0.55...0.80),
                rippleRadius:  0,
                rippleOpacity: 0
            )
        }
        rebuildPuddleLookup()
    }

    /// Width in points of one nearest-puddle lookup bucket.
    private static let puddleBucketWidth: CGFloat = 24

    /// Precomputes the nearest puddle for each horizontal bucket across the screen.
    ///
    /// Puddles never move once placed, so the nearest-puddle answer is fixed. Finding
    /// it with a linear scan per landing raindrop meant an O(puddles) search hundreds
    /// of times a second during heavy rain; this turns it into one array index.
    private func rebuildPuddleLookup() {
        guard !puddles.isEmpty, screenSize.width > 0 else {
            puddleLookup = []
            return
        }
        let buckets = max(1, Int(ceil(screenSize.width / Self.puddleBucketWidth)))
        puddleLookup = (0..<buckets).map { b in
            let x = (CGFloat(b) + 0.5) * Self.puddleBucketWidth
            var best = 0
            var bestDist = CGFloat.greatestFiniteMagnitude
            for (i, p) in puddles.enumerated() {
                let d = abs(p.x - x)
                if d < bestDist { bestDist = d; best = i }
            }
            return best
        }
    }

    // MARK: Physics

    /// Advances all particle positions by one frame.
    /// Handles snow accumulation, rain splashes, and puddle growth depending on settings.
    ///
    /// Frame pacing is *not* handled here. `RenderBudget` decides the timeline's
    /// `minimumInterval`, so low-power and battery throttling now reduce actual redraws
    /// rather than merely skipping physics between full-rate draws. `dt` is always
    /// measured from the wall clock and clamped, so this function is correct at any rate.
    ///
    /// - Parameter tick: The timeline date this frame belongs to. Repeated calls with
    ///   the same tick are ignored, so physics cannot double-step if SwiftUI evaluates
    ///   the Canvas closure more than once per frame.
    func advance(settings: WeatherSettings, tick: Date) {
        guard tick != lastTick else { return }
        lastTick = tick

        let now = CACurrentMediaTime()

        // Paused: keep lastTime current so we don't get a huge dt spike on resume
        if settings.isPaused { lastTime = now; return }

        let dt: CGFloat = lastTime == 0 ? 1.0 / 60.0 : CGFloat(min(now - lastTime, 1.0 / 20.0))
        lastTime = now

        // Refresh the solar arc roughly every 20 seconds at 60 fps. Clear Skies needs
        // it; the other scenes never read it, so it costs nothing to keep current.
        skyRefreshCountdown -= 1
        if skyRefreshCountdown <= 0 {
            sky = .current
            skyRefreshCountdown = 1200
        }

        let speedScale = CGFloat(settings.speedMultiplier)
        let windScale  = CGFloat(settings.windStrength)
        let time       = CGFloat(now)
        let isRain     = settings.weatherType == .rain || settings.weatherType == .thunderstorm
        wind.update(dt: dt, strength: windScale)
        switch settings.windDirection {
        case .left:    currentWindVelocity = -abs(wind.velocity)
        case .right:   currentWindVelocity =  abs(wind.velocity)
        case .natural: currentWindVelocity = wind.velocity
        }

        let accumulating = settings.accumulationEnabled && !accumulationMap.isEmpty
        let maxAccumH    = min(CGFloat(settings.maxAccumulationHeight), screenSize.height * 0.20)

        // Hoist everything loop-invariant out of the per-particle body. `windAngle`
        // in particular was being converted to radians and passed through sin/cos on
        // every single particle, every frame.
        // windAngle rotates the fall vector: 0° = straight down, positive = tilt right.
        // cos(angle) projects onto the Y axis (downward), sin(angle) onto X (rightward).
        let angleRad     = CGFloat(settings.windAngle) * .pi / 180
        let fallY        = cos(angleRad)
        let fallX        = sin(angleRad)
        let wind         = currentWindVelocity
        let weatherType  = settings.weatherType
        let screenW      = screenSize.width
        let screenH      = screenSize.height
        let wrapLeft: CGFloat  = -30
        let wrapRight: CGFloat = screenW + 30

        // Direct buffer access avoids a class-property lookup and a copy-on-write
        // uniqueness check on every one of the ~10 subscript operations below.
        // Guarded rather than early-returning from `advance` so that clouds, lightning,
        // and the sky clock keep running even when the particle array is empty.
        if !particles.isEmpty {
        particles.withUnsafeMutableBufferPointer { buf in
            for i in buf.indices {
                let step = buf[i].fallSpeed * speedScale * dt
                buf[i].y += step * fallY
                buf[i].x += step * fallX
                // Wind adds a per-particle lateral nudge weighted by windSensitivity
                buf[i].x += wind * buf[i].windSensitivity * speedScale * dt
                // Sinusoidal wobble creates the characteristic side-to-side swaying motion
                buf[i].x += sin(time * buf[i].wobbleFreq + buf[i].wobblePhase)
                                * buf[i].wobbleAmp * dt
                // Slowly spin the crystal (snow and AI storm only; 0 for rain)
                buf[i].rotation += buf[i].rotationSpeed * dt

                switch weatherType {
                case .rain, .thunderstorm:
                    advanceRainParticle(&buf[i], accumulating: accumulating)
                case .aiStorm:
                    advanceAIStormParticle(&buf[i])
                case .fog, .aurora:
                    if buf[i].y > screenH + 40 {
                        buf[i].y = -40
                        buf[i].x = CGFloat.random(in: 0...screenW)
                    }
                case .clear:
                    // Motes wrap in both directions — a third of them rise on thermals.
                    if buf[i].y > screenH + 20 {
                        buf[i].y = -20
                        buf[i].x = CGFloat.random(in: 0...screenW)
                    } else if buf[i].y < -20 {
                        buf[i].y = screenH + 20
                        buf[i].x = CGFloat.random(in: 0...screenW)
                    }
                case .snow:
                    advanceSnowParticle(&buf[i], accumulating: accumulating, maxAccumH: maxAccumH)
                }

                // Wrap horizontally when a particle drifts off screen
                if buf[i].x < wrapLeft {
                    buf[i].x = wrapRight
                } else if buf[i].x > wrapRight {
                    buf[i].x = wrapLeft
                }
            }
        }
        }

        ageSplashes(dt: dt)
        advancePuddleRipples(dt: dt)

        // Advance fog bands
        if settings.weatherType == .fog {
            for i in fogBands.indices {
                fogBands[i].y += fogBands[i].speed * dt
                if fogBands[i].y > screenSize.height + fogBands[i].height {
                    fogBands[i].y = -fogBands[i].height
                }
            }
        }

        if (isRain && settings.lightningEnabled) || settings.weatherType == .thunderstorm {
            advanceLightning(dt: dt)
        }

        if settings.weatherType == .aiStorm {
            advanceAIStormEffects(dt: dt)
        }

        if settings.weatherType == .snow && accumulating && frameCount % 30 == 0 { smoothAccumulation() }
        if settings.weatherType == .snow && accumulating && frameCount % 4 == 0 { meltExcessSnow(maxAccumH: maxAccumH) }

        advanceClouds(dt: dt)

        // Advance aurora/snow timers
        if settings.weatherType == .aurora {
            auroraTime += dt
        }
        if settings.weatherType == .snow {
            snowTime += dt
        }
        if settings.weatherType == .clear {
            clearTime += dt
        }

        frameCount &+= 1
    }

    // MARK: Rain physics

    /// Handles a single raindrop hitting the ground: spawns a splash, grows the
    /// nearest puddle, and recycles the drop to the top of the screen.
    ///
    /// Takes the particle `inout` rather than by index so the caller can hold a direct
    /// buffer pointer for the whole frame loop.
    private func advanceRainParticle(_ p: inout Particle, accumulating: Bool) {
        let groundY = screenSize.height
        guard p.y + p.length >= groundY else { return }

        // Spawn a splash at impact point
        splashes.append(Splash(
            x:        p.x,
            y:        groundY,
            radius:   0,
            opacity:  Double.random(in: 0.5...0.8),
            age:      0,
            lifetime: CGFloat.random(in: 0.2...0.4)
        ))

        // Grow nearest puddle and trigger a ripple if puddles mode is enabled
        if accumulating && !puddleLookup.isEmpty {
            let bucket = min(puddleLookup.count - 1,
                             max(0, Int(p.x / Self.puddleBucketWidth)))
            let idx = puddleLookup[bucket]
            if abs(puddles[idx].x - p.x) < puddles[idx].width * 0.65 {
                puddles[idx].height = min(puddles[idx].height + 0.025, 18.0)
                if puddles[idx].rippleOpacity < 0.1 {
                    puddles[idx].rippleRadius  = 2
                    puddles[idx].rippleOpacity = 0.75
                }
            }
        }

        // Recycle drop to top of screen
        p.y = -(p.length + 2)
        p.x = CGFloat.random(in: -20...(screenSize.width + 20))
    }

    // MARK: Snow physics

    /// Handles a single snowflake landing: deposits snow into the accumulation map
    /// and recycles the flake to the top of the screen.
    private func advanceSnowParticle(_ p: inout Particle, accumulating: Bool, maxAccumH: CGFloat) {
        if accumulating {
            let col      = min(max(0, Int(p.x / columnWidth)), accumulationMap.count - 1)
            let landingY = baselineMap[col] - accumulationMap[col]

            if p.y + p.size >= landingY {
                let deposit = p.size * 0.35
                for offset in -1...1 {
                    let c = col + offset
                    guard c >= 0 && c < accumulationMap.count else { continue }
                    let amount = offset == 0 ? deposit : deposit * 0.3
                    accumulationMap[c] = min(accumulationMap[c] + amount, maxAccumH)
                }
                p.y = -(p.size + 2)
                p.x = CGFloat.random(in: -20...(screenSize.width + 20))
            }
        } else {
            if p.y > screenSize.height + p.size + 2 {
                p.y = -(p.size + 2)
                p.x = CGFloat.random(in: -20...(screenSize.width + 20))
            }
        }
    }

    // MARK: Effect updates

    /// Ages all active splashes, expanding their radius and fading opacity.
    /// Removes splashes that have exceeded their lifetime.
    ///
    /// Ages in place, then compacts in a single `removeAll(where:)` pass. The previous
    /// reversed loop called `remove(at:)` per expired splash, each of which shifts the
    /// tail of the array — quadratic behaviour exactly when it hurts most, since heavy
    /// rain spawns and expires hundreds of splashes a second.
    private func ageSplashes(dt: CGFloat) {
        guard !splashes.isEmpty else { return }

        splashes.withUnsafeMutableBufferPointer { buf in
            for i in buf.indices {
                buf[i].age += dt
                let progress = buf[i].age / buf[i].lifetime
                buf[i].radius  = progress * 18
                buf[i].opacity = Double(1 - progress) * 0.85
            }
        }
        splashes.removeAll { $0.age >= $0.lifetime }
    }

    /// Expands and fades active puddle ripple rings.
    private func advancePuddleRipples(dt: CGFloat) {
        for i in puddles.indices where puddles[i].rippleOpacity > 0 {
            puddles[i].rippleRadius  += dt * 40
            puddles[i].rippleOpacity  = max(0, puddles[i].rippleOpacity - dt * 2.5)
        }
    }

    /// Gradually reduces accumulation near and above the cap so the drift surface
    /// breathes at a steady-state depth rather than freezing solid.
    private func meltExcessSnow(maxAccumH: CGFloat) {
        let meltRate: CGFloat = CGFloat(WeatherSettings.shared.snowMeltRate)
        for i in accumulationMap.indices {
            let excess = accumulationMap[i] - maxAccumH
            if excess >= 0 {
                accumulationMap[i] = max(0, accumulationMap[i] - meltRate)
            } else if excess > -8 {
                accumulationMap[i] = max(0, accumulationMap[i] - meltRate * 0.3)
            }
        }
    }

    // MARK: AI Storm physics

    /// Wraps an AI storm particle that has gone off-screen (including upward-movers).
    private func advanceAIStormParticle(_ p: inout Particle) {
        // Wrap vertically for both upward and downward movement
        if p.y > screenSize.height + 20 {
            p.y = -20
            p.x = CGFloat.random(in: -20...(screenSize.width + 20))
        } else if p.y < -30 {
            p.y = screenSize.height + 10
            p.x = CGFloat.random(in: -20...(screenSize.width + 20))
        }

        // Occasional glitch teleport — a sudden jump to a nearby position
        glitchFrame &+= 1
        if glitchFrame % 7 == 0 && CGFloat.random(in: 0...1) < 0.02 {
            p.x += CGFloat.random(in: -60...60)
            p.y += CGFloat.random(in: -40...40)
        }
    }

    /// Advances all AI storm secondary effects: scan lines, data bolts, corruption patches.
    private func advanceAIStormEffects(dt: CGFloat) {
        // Advance scan lines
        for i in scanLines.indices {
            scanLines[i].y += scanLines[i].speed * dt
        }
        // Wrap scan lines that fall off the bottom back to the top
        for i in scanLines.indices where scanLines[i].y > screenSize.height + 10 {
            scanLines[i] = ScanLine(
                y: -CGFloat.random(in: 5...40),
                speed: CGFloat.random(in: 80...250),
                width: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.15...0.40),
                colorIndex: Int.random(in: 0...3)
            )
        }

        // Advance data bolts
        for i in dataBolts.indices.reversed() {
            dataBolts[i].age += dt
            // Fade flash
            let progress = dataBolts[i].age / dataBolts[i].lifetime
            if progress < 0.1 {
                dataBolts[i].flashOpacity = Double(1.0 - progress / 0.1) * 0.15
            } else {
                dataBolts[i].flashOpacity = 0
            }
            if dataBolts[i].age >= dataBolts[i].lifetime {
                dataBolts.remove(at: i)
            }
        }
        // Spawn new data bolts
        timeUntilNextDataBolt -= dt
        if timeUntilNextDataBolt <= 0 && dataBolts.count < 2 {
            dataBolts.append(spawnDataBolt())
            let d = CGFloat(WeatherSettings.shared.aiStormDensity)
            timeUntilNextDataBolt = CGFloat.random(in: 3...10) / d
        }

        // Advance corruption patches
        let corruptionEnabled = WeatherSettings.shared.accumulationEnabled
        for i in corruptionPatches.indices.reversed() {
            corruptionPatches[i].age += dt
            if corruptionPatches[i].age >= corruptionPatches[i].lifetime {
                corruptionPatches.remove(at: i)
            }
        }
        // Spawn new patches if corruption mode is on
        if corruptionEnabled {
            timeUntilNextPatch -= dt
            if timeUntilNextPatch <= 0 && corruptionPatches.count < 5 {
                corruptionPatches.append(spawnCorruptionPatch())
                let d2 = CGFloat(WeatherSettings.shared.aiStormDensity)
                timeUntilNextPatch = CGFloat.random(in: 0.3...1.5) / d2
            }
        }

        // Advance alien ships — steer toward target, update trail
        advanceAlienShips(dt: dt)

        // Advance screen fractures
        advanceScreenFractures(dt: dt)
    }

    /// Initializes 2-4 scan lines at random vertical positions.
    private func initializeScanLines() {
        guard screenSize != .zero else { return }
        let count = Int.random(in: 2...4)
        scanLines = (0..<count).map { _ in
            ScanLine(
                y: CGFloat.random(in: 0...screenSize.height),
                speed: CGFloat.random(in: 80...250),
                width: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.15...0.40),
                colorIndex: Int.random(in: 0...3)
            )
        }
    }

    /// Creates a circuit-trace data bolt with right-angle segments.
    private func spawnDataBolt() -> DataBolt {
        guard screenSize != .zero else {
            return DataBolt(segments: [], lifetime: 0.01, flashOpacity: 0, colorIndex: 0)
        }
        let segmentCount = Int.random(in: 6...12)
        let startX = CGFloat.random(in: screenSize.width * 0.1...screenSize.width * 0.9)
        let startY = CGFloat.random(in: 0...screenSize.height * 0.1)
        let endY = CGFloat.random(in: screenSize.height * 0.5...screenSize.height * 0.9)

        var points: [CGPoint] = []
        var x = startX
        var y = startY
        points.append(CGPoint(x: x, y: y))

        let totalDropY = endY - startY
        var isHorizontal = true  // Alternate between horizontal and vertical moves

        for _ in 0..<segmentCount {
            if isHorizontal {
                // Horizontal segment
                x += CGFloat.random(in: -80...80)
                x = max(10, min(screenSize.width - 10, x))
            } else {
                // Vertical segment — always moves downward
                y += totalDropY / CGFloat(segmentCount / 2 + 1) * CGFloat.random(in: 0.5...1.5)
                y = min(endY, y)
            }
            points.append(CGPoint(x: x, y: y))
            isHorizontal.toggle()
        }

        return DataBolt(
            segments: points,
            lifetime: CGFloat.random(in: 0.25...0.40),
            flashOpacity: 0.15,
            colorIndex: Int.random(in: 0...2)
        )
    }

    /// Creates a corruption patch at a random screen position.
    private func spawnCorruptionPatch() -> CorruptionPatch {
        CorruptionPatch(
            x: CGFloat.random(in: 0...max(1, screenSize.width - 80)),
            y: CGFloat.random(in: 0...max(1, screenSize.height - 16)),
            width: CGFloat.random(in: 20...80),
            height: CGFloat.random(in: 4...16),
            lifetime: CGFloat.random(in: 0.15...0.5),
            colorIndex: Int.random(in: 0...3)
        )
    }

    // MARK: Alien ship physics

    /// Steers alien ships toward their targets, updates trails, and manages the fleet.
    /// Ships smoothly accelerate toward a wandering target point, creating organic
    /// curved flight paths. When a ship reaches its target or the timer expires,
    /// a new target is picked — occasionally off-screen for fly-through behaviour.
    private func advanceAlienShips(dt: CGFloat) {
        guard screenSize != .zero else { return }

        // Maintain 2-4 ships
        while alienShips.count < 2 {
            alienShips.append(spawnAlienShip())
        }
        if alienShips.count < 4 && CGFloat.random(in: 0...1) < 0.001 {
            alienShips.append(spawnAlienShip())
        }

        for i in alienShips.indices {
            // Steer toward target
            let dx = alienShips[i].targetX - alienShips[i].x
            let dy = alienShips[i].targetY - alienShips[i].y
            let dist = sqrt(dx * dx + dy * dy)
            let steer: CGFloat = 2.5
            if dist > 5 {
                alienShips[i].vx += (dx / dist) * steer
                alienShips[i].vy += (dy / dist) * steer
            }

            // Clamp to max speed
            let spd = sqrt(alienShips[i].vx * alienShips[i].vx + alienShips[i].vy * alienShips[i].vy)
            let maxSpd = alienShips[i].speed
            if spd > maxSpd {
                alienShips[i].vx = alienShips[i].vx / spd * maxSpd
                alienShips[i].vy = alienShips[i].vy / spd * maxSpd
            }

            // Move
            alienShips[i].x += alienShips[i].vx * dt
            alienShips[i].y += alienShips[i].vy * dt

            // Update trail (keep last 12 positions, newest first).
            // Left as a front-insert: at 12 entries across 2–4 ships this is a few
            // dozen element moves per frame, far below the noise floor, and a ring
            // buffer here would leak an index into `AlienShip` and its renderer.
            alienShips[i].trail.insert((alienShips[i].x, alienShips[i].y), at: 0)
            if alienShips[i].trail.count > 12 {
                alienShips[i].trail.removeLast()
            }

            // Pick new target when close or timer expires
            alienShips[i].timeUntilRetarget -= dt
            if dist < 30 || alienShips[i].timeUntilRetarget <= 0 {
                alienShips[i].targetX = CGFloat.random(in: -50...(screenSize.width + 50))
                alienShips[i].targetY = CGFloat.random(in: -50...(screenSize.height + 50))
                alienShips[i].timeUntilRetarget = CGFloat.random(in: 2...6)
            }

            // Wrap ships that drift too far off-screen
            let margin: CGFloat = 120
            if alienShips[i].x < -margin || alienShips[i].x > screenSize.width + margin ||
               alienShips[i].y < -margin || alienShips[i].y > screenSize.height + margin {
                alienShips[i].x = CGFloat.random(in: 0...screenSize.width)
                alienShips[i].y = CGFloat.random(in: 0...screenSize.height)
                alienShips[i].trail.removeAll()
            }
        }
    }

    /// Creates an alien ship at a random edge of the screen flying inward.
    private func spawnAlienShip() -> AlienShip {
        let edge = Int.random(in: 0...3) // 0=top, 1=right, 2=bottom, 3=left
        let x: CGFloat
        let y: CGFloat
        switch edge {
        case 0:  x = CGFloat.random(in: 0...screenSize.width);  y = -20
        case 1:  x = screenSize.width + 20; y = CGFloat.random(in: 0...screenSize.height)
        case 2:  x = CGFloat.random(in: 0...screenSize.width);  y = screenSize.height + 20
        default: x = -20; y = CGFloat.random(in: 0...screenSize.height)
        }
        let targetX = CGFloat.random(in: screenSize.width * 0.2...screenSize.width * 0.8)
        let targetY = CGFloat.random(in: screenSize.height * 0.2...screenSize.height * 0.8)
        return AlienShip(
            x: x, y: y,
            vx: 0, vy: 0,
            targetX: targetX, targetY: targetY,
            timeUntilRetarget: CGFloat.random(in: 2...5),
            size: CGFloat.random(in: 8...16),
            colorIndex: Int.random(in: 0...3),
            speed: CGFloat.random(in: 60...180),
            trail: []
        )
    }

    // MARK: Screen fracture physics

    /// Ages active fractures and spawns new ones on a timer.
    private func advanceScreenFractures(dt: CGFloat) {
        // Age existing fractures
        for i in screenFractures.indices.reversed() {
            screenFractures[i].age += dt
            let progress = screenFractures[i].age / screenFractures[i].lifetime
            if progress < 0.08 {
                screenFractures[i].flashOpacity = Double(1.0 - progress / 0.08) * 0.5
            } else {
                screenFractures[i].flashOpacity = 0
            }
            if screenFractures[i].age >= screenFractures[i].lifetime {
                screenFractures.remove(at: i)
            }
        }

        // Spawn new fractures
        timeUntilNextFracture -= dt
        if timeUntilNextFracture <= 0 && screenFractures.count < 3 {
            screenFractures.append(spawnScreenFracture())
            let d3 = CGFloat(WeatherSettings.shared.aiStormDensity)
            timeUntilNextFracture = CGFloat.random(in: 5...15) / d3
        }
    }

    /// Creates a screen fracture with 5-8 jagged arms radiating from a random impact point.
    /// Each arm has 4-7 segments that zigzag outward with decreasing amplitude.
    private func spawnScreenFracture() -> ScreenFracture {
        guard screenSize != .zero else {
            return ScreenFracture(origin: .zero, arms: [], lifetime: 0.01, colorIndex: 0, flashOpacity: 0)
        }
        let origin = CGPoint(
            x: CGFloat.random(in: screenSize.width * 0.1...screenSize.width * 0.9),
            y: CGFloat.random(in: screenSize.height * 0.1...screenSize.height * 0.9)
        )
        let armCount = Int.random(in: 5...8)
        var arms: [[CGPoint]] = []

        for i in 0..<armCount {
            // Base angle evenly spaced with some jitter
            let baseAngle = (CGFloat(i) / CGFloat(armCount)) * 2 * .pi + CGFloat.random(in: -0.3...0.3)
            let segCount = Int.random(in: 4...7)
            var points: [CGPoint] = [origin]
            var currentAngle = baseAngle
            var reach: CGFloat = 0

            for seg in 0..<segCount {
                // Each segment gets longer as it radiates outward
                let segLen = CGFloat.random(in: 15...45) * (1.0 + CGFloat(seg) * 0.15)
                reach += segLen
                currentAngle += CGFloat.random(in: -0.4...0.4)
                let nx = points.last!.x + cos(currentAngle) * segLen
                let ny = points.last!.y + sin(currentAngle) * segLen
                points.append(CGPoint(x: nx, y: ny))
            }
            arms.append(points)
        }

        return ScreenFracture(
            origin: origin,
            arms: arms,
            lifetime: CGFloat.random(in: 2.0...4.0),
            colorIndex: Int.random(in: 0...3),
            flashOpacity: 0.5
        )
    }

    // MARK: Fog effect helpers

    /// Populates the fog bands array with 5-8 translucent gradient bands.
    private func initializeFogBands() {
        guard screenSize != .zero else { return }
        fogBands = (0..<Int.random(in: 5...8)).map { _ in
            FogBand(
                y: CGFloat.random(in: 0...screenSize.height),
                height: CGFloat.random(in: 60...200),
                speed: CGFloat.random(in: 3...12),
                opacity: Double.random(in: 0.06...0.18),
                phase: CGFloat.random(in: 0...(.pi * 2))
            )
        }
    }

    /// Empties the fog bands array. Called when switching to a different weather type.
    func clearFogEffects() {
        fogBands.removeAll()
    }

    /// No-op — aurora has no persistent secondary effects to tear down.
    /// Exists for symmetry with the other `clear*` methods and to make
    /// `WeatherView`'s `.onChange(of: weatherType)` cleaner.
    func clearAuroraEffects() {
        // Aurora has no persistent effects to clear
    }

    /// Empties all AI storm effect arrays.
    func clearAIStormEffects() {
        scanLines.removeAll()
        dataBolts.removeAll()
        corruptionPatches.removeAll()
        alienShips.removeAll()
        screenFractures.removeAll()
    }

    // MARK: Lightning

    /// Advances the lightning timer, spawns new bolts, and ages the active bolt.
    /// Produces a brief screen flash followed by a jagged bolt that fades out.
    private func advanceLightning(dt: CGFloat) {
        // Age the active bolt
        if var bolt = activeBolt {
            bolt.age += dt
            // Double-flash effect: a quick re-flash at 40% of lifetime
            let progress = bolt.age / bolt.lifetime
            if progress < 0.12 {
                bolt.flashOpacity = Double(1.0 - progress / 0.12) * 0.3
            } else if progress > 0.35 && progress < 0.45 {
                bolt.flashOpacity = Double(1.0 - (progress - 0.35) / 0.10) * 0.12
            } else {
                bolt.flashOpacity = 0
            }
            if bolt.age >= bolt.lifetime {
                activeBolt = nil
            } else {
                activeBolt = bolt
            }
        }

        // Count down to the next strike
        timeUntilNextStrike -= dt
        if timeUntilNextStrike <= 0 && activeBolt == nil {
            activeBolt = spawnBolt()
            timeUntilNextStrike = CGFloat.random(in: 8...25) / CGFloat(WeatherSettings.shared.lightningFrequency)
        }
    }

    /// Creates a new lightning bolt with a jagged path from near the top to the
    /// lower portion of the screen. The bolt has 10-16 segments with random
    /// lateral offsets for a natural zigzag appearance.
    private func spawnBolt() -> LightningBolt {
        guard screenSize != .zero else {
            return LightningBolt(segments: [], lifetime: 0.01, flashOpacity: 0)
        }
        let segmentCount = Int.random(in: 10...16)
        let startX = CGFloat.random(in: screenSize.width * 0.15...screenSize.width * 0.85)
        let startY: CGFloat = CGFloat.random(in: 0...screenSize.height * 0.05)
        let endY = CGFloat.random(in: screenSize.height * 0.55...screenSize.height * 0.85)
        let stepY = (endY - startY) / CGFloat(segmentCount)

        var points: [CGPoint] = []
        var x = startX
        var y = startY
        points.append(CGPoint(x: x, y: y))

        for i in 1...segmentCount {
            y += stepY
            // Wider zigzags in the middle, tighter at the ends
            let midFactor = 1.0 - abs(CGFloat(i) / CGFloat(segmentCount) - 0.5) * 2.0
            let maxOffset = 25.0 + midFactor * 40.0
            x += CGFloat.random(in: -maxOffset...maxOffset)
            // Keep bolt on screen
            x = max(20, min(screenSize.width - 20, x))
            points.append(CGPoint(x: x, y: y))
        }

        return LightningBolt(
            segments: points,
            lifetime: CGFloat.random(in: 0.30...0.45),
            flashOpacity: 0.3
        )
    }

    // MARK: Cloud management

    /// Builds or tears down the cloud population based on the clouds-enabled setting.
    private func configureClouds(settings: WeatherSettings) {
        guard screenSize != .zero else { return }

        let isClear = settings.weatherType == .clear
        // Clear Skies always has clouds — they are the scene, not an optional garnish.
        let cloudsNeeded = settings.cloudsEnabled || settings.weatherType == .thunderstorm || isClear
        if !cloudsNeeded {
            if !clouds.isEmpty { clouds.removeAll() }
            builtCloudsEnabled = false
            return
        }

        let needsRebuild = !builtCloudsEnabled
            || clouds.isEmpty
            || settings.cloudSize != builtCloudSize
            || isClear != builtCloudsFairWeather

        guard needsRebuild else { return }
        builtCloudsEnabled = true
        builtCloudSize = settings.cloudSize
        builtCloudsFairWeather = isClear

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(settings.randomSeed &+ 7777)))
        if isClear {
            let count = Int(rng.next(in: 4...Double(CloudFactory.maxFairWeatherClouds)))
            clouds = (0..<count).map { _ in
                CloudFactory.makeFairWeatherCloud(
                    screenWidth: screenSize.width,
                    screenHeight: screenSize.height,
                    sizeMultiplier: settings.cloudSize,
                    startOffScreen: false,
                    rng: &rng
                )
            }
        } else {
            let count = Int.random(in: 3...CloudFactory.maxClouds)
            clouds = (0..<count).map { _ in
                CloudFactory.makeCloud(
                    screenWidth: screenSize.width,
                    sizeMultiplier: settings.cloudSize,
                    startOffScreen: false,
                    rng: &rng
                )
            }
        }
    }

    /// Moves clouds rightward each frame and recycles ones that drift off-screen.
    private func advanceClouds(dt: CGFloat) {
        guard !clouds.isEmpty else { return }
        let settings = WeatherSettings.shared
        let isClear = settings.weatherType == .clear
        guard settings.cloudsEnabled || settings.weatherType == .thunderstorm || isClear else { return }

        for i in clouds.indices {
            clouds[i].x += clouds[i].speed * CGFloat(settings.cloudSpeed) * dt
        }

        // Recycle clouds that have fully exited the right edge
        for i in clouds.indices {
            if clouds[i].x - clouds[i].width / 2 > screenSize.width {
                var rng = SeededRNG(seed: UInt64(CACurrentMediaTime().bitPattern) &+ UInt64(i))
                clouds[i] = isClear
                    ? CloudFactory.makeFairWeatherCloud(
                        screenWidth: screenSize.width,
                        screenHeight: screenSize.height,
                        sizeMultiplier: settings.cloudSize,
                        startOffScreen: true,
                        rng: &rng
                    )
                    : CloudFactory.makeCloud(
                        screenWidth: screenSize.width,
                        sizeMultiplier: settings.cloudSize,
                        startOffScreen: true,
                        rng: &rng
                    )
            }
        }
    }

    // MARK: Factory

    /// Dispatches to the appropriate factory based on the active weather type.
    private func makeParticle(startY: CGFloat, rng: inout SeededRNG, weatherType: WeatherType) -> Particle {
        switch weatherType {
        case .rain:
            return RainParticleFactory.makeRaindrop(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .thunderstorm:
            return RainParticleFactory.makeRaindrop(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .aiStorm:
            return AIStormParticleFactory.makeGlitch(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .fog:
            return FogParticleFactory.makeWisp(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .aurora:
            return AuroraParticleFactory.makeBand(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .clear:
            return ClearParticleFactory.makeMote(startY: startY, screenWidth: screenSize.width, rng: &rng)
        case .snow:
            return SnowParticleFactory.makeFlake(startY: startY, screenWidth: screenSize.width, rng: &rng)
        }
    }
}
