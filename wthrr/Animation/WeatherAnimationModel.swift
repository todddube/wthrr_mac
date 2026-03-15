// WeatherAnimationModel.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import Combine
import QuartzCore

// MARK: - Weather animation model

/// Drives weather particle physics at ~60 fps and manages the per-column accumulation
/// height map and rain effects. The baseline is always the true screen bottom
/// (screenSize.height); snow piles upward from there. The Dock sits above our
/// window level and naturally occludes whatever is behind it.
@MainActor
class WeatherAnimationModel: ObservableObject {
    private(set) var particles: [Particle] = []
    private var screenSize: CGSize = .zero
    private let wind = WindModel()

    private var timer: Timer?
    private var lastTime: CFTimeInterval = 0

    private var builtCount = 0
    private var builtSeed  = 0
    private var builtSpeed: Double = 0
    private var builtWeatherType: WeatherType?

    /// Incremented every frame so the Canvas knows to redraw.
    @Published var tick: Int = 0

    /// Current wind velocity exposed for Canvas rain-angle rendering (pts/s).
    @Published var currentWindVelocity: CGFloat = 0

    // MARK: Rain effects

    /// Short-lived splash effects spawned when raindrops hit the ground.
    private(set) var splashes: [Splash] = []

    /// Persistent puddles that grow during rain + puddles mode.
    private(set) var puddles: [Puddle] = []

    // MARK: Lightning

    /// The currently active lightning bolt, if any. Nil when no strike is in progress.
    private(set) var activeBolt: LightningBolt?

    /// Countdown in seconds until the next lightning strike.
    private var timeUntilNextStrike: CGFloat = 0

    // MARK: Accumulation

    /// Column width in points for the height-map grid.
    let columnWidth: CGFloat = 4.0

    /// Accumulated snow height per column, measured upward from the baseline in points.
    private(set) var accumulationMap: [CGFloat] = []

    /// Ground level per column in Canvas coordinates (Y increases downward).
    private(set) var baselineMap: [CGFloat] = []

    private var lastScreenSize: CGSize = .zero

    // MARK: Timer

    /// Starts the ~60 fps animation timer. Safe to call multiple times.
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops the animation timer and releases the scheduled timer.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Configuration

