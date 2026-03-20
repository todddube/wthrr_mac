// WeatherAnimationModel.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import QuartzCore

// MARK: - Weather animation model

/// Drives weather particle physics at ~60 fps and manages the per-column accumulation
/// height map and rain effects. The baseline is always the true screen bottom
/// (screenSize.height); snow piles upward from there. The Dock sits above our
/// window level and naturally occludes whatever is behind it.
@Observable
@MainActor
final class WeatherAnimationModel {
    private(set) var particles: [Particle] = []
    private var screenSize: CGSize = .zero
    private let wind = WindModel()

    private var lastTime: CFTimeInterval = 0

    private var builtCount = 0
    private var builtSeed  = 0
    private var builtSpeed: Double = 0
    private var builtWeatherType: WeatherType?

    /// Internal frame counter for periodic operations (smoothing, melting).
    private var frameCount: Int = 0

    /// Current wind velocity exposed for Canvas rain-angle rendering (pts/s).
    private(set) var currentWindVelocity: CGFloat = 0

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

    // MARK: Clouds

    /// Active clouds drifting across the top of the screen.
    private(set) var clouds: [Cloud] = []

    /// Whether clouds were enabled last frame (to detect toggle changes).
    private var builtCloudsEnabled: Bool = false

    /// Cloud size multiplier last used to build the cloud population.
    private var builtCloudSize: Double = 0

    // MARK: Accumulation

    /// Column width in points for the height-map grid.
    let columnWidth: CGFloat = 4.0

    /// Accumulated snow height per column, measured upward from the baseline in points.
    private(set) var accumulationMap: [CGFloat] = []

    /// Ground level per column in Canvas coordinates (Y increases downward).
    private(set) var baselineMap: [CGFloat] = []

    private var lastScreenSize: CGSize = .zero

    // MARK: Configuration

    /// Rebuilds the particle array if key parameters changed since the last build.
    /// Detects changes to count, seed, speed, screen size, and weather type.
    func configure(size: CGSize, settings: WeatherSettings) {
        guard size != .zero else { return }

        // Clouds are independent of the particle system — always check
        screenSize = screenSize == .zero ? size : screenSize
        configureClouds(settings: settings)

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
    /// Called each frame by the TimelineView-driven Canvas.
    func advance(settings: WeatherSettings) {
        let now = CACurrentMediaTime()

        // Paused: keep lastTime current so we don't get a huge dt spike on resume
        if settings.isPaused { lastTime = now; return }

        // Low-power mode: skip frames to target ~30 fps instead of the display refresh rate
        if settings.lowPowerMode && lastTime > 0 && (now - lastTime) < 1.0 / 30.0 { return }

        let dt: CGFloat = lastTime == 0 ? 1.0 / 60.0 : CGFloat(min(now - lastTime, 1.0 / 20.0))
        lastTime = now

        guard !particles.isEmpty else { return }

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
        let maxAccumH    = CGFloat(settings.maxAccumulationHeight)

        for i in particles.indices {
            // Apply fall speed, wind, and wobble to each particle
            let angleRad = CGFloat(settings.windAngle) * .pi / 180
            particles[i].y += particles[i].fallSpeed * speedScale * dt * cos(angleRad)
            particles[i].x += particles[i].fallSpeed * speedScale * dt * sin(angleRad)
            particles[i].x += currentWindVelocity * particles[i].windSensitivity * speedScale * dt
            particles[i].x += sin(time * particles[i].wobbleFreq + particles[i].wobblePhase)
                                * particles[i].wobbleAmp * dt
            particles[i].rotation += particles[i].rotationSpeed * dt

            if isRain {
                advanceRainParticle(at: i, accumulating: accumulating)
            } else if settings.weatherType == .aiStorm {
                advanceAIStormParticle(at: i)
            } else if settings.weatherType == .fog {
                if particles[i].y > screenSize.height + 40 {
                    particles[i].y = -40
                    particles[i].x = CGFloat.random(in: 0...screenSize.width)
                }
            } else if settings.weatherType == .aurora {
                if particles[i].y > screenSize.height + 40 {
                    particles[i].y = -40
                    particles[i].x = CGFloat.random(in: 0...screenSize.width)
                }
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

        // Advance aurora time
        if settings.weatherType == .aurora {
            auroraTime += dt
        }

        frameCount &+= 1
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
    private func advanceAIStormParticle(at i: Int) {
        // Wrap vertically for both upward and downward movement
        if particles[i].y > screenSize.height + 20 {
            particles[i].y = -20
            particles[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
        } else if particles[i].y < -30 {
            particles[i].y = screenSize.height + 10
            particles[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
        }

        // Occasional glitch teleport — a sudden jump to a nearby position
        glitchFrame &+= 1
        if glitchFrame % 7 == 0 && CGFloat.random(in: 0...1) < 0.02 {
            particles[i].x += CGFloat.random(in: -60...60)
            particles[i].y += CGFloat.random(in: -40...40)
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

            // Update trail (keep last 12 positions)
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

    func clearFogEffects() {
        fogBands.removeAll()
    }

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

        let cloudsNeeded = settings.cloudsEnabled || settings.weatherType == .thunderstorm
        if !cloudsNeeded {
            if !clouds.isEmpty { clouds.removeAll() }
            builtCloudsEnabled = false
            return
        }

        let needsRebuild = !builtCloudsEnabled
            || clouds.isEmpty
            || settings.cloudSize != builtCloudSize

        guard needsRebuild else { return }
        builtCloudsEnabled = true
        builtCloudSize = settings.cloudSize

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(settings.randomSeed &+ 7777)))
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

    /// Moves clouds rightward each frame and recycles ones that drift off-screen.
    private func advanceClouds(dt: CGFloat) {
        guard !clouds.isEmpty else { return }
        let settings = WeatherSettings.shared
        guard settings.cloudsEnabled || settings.weatherType == .thunderstorm else { return }

        for i in clouds.indices {
            clouds[i].x += clouds[i].speed * CGFloat(settings.cloudSpeed) * dt
        }

        // Recycle clouds that have fully exited the right edge
        for i in clouds.indices {
            if clouds[i].x - clouds[i].width / 2 > screenSize.width {
                var rng = SeededRNG(seed: UInt64(CACurrentMediaTime().bitPattern) &+ UInt64(i))
                clouds[i] = CloudFactory.makeCloud(
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
        case .snow:
            return SnowParticleFactory.makeFlake(startY: startY, screenWidth: screenSize.width, rng: &rng)
        }
    }
}
