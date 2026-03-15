// SnowflakeView.swift
// wthrr — macOS decorative snowfall overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import Combine
import QuartzCore

// MARK: - Data

/// Visual shape category for snow crystals.
enum SnowShape {
    case dot         // Small round pellet — graupel / sleety drop
    case star        // 6-arm star with short crossbars — classic plate crystal
    case dendrite    // 3-axis branching crystal — most intricate, largest flakes only
}

/// Value type representing a single weather particle's current position and immutable
/// physical characteristics. Position (x, y) is mutated each frame by the
/// animation model; all other fields are assigned once at spawn time.
/// Used for both snowflakes and raindrops.
struct Snowflake {
    var x: CGFloat
    var y: CGFloat
    var rotation: CGFloat       // Current rotation angle in radians (snow only, drifts over time)
    let rotationSpeed: CGFloat  // Radians per second the flake slowly spins
    let shape: SnowShape        // Visual crystal shape (snow only)
    let tint: Double            // Slight blue tint 0 = pure white, 1 = max tint (snow only)
    let size: CGFloat           // Radius / half-width in points (snow: 2–8, rain: 0.8–1.8)
    let length: CGFloat         // Streak length (snow: size*2, rain: 8–25 pts)
    let fallSpeed: CGFloat      // Downward speed in pts/s before speed multiplier
    let wobbleAmp: CGFloat      // Horizontal wobble amplitude in pts
    let wobbleFreq: CGFloat     // Wobble oscillation frequency in Hz
    let wobblePhase: CGFloat    // Per-flake phase offset so wobbles stay out of sync
    let windSensitivity: CGFloat // Scales how strongly this particle responds to wind
    let opacity: Double         // Alpha value (snow: 0.45–0.95, rain: 0.55–0.85)
}

/// A short-lived splash effect spawned when a raindrop hits the ground or a puddle.
struct Splash {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat         // Expands over lifetime
    var opacity: Double         // Fades to zero over lifetime
    var age: CGFloat            // Seconds elapsed since spawning
    let lifetime: CGFloat       // Total duration (0.2 – 0.4 s)
}

/// A puddle that forms at the bottom of the screen in rain + puddles mode.
/// Puddles grow as raindrops land nearby, capped at a maximum height, and display
/// ripple rings when splashes occur close by.
struct Puddle {
    var x: CGFloat              // Horizontal centre
    var width: CGFloat          // Horizontal extent
    var height: CGFloat         // Vertical half-height (max 18 pts)
    var opacity: Double         // 0.55 – 0.80
    var rippleRadius: CGFloat   // Active ripple ring radius (0 = no ripple)
    var rippleOpacity: Double   // Fades as ripple expands
}

// MARK: - Wind

/// Simulates a smoothly varying horizontal wind that gusts and changes direction.
/// Velocity is expressed in points per second; positive = rightward.
@MainActor
class WindModel {
    private(set) var velocity: CGFloat = 0
    private var targetVelocity: CGFloat = 0
    private var timeUntilChange: CGFloat = 0

    /// Advances the wind simulation by one time step.
    /// - Parameters:
    ///   - dt: Elapsed seconds since the last update (capped upstream to 1/20 s).
    ///   - strength: Wind intensity from `SnowSettings.windStrength` (0 = calm, 1 = full gale).
    func update(dt: CGFloat, strength: CGFloat) {
        guard strength > 0 else {
            velocity += (0 - velocity) * min(dt * 1.5, 1.0)
            return
        }
        let maxGust = CGFloat(15 + 125 * strength)
        let smooth  = CGFloat(0.5 + 1.5 * strength)
        velocity += (targetVelocity - velocity) * min(dt * smooth, 1.0)
        timeUntilChange -= dt
        if timeUntilChange <= 0 {
            let flip: CGFloat = strength < 0.5 ? 1.0 : (CGFloat.random(in: 0...1) < 0.25 ? -1.0 : 1.0)
            let gustMag = CGFloat.random(in: maxGust * 0.3...maxGust)
            targetVelocity = gustMag * flip
            let baseInterval = CGFloat.random(in: 1.5...6.0)
            timeUntilChange = baseInterval * (1.2 - strength * 0.8)
        }
    }
}