    /// Rebuilds the particle array if key parameters changed since the last build.
    /// Detects changes to count, seed, speed, screen size, and weather type.
    func configure(size: CGSize, settings: WeatherSettings) {
        guard size != .zero else { return }
        let needsRebuild = particles.isEmpty
            || size != screenSize
            || settings.flakeCount      != builtCount
            || settings.randomSeed      != builtSeed
            || settings.speedMultiplier != builtSpeed
            || settings.weatherType     != builtWeatherType

        guard needsRebuild else { return }

        let weatherChanged = settings.weatherType != builtWeatherType

        screenSize        = size
        builtCount        = settings.flakeCount
        builtSeed         = settings.randomSeed
        builtSpeed        = settings.speedMultiplier
        builtWeatherType  = settings.weatherType

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(settings.randomSeed)))
        particles = (0..<settings.flakeCount).map { _ in
            makeParticle(
                startY: CGFloat(rng.next01()) * (size.height + 40) - 40,
                rng: &rng,
                weatherType: settings.weatherType
            )
        }

        if weatherChanged {
            clearRainEffects()
            clearAccumulation()
        }

        if settings.weatherType == .rain && puddles.isEmpty {
            initializePuddles()
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
    private func smoothAccumulation() {
        guard accumulationMap.count > 2 else { return }
        var smoothed = accumulationMap
        for i in 1..<(accumulationMap.count - 1) {
            smoothed[i] = (accumulationMap[i - 1] + accumulationMap[i] * 2 + accumulationMap[i + 1]) / 4
        }
        accumulationMap = smoothed
    }

    // MARK: Rain effect helpers

    /// Empties the splashes and puddles arrays. Called when switching weather types.
    func clearRainEffects() {
        splashes.removeAll()
        puddles.removeAll()
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
    }

    // MARK: Physics

    /// Advances all particle positions by one frame.
    /// Handles snow accumulation, rain splashes, and puddle growth depending on settings.
    private func advance() {
        let now = CACurrentMediaTime()
        let dt: CGFloat = lastTime == 0 ? 1.0 / 60.0 : CGFloat(min(now - lastTime, 1.0 / 20.0))
        lastTime = now

        guard !particles.isEmpty else { return }

        let settings   = WeatherSettings.shared
        let speedScale = CGFloat(settings.speedMultiplier)
        let windScale  = CGFloat(settings.windStrength)
        let time       = CGFloat(now)
        let isRain     = settings.weatherType == .rain
        wind.update(dt: dt, strength: windScale)
        currentWindVelocity = wind.velocity

        let accumulating = settings.accumulationEnabled && !accumulationMap.isEmpty
        let maxAccumH    = CGFloat(settings.maxAccumulationHeight)

        for i in particles.indices {
            // Apply fall speed, wind, and wobble to each particle
            particles[i].y += particles[i].fallSpeed * speedScale * dt
            particles[i].x += wind.velocity * particles[i].windSensitivity * speedScale * dt
            particles[i].x += sin(time * particles[i].wobbleFreq + particles[i].wobblePhase)
                                * particles[i].wobbleAmp * dt
            particles[i].rotation += particles[i].rotationSpeed * dt

            if isRain {
                advanceRainParticle(at: i, accumulating: accumulating)
            } else {
                advanceSnowParticle(at: i, accumulating: accumulating, maxAccumH: maxAccumH)
            }

            // Wrap horizontally when a particle drifts off screen
            if particles[i].x < -30 {
                particles[i].x = screenSize.width + 30
            } else if particles[i].x > screenSize.width + 30 {
                particles[i].x = -30
            }
        }

        ageSplashes(dt: dt)
        advancePuddleRipples(dt: dt)

        if isRain && settings.lightningEnabled {
            advanceLightning(dt: dt)
        }

        if !isRain && accumulating && tick % 30 == 0 { smoothAccumulation() }
        if !isRain && accumulating && tick % 4 == 0 { meltExcessSnow(maxAccumH: maxAccumH) }

        tick &+= 1
    }

    // MARK: Rain physics

    /// Handles a single raindrop hitting the ground: spawns a splash, grows the
    /// nearest puddle, and recycles the drop to the top of the screen.
    private func advanceRainParticle(at i: Int, accumulating: Bool) {
        let groundY = screenSize.height
        let hitY    = particles[i].y + particles[i].length

        guard hitY >= groundY else { return }

        // Spawn a splash at impact point
        let splash = Splash(
            x:        particles[i].x,
            y:        groundY,
            radius:   0,
            opacity:  Double.random(in: 0.5...0.8),
            age:      0,
            lifetime: CGFloat.random(in: 0.2...0.4)
        )
        splashes.append(splash)

        // Grow nearest puddle and trigger a ripple if puddles mode is enabled
        if accumulating && !puddles.isEmpty {
            let dropX = particles[i].x
            if let idx = puddles.indices.min(by: { abs(puddles[$0].x - dropX) < abs(puddles[$1].x - dropX) }) {
                let dist = abs(puddles[idx].x - dropX)
                if dist < puddles[idx].width * 0.65 {
                    puddles[idx].height = min(puddles[idx].height + 0.025, 18.0)
                    if puddles[idx].rippleOpacity < 0.1 {
                        puddles[idx].rippleRadius  = 2
                        puddles[idx].rippleOpacity = 0.75
                    }
                }
            }
        }

        // Recycle drop to top of screen
        particles[i].y = -(particles[i].length + 2)
        particles[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
    }

    // MARK: Snow physics

    /// Handles a single snowflake landing: deposits snow into the accumulation map
    /// and recycles the flake to the top of the screen.
    private func advanceSnowParticle(at i: Int, accumulating: Bool, maxAccumH: CGFloat) {
        if accumulating {
            let col      = min(max(0, Int(particles[i].x / columnWidth)), accumulationMap.count - 1)
            let landingY = baselineMap[col] - accumulationMap[col]

            if particles[i].y + particles[i].size >= landingY {
                let deposit = particles[i].size * 0.35
                for offset in -1...1 {
                    let c = col + offset
                    guard c >= 0 && c < accumulationMap.count else { continue }
                    let amount = offset == 0 ? deposit : deposit * 0.3
                    accumulationMap[c] = min(accumulationMap[c] + amount, maxAccumH)
                }
                particles[i].y = -(particles[i].size + 2)
                particles[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
            }
        } else {
            if particles[i].y > screenSize.height + particles[i].size + 2 {
                particles[i].y = -(particles[i].size + 2)
                particles[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
            }
        }
    }

    // MARK: Effect updates

    /// Ages all active splashes, expanding their radius and fading opacity.
    /// Removes splashes that have exceeded their lifetime.
    private func ageSplashes(dt: CGFloat) {
        for i in splashes.indices.reversed() {
            splashes[i].age    += dt
            splashes[i].radius  = splashes[i].age / splashes[i].lifetime * 18
            splashes[i].opacity = Double(1 - splashes[i].age / splashes[i].lifetime) * 0.85
            if splashes[i].age >= splashes[i].lifetime {
                splashes.remove(at: i)
            }
        }
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
        let meltRate: CGFloat = 0.08
        for i in accumulationMap.indices {
            let excess = accumulationMap[i] - maxAccumH
            if excess >= 0 {
                accumulationMap[i] = max(0, accumulationMap[i] - meltRate)
            } else if excess > -8 {
                accumulationMap[i] = max(0, accumulationMap[i] - meltRate * 0.3)
            }
        }
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
            timeUntilNextStrike = CGFloat.random(in: 8...25)
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

    // MARK: Factory

    /// Dispatches to the appropriate factory based on the active weather type.
    private func makeParticle(startY: CGFloat, rng: inout SeededRNG, weatherType: WeatherType) -> Particle {
        weatherType == .rain
            ? RainParticleFactory.makeRaindrop(startY: startY, screenWidth: screenSize.width, rng: &rng)
            : SnowParticleFactory.makeFlake(startY: startY, screenWidth: screenSize.width, rng: &rng)
    }
}
