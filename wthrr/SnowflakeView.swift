import SwiftUI
import Combine
import QuartzCore

// MARK: - Data

struct Snowflake {
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let fallSpeed: CGFloat
    let wobbleAmp: CGFloat
    let wobbleFreq: CGFloat
    let wobblePhase: CGFloat
    let windSensitivity: CGFloat
    let opacity: Double
}

// MARK: - Wind

@MainActor
class WindModel {
    private(set) var velocity: CGFloat = 0
    private var targetVelocity: CGFloat = 0
    private var timeUntilChange: CGFloat = 0

    /// - Parameter strength: 0 (calm) … 1 (full gale) from SnowSettings.windStrength
    func update(dt: CGFloat, strength: CGFloat) {
        // At strength 0 the wind dies out; smoothly ease velocity toward 0
        guard strength > 0 else {
            velocity += (0 - velocity) * min(dt * 1.5, 1.0)
            return
        }

        // Scale max gust speed: calm = 15 pts/s, full gale = 140 pts/s
        let maxGust = CGFloat(15 + 125 * strength)

        // Smoothing speed: stronger wind transitions faster (more abrupt gusts)
        let smooth = CGFloat(0.5 + 1.5 * strength)
        velocity += (targetVelocity - velocity) * min(dt * smooth, 1.0)

        timeUntilChange -= dt
        if timeUntilChange <= 0 {
            // Bias toward the same direction at high strength (prevailing wind feel)
            // At low strength, direction flips freely; at high strength it mostly stays put
            let flip: CGFloat = strength < 0.5 ? 1.0 : (CGFloat.random(in: 0...1) < 0.25 ? -1.0 : 1.0)
            let gustMag = CGFloat.random(in: maxGust * 0.3...maxGust)
            targetVelocity = gustMag * flip

            // High strength = short, sharp gust intervals; low = long lazy drifts
            let baseInterval = CGFloat.random(in: 1.5...6.0)
            timeUntilChange = baseInterval * (1.2 - strength * 0.8)
        }
    }
}

// MARK: - Seeded RNG

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

    /// Bumped every frame so the Canvas knows to redraw.
    @Published var tick: Int = 0

    func start() {
        guard timer == nil else { return }
        // Schedule at ~60 fps on the common run loop mode so it fires during tracking/scrolling too
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func configure(size: CGSize, settings: SnowSettings) {
        guard size != .zero else { return }
        let needsRebuild = snowflakes.isEmpty
            || size != screenSize
            || settings.flakeCount      != builtCount
            || settings.randomSeed      != builtSeed
            || settings.speedMultiplier != builtSpeed

        guard needsRebuild else { return }

        screenSize = size
        builtCount = settings.flakeCount
        builtSeed  = settings.randomSeed
        builtSpeed = settings.speedMultiplier

        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(settings.randomSeed)))
        // Distribute initial Y across the full screen so it looks populated immediately
        snowflakes = (0..<settings.flakeCount).map { _ in
            makeFlake(startY: CGFloat(rng.next01()) * (size.height + 40) - 40, rng: &rng)
        }
    }

    private func advance() {
        let now = CACurrentMediaTime()
        let dt: CGFloat
        if lastTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = CGFloat(min(now - lastTime, 1.0 / 20.0))
        }
        lastTime = now

        guard !snowflakes.isEmpty else { return }

        let settings = SnowSettings.shared
        let speedScale = CGFloat(settings.speedMultiplier)
        let windScale  = CGFloat(settings.windStrength)
        let time = CGFloat(now)
        wind.update(dt: dt, strength: windScale)

        for i in snowflakes.indices {
            // Fall downward
            snowflakes[i].y += snowflakes[i].fallSpeed * speedScale * dt
            // Wind
            snowflakes[i].x += wind.velocity * snowflakes[i].windSensitivity * speedScale * dt
            // Personal wobble
            snowflakes[i].x += sin(time * snowflakes[i].wobbleFreq + snowflakes[i].wobblePhase)
                                * snowflakes[i].wobbleAmp * dt

            // Off the bottom → reset to just above the top
            if snowflakes[i].y > screenSize.height + snowflakes[i].size + 2 {
                snowflakes[i].y = -(snowflakes[i].size + 2)
                snowflakes[i].x = CGFloat.random(in: -20...(screenSize.width + 20))
            }
            // Horizontal wrap
            if snowflakes[i].x < -30 {
                snowflakes[i].x = screenSize.width + 30
            } else if snowflakes[i].x > screenSize.width + 30 {
                snowflakes[i].x = -30
            }
        }

        tick &+= 1
    }

    private func makeFlake(startY: CGFloat, rng: inout SeededRNG) -> Snowflake {
        let size = CGFloat(rng.next(in: 1.5...6.5))
        let sizeFactor = (size - 1.5) / 5.0
        return Snowflake(
            x: CGFloat(rng.next(in: -20...max(Double(screenSize.width) + 20, 1))),
            y: startY,
            size: size,
            fallSpeed: CGFloat(rng.next(in: 40...120)) * (0.5 + sizeFactor * 0.8),
            wobbleAmp: CGFloat(rng.next(in: 0.3...1.8)),
            wobbleFreq: CGFloat(rng.next(in: 0.4...2.2)),
            wobblePhase: CGFloat(rng.next(in: 0...(2 * Double.pi))),
            windSensitivity: CGFloat(rng.next(in: 0.6...1.4)) * (1.2 - sizeFactor * 0.6),
            opacity: rng.next(in: 0.35...0.92)
        )
    }
}

// MARK: - SwiftUI view

struct SnowflakeView: View {
    @Environment(SnowSettings.self) private var settings
    @StateObject private var model = SnowflakeAnimationModel()

    var body: some View {
        Canvas { context, size in
            // Rebuild flakes only when settings or screen size changed
            model.configure(size: size, settings: settings)

            // Reading tick makes SwiftUI invalidate & redraw this Canvas each timer fire
            _ = model.tick

            for flake in model.snowflakes {
                var ctx = context
                ctx.opacity = flake.opacity
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: flake.x - flake.size,
                        y: flake.y - flake.size,
                        width: flake.size * 2,
                        height: flake.size * 2
                    )),
                    with: .color(.white)
                )
            }
        }
        .ignoresSafeArea()
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