// MARK: - Seeded RNG

/// A fast xorshift64 pseudo-random number generator seeded from `SnowSettings.randomSeed`.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    mutating func nextRaw() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    mutating func next01() -> Double { Double(nextRaw()) / Double(UInt64.max) }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next01() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Animation model

/// Drives snowflake physics at ~60 fps and manages the per-column accumulation
/// height map. The baseline is always the true screen bottom (screenSize.height);
/// snow piles upward from there. The Dock sits above our window level and
/// naturally occludes whatever is behind it, so no special baseline raising
/// is needed — snow simply fills from the floor up.
@MainActor
class SnowflakeAnimationModel: ObservableObject {
    private(set) var snowflakes: [Snowflake] = []
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

    // MARK: - Rain effects

    /// Short-lived splash effects spawned when raindrops hit the ground.
    private(set) var splashes: [Splash] = []

    /// Persistent puddles that grow during rain + puddles mode.
    private(set) var puddles: [Puddle] = []

    // MARK: - Accumulation

    /// Column width in points for the height-map grid.
    private let columnWidth: CGFloat = 4.0

    /// Accumulated snow height per column, measured upward from the baseline in points.
    private(set) var accumulationMap: [CGFloat] = []

    /// Ground level per column in Canvas coordinates (Y increases downward).
    /// Always screenSize.height — snow falls to the true bottom of the screen.
    private(set) var baselineMap: [CGFloat] = []

    /// Cached screen height to detect when a rebuild is needed.
    private var lastScreenSize: CGSize = .zero

    // MARK: - Timer

    /// Starts the ~60 fps animation timer. Safe to call multiple times.
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops the animation timer.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Configuration

    /// Rebuilds the particle array if key parameters changed since the last build.
    /// Detects changes to count, seed, speed, screen size, and weather type.
    func configure(size: CGSize, settings: SnowSettings) {
        guard size != .zero else { return }
        let needsRebuild = snowflakes.isEmpty
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
        snowflakes = (0..<settings.flakeCount).map { _ in
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

    // MARK: - Accumulation helpers

    /// Fills the baseline and (if needed) the accumulation map.
    /// Every column's baseline is screenSize.height — the absolute screen floor.
    /// Snow piles upward from there. The Dock sits in a window above ours and
    /// visually covers whatever accumulates behind it.
    private func rebuildBaseline() {
        guard screenSize != .zero else { return }
        let count = max(1, Int(ceil(screenSize.width / columnWidth)))
        let h     = screenSize.height

        if accumulationMap.count != count {
            accumulationMap = Array(repeating: 0, count: count)
        }
        // Always the true screen bottom — no dock adjustment needed
        baselineMap = Array(repeating: h, count: count)
        lastScreenSize = screenSize
    }

    /// Zeros all accumulated snow. Called when the toggle is turned off.
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

    // MARK: - Rain effect helpers

    /// Empties the splashes and puddles arrays. Called when switching weather types.
    func clearRainEffects() {
        splashes.removeAll()
        puddles.removeAll()
    }

    /// Populates the puddles array with 8–12 randomly placed puddles across the screen width.
    /// Puddles start with zero height and grow as raindrops land nearby (puddles mode).
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

    // MARK: - Physics

    /// Advances all particle positions by one frame.
    /// Handles snow accumulation, rain splashes, and puddle growth depending on settings.
    private func advance() {
        let now = CACurrentMediaTime()
        let dt: CGFloat = lastTime == 0 ? 1.0 / 60.0 : CGFloat(min(now - lastTime, 1.0 / 20.0))
        lastTime = now

        guard !snowflakes.isEmpty else { return }

        let settings   = SnowSettings.shared
        let speedScale = CGFloat(settings.speedMultiplier)
        let windScale  = CGFloat(settings.windStrength)
        let time       = CGFloat(now)
        let isRain     = settings.weatherType == .rain
        wind.update(dt: dt, strength: windScale)
        currentWindVelocity = wind.velocity

        let accumulating = settings.accumulationEnabled && !accumulationMap.isEmpty
        let maxAccumH    = CGFloat(settings.maxAccumulationHeight)

        for i in snowflakes.indices {
            snowflakes[i].y += snowflakes[i].fallSpeed * speedScale * dt
            snowflakes[i].x += wind.velocity * snowflakes[i].windSensitivity * speedScale * dt
            snowflakes[i].x += sin(time * snowflakes[i].wobbleFreq + snowflakes[i].wobblePhase)
                                * snowflakes[i].wobbleAmp * dt
            // Slowly spin each snow crystal (no-op for rain — rotationSpeed is 0)
            snowflakes[i].rotation += snowflakes[i].rotationSpeed * dt

            if isRain {
                // Rain: check against bottom or puddle surface
                let groundY = screenSize.height
                let hitY    = snowflakes[i].y + snowflakes[i].length

                if hitY >= groundY {
                    // Spawn a splash at impact point
                    let splash = Splash(
                        x:        snowflakes[i].x,
                        y:        groundY,
                        radius:   0,
                        opacity:  Double.random(in: 0.5...0.8),
                        age:      0,
                        lifetime: CGFloat.random(in: 0.2...0.4)
                    )
                    splashes.append(splash)

                    // Grow nearest puddle and trigger a ripple if puddles mode is enabled
                    if accumulating && !puddles.isEmpty {
                        let dropX = snowflakes[i].x
                        if let idx = puddles.indices.min(by: { abs(puddles[$0].x - dropX) < abs(puddles[$1].x - dropX) }) {
                            let dist = abs(puddles[idx].x - dropX)
                            if dist < puddles[idx].width * 0.65 {
                                puddles[idx].height = min(puddles[idx].height + 0.025, 18.0)
                                // Start a ripple on this puddle if one isn't already in progress
                                if puddles[idx].rippleOpacity < 0.1 {
                                    puddles[idx].rippleRadius  = 2
                                    puddles[idx].rippleOpacity = 0.75
                                }
                            }
                        }
                    }

                    // Recycle drop to top
                    snowflakes[i].y = -(snowflakes[i].length + 2)
                    snowflakes[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
                    continue
                }
            } else {
                // Snow: accumulation or simple wrap
                if accumulating {
                    let col      = min(max(0, Int(snowflakes[i].x / columnWidth)), accumulationMap.count - 1)
                    let landingY = baselineMap[col] - accumulationMap[col]

                    if snowflakes[i].y + snowflakes[i].size >= landingY {
                        let deposit = snowflakes[i].size * 0.35
                        for offset in -1...1 {
                            let c = col + offset
                            guard c >= 0 && c < accumulationMap.count else { continue }
                            let amount = offset == 0 ? deposit : deposit * 0.3
                            accumulationMap[c] = min(accumulationMap[c] + amount, maxAccumH)
                        }
                        snowflakes[i].y = -(snowflakes[i].size + 2)
                        snowflakes[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
                        continue
                    }
                } else {
                    if snowflakes[i].y > screenSize.height + snowflakes[i].size + 2 {
                        snowflakes[i].y = -(snowflakes[i].size + 2)
                        snowflakes[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
                    }
                }
            }

            if snowflakes[i].x < -30 {
                snowflakes[i].x = screenSize.width + 30
            } else if snowflakes[i].x > screenSize.width + 30 {
                snowflakes[i].x = -30
            }
        }

        // Age splashes and remove expired ones
        for i in splashes.indices.reversed() {
            splashes[i].age    += dt
            splashes[i].radius  = splashes[i].age / splashes[i].lifetime * 18
            splashes[i].opacity = Double(1 - splashes[i].age / splashes[i].lifetime) * 0.85
            if splashes[i].age >= splashes[i].lifetime {
                splashes.remove(at: i)
            }
        }

        // Advance puddle ripples
        for i in puddles.indices where puddles[i].rippleOpacity > 0 {
            puddles[i].rippleRadius  += dt * 40
            puddles[i].rippleOpacity  = max(0, puddles[i].rippleOpacity - dt * 2.5)
        }

        if !isRain && accumulating && tick % 30 == 0 { smoothAccumulation() }

        // Melt pass: when a column is at or above the cap, gradually reduce it so
        // the drift plateaus at maxAccumH rather than freezing solid. The rate is
        // proportional to how far above the cap the column is, so columns that just
        // reached the cap melt slowly while any overshoot resolves quickly.
        if !isRain && accumulating && tick % 4 == 0 {
            let meltRate: CGFloat = 0.08   // pts removed per eligible frame (~1.2 pts/s at 60 fps)
            for i in accumulationMap.indices {
                let excess = accumulationMap[i] - maxAccumH
                if excess >= 0 {
                    // At the cap: steady-state melt keeps the surface from freezing
                    accumulationMap[i] = max(0, accumulationMap[i] - meltRate)
                } else if excess > -8 {
                    // Just below cap: very gentle melt so the surface stays lively
                    accumulationMap[i] = max(0, accumulationMap[i] - meltRate * 0.3)
                }
            }
        }

        tick &+= 1
    }

    // MARK: - Factory

    /// Creates a single snowflake with randomised properties.
    /// Larger flakes get intricate crystal shapes; smaller ones are simple dots.
    /// Larger flakes fall faster and are less wind-sensitive, giving a sense of depth.
    private func makeFlake(startY: CGFloat, rng: inout SeededRNG) -> Snowflake {
        let size = CGFloat(rng.next(in: 2.0...8.0))
        let sizeFactor = (size - 2.0) / 6.0   // 0 = smallest, 1 = largest

        // Shape distribution: small → dot, medium → star, large → dendrite
        // Some randomness so shapes mix at boundary sizes
        let shapeRoll = rng.next01()
        let shape: SnowShape
        if size < 3.5 {
            shape = .dot
        } else if size < 6.0 {
            shape = shapeRoll < 0.75 ? .star : .dot
        } else {
            shape = shapeRoll < 0.55 ? .dendrite : .star
        }

        return Snowflake(
            x: CGFloat(rng.next(in: -20...max(Double(screenSize.width) + 20, 1))),
            y: startY,
            rotation: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            rotationSpeed: CGFloat(rng.next(in: -0.4...0.4)),
            shape: shape,
            tint: rng.next(in: 0.0...0.35),
            size: size,
            length: size * 2,
            fallSpeed: CGFloat(rng.next(in: 35...110)) * (0.45 + sizeFactor * 0.8),
            wobbleAmp: CGFloat(rng.next(in: 0.2...2.2)),
            wobbleFreq: CGFloat(rng.next(in: 0.3...2.0)),
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.5...1.5)) * (1.3 - sizeFactor * 0.7),
            opacity: rng.next(in: 0.45...0.95)
        )
    }

    /// Creates a single raindrop with randomised properties.
    /// Raindrops are thin, fast-falling streaks with minimal wobble.
    private func makeRaindrop(startY: CGFloat, rng: inout SeededRNG) -> Snowflake {
        let size = CGFloat(rng.next(in: 0.8...1.8))
        return Snowflake(
            x: CGFloat(rng.next(in: -20...max(Double(screenSize.width) + 20, 1))),
            y: startY,
            rotation: 0,
            rotationSpeed: 0,
            shape: .dot,        // unused for rain rendering
            tint: 0,
            size: size,
            length: CGFloat(rng.next(in: 8...25)),
            fallSpeed: CGFloat(rng.next(in: 300...600)),
            wobbleAmp: CGFloat(rng.next(in: 0.0...0.3)),
            wobbleFreq: CGFloat(rng.next(in: 0.2...0.8)),
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.3...0.7)),
            opacity: rng.next(in: 0.55...0.85)
        )
    }

    /// Dispatches to the appropriate factory based on the active weather type.
    private func makeParticle(startY: CGFloat, rng: inout SeededRNG, weatherType: WeatherType) -> Snowflake {
        weatherType == .rain
            ? makeRaindrop(startY: startY, rng: &rng)
            : makeFlake(startY: startY, rng: &rng)
    }
}

// MARK: - SwiftUI view

/// Full-screen Canvas that renders weather particles (snow or rain) and secondary effects
/// (drift, splashes, puddles) each frame. Adapts colours to macOS light/dark appearance.
struct SnowflakeView: View {
    @Environment(SnowSettings.self)   private var settings
    @Environment(ScreenGeometry.self) private var geometry
    @Environment(\.colorScheme)       private var colorScheme
    @StateObject private var model = SnowflakeAnimationModel()

    var body: some View {
        Canvas { context, size in
            model.configure(size: size, settings: settings)
            _ = model.tick

            let isDark   = colorScheme == .dark
            let isRain   = settings.weatherType == .rain

            if isRain {
                drawRain(context: context, size: size, isDark: isDark)
            } else {
                drawSnow(context: context, size: size, isDark: isDark)
            }
        }
        .ignoresSafeArea()
        .onAppear    { model.start() }
        .onDisappear { model.stop()  }
        .onChange(of: settings.accumulationEnabled) { _, enabled in
            if !enabled {
                model.clearAccumulation()
                // Also clear puddle heights when puddles mode is turned off
                if settings.weatherType == .rain { model.clearRainEffects() }
            }
        }
        .onChange(of: settings.weatherType) { _, _ in
            model.clearAccumulation()
            model.clearRainEffects()
        }
    }

    // MARK: - Snow rendering

    /// Renders snow particles (dots, star crystals, dendrites) and the accumulated drift shape.
    /// Each flake slowly rotates and has a slight colour tint variation for realism.
    private func drawSnow(context: GraphicsContext, size: CGSize, isDark: Bool) {
        let driftFillColor: Color = isDark
            ? Color(white: 0.95)
            : Color(red: 0.82, green: 0.87, blue: 0.95)

        let driftEdgeColor: Color = isDark
            ? Color(white: 0.80, opacity: 0.6)
            : Color(red: 0.65, green: 0.73, blue: 0.85, opacity: 0.7)

        // Snowflakes — three crystal shapes rendered with per-flake rotation
        for flake in model.snowflakes {
            // Per-flake colour: slight blue tint variation
            let flakeColor: Color = isDark
                ? Color(red: 1.0, green: 1.0 - flake.tint * 0.05, blue: 1.0)
                : Color(red: 0.88, green: 0.92 - flake.tint * 0.04, blue: 0.98)

            var ctx = context
            ctx.opacity = flake.opacity

            // Light-mode shadow pass for contrast against bright wallpapers
            if !isDark {
                var shadowCtx = context
                shadowCtx.opacity = flake.opacity * 0.18
                let sr = flake.size * 1.15
                let shadowRect = CGRect(x: flake.x - sr + 0.7, y: flake.y - sr + 0.9,
                                        width: sr * 2, height: sr * 2)
                shadowCtx.fill(Path(ellipseIn: shadowRect), with: .color(Color(white: 0.3)))
            }

            switch flake.shape {
            case .dot:
                // Soft round pellet — slightly oval to hint at 3D
                let r = flake.size
                let dotRect = CGRect(x: flake.x - r, y: flake.y - r * 0.9,
                                     width: r * 2, height: r * 1.8)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(flakeColor))

            case .star:
                // 6-arm plate crystal: 3 lines at 60° intervals + centre dot + arm tips
                ctx.drawLayer { starCtx in
                    starCtx.translateBy(x: flake.x, y: flake.y)
                    starCtx.rotate(by: Angle(radians: flake.rotation))
                    let arm = flake.size
                    let lineWidth = max(1.0, flake.size * 0.28)
                    // Draw 3 axes (each axis = 2 opposing arms)
                    for i in 0..<3 {
                        let angle = CGFloat(i) * .pi / 3
                        var axisPath = Path()
                        axisPath.move(to: CGPoint(x: -cos(angle) * arm, y: -sin(angle) * arm))
                        axisPath.addLine(to: CGPoint(x: cos(angle) * arm, y: sin(angle) * arm))
                        starCtx.stroke(axisPath, with: .color(flakeColor),
                                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        // Crossbar at ~60% along each arm
                        for sign: CGFloat in [-1, 1] {
                            let cx = sign * cos(angle) * arm * 0.6
                            let cy = sign * sin(angle) * arm * 0.6
                            let barAngle = angle + .pi / 2
                            let barLen   = arm * 0.32
                            var barPath = Path()
                            barPath.move(to: CGPoint(x: cx - cos(barAngle) * barLen,
                                                     y: cy - sin(barAngle) * barLen))
                            barPath.addLine(to: CGPoint(x: cx + cos(barAngle) * barLen,
                                                        y: cy + sin(barAngle) * barLen))
                            starCtx.stroke(barPath, with: .color(flakeColor),
                                           style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
                        }
                    }
                    // Bright centre dot
                    let cR = lineWidth * 1.1
                    starCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                                 with: .color(flakeColor))
                }

            case .dendrite:
                // 3-axis branching dendrite: main arms + secondary branches + tertiary tips
                ctx.drawLayer { dendCtx in
                    dendCtx.translateBy(x: flake.x, y: flake.y)
                    dendCtx.rotate(by: Angle(radians: flake.rotation))
                    let arm      = flake.size
                    let lineW    = max(1.0, flake.size * 0.22)
                    let branchW  = lineW * 0.65
                    let tipW     = lineW * 0.45

                    for i in 0..<3 {
                        let angle = CGFloat(i) * .pi / 3
                        for sign: CGFloat in [-1, 1] {
                            let ex = sign * cos(angle) * arm
                            let ey = sign * sin(angle) * arm
                            // Main arm
                            var mainPath = Path()
                            mainPath.move(to: .zero)
                            mainPath.addLine(to: CGPoint(x: ex, y: ey))
                            dendCtx.stroke(mainPath, with: .color(flakeColor),
                                           style: StrokeStyle(lineWidth: lineW, lineCap: .round))

                            // Two pairs of secondary branches at 35% and 65% of the arm
                            for frac: CGFloat in [0.35, 0.65] {
                                let bx = sign * cos(angle) * arm * frac
                                let by = sign * sin(angle) * arm * frac
                                let branchLen = arm * (0.40 - frac * 0.18)
                                let branchAngle = angle + .pi / 2
                                for bSign: CGFloat in [-1, 1] {
                                    var bPath = Path()
                                    bPath.move(to: CGPoint(x: bx, y: by))
                                    bPath.addLine(to: CGPoint(
                                        x: bx + bSign * cos(branchAngle) * branchLen,
                                        y: by + bSign * sin(branchAngle) * branchLen
                                    ))
                                    dendCtx.stroke(bPath, with: .color(flakeColor),
                                                   style: StrokeStyle(lineWidth: branchW, lineCap: .round))

                                    // Tiny tertiary tip at the end of each branch
                                    let tipStartX = bx + bSign * cos(branchAngle) * branchLen
                                    let tipStartY = by + bSign * sin(branchAngle) * branchLen
                                    let tipLen    = branchLen * 0.38
                                    for tSign: CGFloat in [-1, 1] {
                                        let tipAngle = branchAngle + tSign * .pi / 4
                                        var tPath = Path()
                                        tPath.move(to: CGPoint(x: tipStartX, y: tipStartY))
                                        tPath.addLine(to: CGPoint(
                                            x: tipStartX + cos(tipAngle) * tipLen,
                                            y: tipStartY + sin(tipAngle) * tipLen
                                        ))
                                        dendCtx.stroke(tPath, with: .color(flakeColor),
                                                       style: StrokeStyle(lineWidth: tipW, lineCap: .round))
                                    }
                                }
                            }
                        }
                    }
                    // Centre hexagon dot
                    let cR = lineW * 1.2
                    dendCtx.fill(Path(ellipseIn: CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)),
                                 with: .color(flakeColor))
                }
            }
        }

        // Snow drift
        let mapCount = model.accumulationMap.count
        if settings.accumulationEnabled && mapCount > 1 {
            let colW = CGFloat(4.0)

            // Filled body — walk right edge down → bottom → left along top surface
            var driftPath = Path()
            driftPath.move(to: CGPoint(x: 0, y: size.height))
            driftPath.addLine(to: CGPoint(x: size.width, y: size.height))

            var firstPoint = true
            var prevPt = CGPoint.zero
            for col in (0..<mapCount).reversed() {
                let x    = CGFloat(col) * colW + colW * 0.5
                let topY = model.baselineMap[col] - model.accumulationMap[col]
                let pt   = CGPoint(x: x, y: topY)
                if firstPoint {
                    driftPath.addLine(to: pt)
                    firstPoint = false
                } else {
                    let mid = CGPoint(x: (prevPt.x + pt.x) / 2, y: (prevPt.y + pt.y) / 2)
                    driftPath.addQuadCurve(to: pt, control: mid)
                }
                prevPt = pt
            }
            driftPath.closeSubpath()
            context.fill(driftPath, with: .color(driftFillColor))

            // Top edge stroke
            var edgePath = Path()
            firstPoint = true
            prevPt = .zero
            for col in 0..<mapCount {
                let x    = CGFloat(col) * colW + colW * 0.5
                let topY = model.baselineMap[col] - model.accumulationMap[col]
                let pt   = CGPoint(x: x, y: topY)
                if firstPoint {
                    edgePath.move(to: pt)
                    firstPoint = false
                } else {
                    let mid = CGPoint(x: (prevPt.x + pt.x) / 2, y: (prevPt.y + pt.y) / 2)
                    edgePath.addQuadCurve(to: pt, control: mid)
                }
                prevPt = pt
            }
            context.stroke(edgePath, with: .color(driftEdgeColor), lineWidth: 1.5)
        }
    }

    // MARK: - Rain rendering

    /// Renders rain streaks, splash effects, and puddles.
    private func drawRain(context: GraphicsContext, size: CGSize, isDark: Bool) {
        // Rain streak colour — light blue-white in dark mode, blue-grey in light mode
        let rainColor: Color = isDark
            ? Color(red: 0.78, green: 0.88, blue: 1.0)
            : Color(red: 0.55, green: 0.65, blue: 0.80)

        let splashColor: Color = isDark
            ? Color(red: 0.75, green: 0.88, blue: 1.0, opacity: 0.7)
            : Color(red: 0.50, green: 0.62, blue: 0.78, opacity: 0.6)

        // Puddle base fill colour — deep blue tint, clearly visible
        let puddleBodyColor: Color = isDark
            ? Color(red: 0.30, green: 0.52, blue: 0.82, opacity: 0.72)
            : Color(red: 0.28, green: 0.46, blue: 0.72, opacity: 0.60)
        // Lighter sheen layer sitting on top of the body
        let puddleShineColor: Color = isDark
            ? Color(red: 0.65, green: 0.82, blue: 1.0, opacity: 0.35)
            : Color(red: 0.70, green: 0.84, blue: 1.0, opacity: 0.28)
        // Ripple ring colour
        let rippleColor: Color = isDark
            ? Color(red: 0.60, green: 0.80, blue: 1.0)
            : Color(red: 0.45, green: 0.65, blue: 0.90)

        // Wind-tilt angle (clamped to ±25 degrees for readability)
        let maxTiltDeg: CGFloat = 25
        let tiltAngle = CGFloat(atan2(model.currentWindVelocity * 0.015, 1.0))
            .clamped(to: -maxTiltDeg * .pi / 180 ... maxTiltDeg * .pi / 180)

        // Puddles — always drawn in rain mode (grow when puddles toggle is on)
        for puddle in model.puddles where puddle.height > 0.5 {
            let halfH  = puddle.height
            let bodyY  = size.height - halfH            // top of puddle body
            let bodyH  = halfH * 2.2                    // extends below screen bottom

            // Body ellipse
            let bodyRect = CGRect(
                x: puddle.x - puddle.width / 2,
                y: bodyY,
                width: puddle.width,
                height: bodyH
            )
            var bodyCtx = context
            bodyCtx.opacity = puddle.opacity
            bodyCtx.fill(Path(ellipseIn: bodyRect), with: .color(puddleBodyColor))

            // Specular shine — narrow ellipse across the upper third of the puddle
            let shineW  = puddle.width * 0.55
            let shineH  = halfH * 0.45
            let shineRect = CGRect(
                x: puddle.x - shineW / 2,
                y: bodyY + halfH * 0.15,
                width: shineW,
                height: shineH
            )
            var shineCtx = context
            shineCtx.opacity = puddle.opacity * 0.9
            shineCtx.fill(Path(ellipseIn: shineRect), with: .color(puddleShineColor))

            // Ripple ring
            if puddle.rippleOpacity > 0.01 {
                let rr = puddle.rippleRadius
                // Keep ripple constrained to puddle width
                let clampedRR = min(rr, puddle.width * 0.42)
                let rippleRect = CGRect(
                    x: puddle.x - clampedRR,
                    y: bodyY + halfH * 0.45 - clampedRR * 0.3,
                    width: clampedRR * 2,
                    height: clampedRR * 0.6
                )
                var rippleCtx = context
                rippleCtx.opacity = puddle.rippleOpacity
                rippleCtx.stroke(
                    Path(ellipseIn: rippleRect),
                    with: .color(rippleColor),
                    lineWidth: 1.0
                )
            }
        }

        // Rain streaks
        for drop in model.snowflakes {
            // Compute streak endpoints from tilt angle
            let halfLen = drop.length / 2
            let dx = sin(tiltAngle) * halfLen
            let dy = cos(tiltAngle) * halfLen
            let top    = CGPoint(x: drop.x - dx, y: drop.y - dy)
            let bottom = CGPoint(x: drop.x + dx, y: drop.y + dy)

            var path = Path()
            path.move(to: top)
            path.addLine(to: bottom)

            var ctx = context
            ctx.opacity = drop.opacity
            ctx.stroke(path, with: .color(rainColor), style: StrokeStyle(lineWidth: drop.size * 1.5, lineCap: .round))
        }

        // Splashes
        for splash in model.splashes {
            var ctx = context
            ctx.opacity = splash.opacity

            // Primary expanding elliptical ring at impact point
            let r = splash.radius
            let ringRect = CGRect(
                x: splash.x - r,
                y: splash.y - r * 0.35,
                width: r * 2,
                height: r * 0.7
            )
            ctx.stroke(Path(ellipseIn: ringRect), with: .color(splashColor), lineWidth: 1.2)

            // Second outer ring (slightly larger, more transparent)
            let r2 = r * 1.35
            let outerRect = CGRect(
                x: splash.x - r2,
                y: splash.y - r2 * 0.35,
                width: r2 * 2,
                height: r2 * 0.7
            )
            var outerCtx = context
            outerCtx.opacity = splash.opacity * 0.45
            outerCtx.stroke(Path(ellipseIn: outerRect), with: .color(splashColor), lineWidth: 0.7)

            // Four droplet dots radiating outward at compass points
            let dotR: CGFloat = 1.4
            let dotOffsets: [(CGFloat, CGFloat)] = [
                (-r * 0.7, -r * 0.55),
                ( r * 0.7, -r * 0.55),
                (-r * 0.35, -r * 0.85),
                ( r * 0.35, -r * 0.85)
            ]
            for (ox, oy) in dotOffsets {
                let dotRect = CGRect(x: splash.x + ox - dotR, y: splash.y + oy - dotR,
                                     width: dotR * 2, height: dotR * 2)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(splashColor))
            }
        }
    }
}

// MARK: - CGFloat clamp helper
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
