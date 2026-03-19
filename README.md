# wthrr

A macOS menu bar app that renders animated weather overlays (snow and rain) across all your displays. Purely decorative — no live weather data, just beautiful particle effects you can tweak from your menu bar.

![macOS](https://img.shields.io/badge/macOS-26.4+-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Snow Mode
- **Three procedural crystal shapes** — round pellets (graupel), 6-arm star plates with crossbars, and branching dendrites with secondary and tertiary arms; shape is assigned by flake size with randomised overlap at boundaries
- **Per-flake variation** — each crystal slowly spins at its own rotation speed, carries a slight individual blue tint, and has unique wobble characteristics driven by a seeded RNG
- **Drift accumulation** — flakes pile up at the screen bottom into a smooth QuadCurve surface; drift depth is adjustable from Dusting (~40 pt) to Blizzard (~300 pt); a steady-state melt keeps the surface breathing rather than freezing solid
- **Light & dark appearance** — snow is blue-tinted in light mode with a subtle shadow pass for contrast against bright wallpapers; pure white in dark mode

### Rain Mode
- **Wind-angled streaks** — thin, fast-falling rain streaks that tilt up to 25 degrees based on current wind velocity
- **Impact splashes** — expanding double-ring elliptical splashes at impact with four radiating droplet dots
- **Puddles** — 8-12 persistent puddles that grow as raindrops land nearby, each with a specular shine layer and expanding ripple rings triggered by nearby impacts
- **Adaptive colours** — streak, splash, and puddle colours shift between light blue-white (dark mode) and blue-grey (light mode)

### AI Storm Mode
- **Neon glitch particles** — erratically moving particles with occasional teleport glitches and digital-style rendering
- **Scan line distortion** — horizontal bands sweeping down at varying speeds with randomised neon colours
- **Circuit-trace data bolts** — right-angle lightning paths that flash on spawn and fade quickly
- **Corruption patches** — rectangular static regions that flicker in and out (toggled via Corruption setting)
- **Alien ships** — small craft with organic steering toward wandering targets, leaving fading trails
- **Screen fractures** — jagged radial crack patterns with impact flash effects

### Shared Systems
- **Wind simulation** — smoothly varying gusts that change direction and intensity over time; affects snowflake drift and rain streak angle; organic gust intervals with configurable overall strength (Calm to Storm)
- **Deterministic randomness** — xorshift64 seeded RNG ensures the same seed always produces the same particle population; re-randomise to get a fresh layout
- **Multi-display support** — overlays span all connected displays, or choose specific monitors; windows rebuild automatically when monitors are connected, disconnected, or reconfigured
- **Dock awareness** — the overlay window sits below all app windows so the Dock naturally occludes effects; optional "Over Dock" mode raises overlays above the Dock; geometry updates live when the Dock is resized or moved
- **Menu bar control** — lives entirely in the menu bar with a dynamic icon (snow cloud or rain cloud); no Dock icon, no windows to manage
- **Persistent settings** — all preferences saved to `UserDefaults` and restored on launch
- **Single instance** — automatically prevents duplicate copies from running
- **Lightweight** — display-synced SwiftUI `TimelineView` + `Canvas` rendering; transparent overlay windows pass all mouse events through; clean SIGTERM handling for graceful shutdown

## Screenshots

<!-- Add screenshots here -->

## Requirements

- macOS 26.4 or later
- Xcode 26+ (to build from source)

## Building

wthrr is a native SwiftUI app built entirely through Xcode — there is no command-line build script.

1. Clone the repo:
   ```bash
   git clone https://github.com/todddube/wthrr_mac.git
   cd wthrr_mac
   ```

2. Open in Xcode:
   ```bash
   open wthrr.xcodeproj
   ```

3. Select the **wthrr** scheme, choose **My Mac** as the run destination, and hit **Cmd+R**.

The app appears as a cloud icon (or rain cloud in rain mode) in your menu bar. Click it to open the settings popover.

## Architecture

```
wthrr/
├── App/            Entry point, AppDelegate, lifecycle management
├── Models/         WeatherSettings (singleton), Particle, ScreenGeometry
├── Snow/           SnowParticle (shapes + factory), SnowRenderer (crystal + drift drawing)
├── Rain/           RainParticle (splash/puddle types + factory), RainRenderer (streak + effect drawing)
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer (neon effects)
├── Animation/      WeatherAnimationModel (display-synced physics engine)
├── Views/          WeatherView (Canvas + TimelineView), ContentView (menu bar popover), SplashView
├── Windows/        OverlayWindowController (per-display overlay windows)
└── Assets.xcassets
```

### Data flow

```
WeatherSettings.shared          (@Observable singleton, persists to UserDefaults)
    |
    +-- ContentView              (MenuBarExtra popover — sliders, toggles, display picker)
    |
    +-- OverlayWindowController
            |
            +-- per-display NSWindow (borderless, transparent, click-through)
                    |
                    +-- WeatherView (TimelineView + Canvas) + WeatherAnimationModel
                            |
                            +-- SnowRenderer / SnowParticleFactory      (snow mode)
                            +-- RainRenderer / RainParticleFactory      (rain mode)
                            +-- AIStormRenderer / AIStormParticleFactory (AI storm mode)
```

### Key components

| Module | Files | Role |
|--------|-------|------|
| **App** | `wthrrApp.swift` | `@main` entry point, `MenuBarExtra` scene with dynamic weather icon, `AppDelegate` for lifecycle and single-instance enforcement |
| **Models** | `WeatherSettings.swift` | `@Observable` singleton holding all user settings with `UserDefaults` persistence; weather-type-aware display helpers (labels, icons, descriptions) |
| | `Particle.swift` | Shared `Particle` value type (position + physics), `WindModel` (gusting simulation), `SeededRNG` (xorshift64 deterministic randomness) |
| | `ScreenGeometry.swift` | Per-display geometry tracking dock insets and screen frames via `@Observable` |
| **Snow** | `SnowParticle.swift` | `SnowShape` enum (dot, star, dendrite) and `SnowParticleFactory` — creates flakes with size-dependent shape distribution |
| | `SnowRenderer.swift` | Stateless renderer: draws three crystal shapes with rotation and tint, plus smooth drift accumulation surface with edge stroke |
| **Rain** | `RainParticle.swift` | `Splash` and `Puddle` value types, `RainParticleFactory` — creates thin fast-falling streaks |
| | `RainRenderer.swift` | Stateless renderer: draws wind-tilted streaks, double-ring splashes with droplet dots, and puddles with specular shine and ripple rings |
| **AIStorm** | `AIStormParticle.swift` | `ScanLine`, `DataBolt`, `CorruptionPatch`, `AlienShip`, `ScreenFracture` value types and `AIStormParticleFactory` — creates neon glitch particles |
| | `AIStormRenderer.swift` | Stateless renderer: draws glitch particles, scan lines, circuit-trace data bolts, corruption patches, alien ships, and screen fractures |
| **Animation** | `WeatherAnimationModel.swift` | `@Observable @MainActor` model driving display-synced physics via `TimelineView`: particle movement, wind updates, snow accumulation + melt, rain splash spawning + puddle growth, AI storm effects |
| **Views** | `WeatherView.swift` | `TimelineView(.animation)` + `Canvas` that delegates to `SnowRenderer`, `RainRenderer`, or `AIStormRenderer` based on active weather type |
| | `ContentView.swift` | Menu bar popover UI with weather summary, settings controls, display picker, and `AboutView` footer |
| | `SplashView.swift` | Startup splash screen with live weather animation background, feature highlights, and auto-dismiss countdown |
| **Windows** | `OverlayWindowController.swift` | Creates/manages one borderless overlay `NSWindow` per active display; handles screen change notifications, window level toggling, and teardown |

## Usage

| Control | Range / Options | Description |
|---------|-----------------|-------------|
| Weather | Snow / Rain / AI Storm | Switch weather effect; menu bar icon and all labels update |
| Amount | 20-400 | Particles per screen ("flakes" or "drops") |
| Speed | 0.25x-3.0x | Fall speed (Gentle to Blizzard for snow; Mist to Monsoon for rain) |
| Wind | 0-100% | Wind strength (Calm to Storm); tilts rain streaks up to 25 degrees |
| Accumulation | On / Off | Snow: drift piles up. Rain: puddles form and grow at the bottom |
| Drift Depth | Dusting-Blizzard | Max drift height before melt keeps the surface steady (snow only, shown when accumulation is on) |
| Over Dock | On / Off | Raises overlay above the Dock instead of behind it |
| Displays | All / Choose | Select which monitors show the overlay |
| Re-randomise | — | Generate a new particle layout with a fresh random seed |

### Snow crystal types

Crystals are assigned by flake size with some randomised overlap at boundaries:

| Shape | Size range | Description |
|-------|-----------|-------------|
| Dot | < 3.5 pt | Round soft pellet (graupel), slightly oval |
| Star | 3.5-6 pt | Hexagonal plate with 6 arms, crossbars at 60% arm length, bright centre dot |
| Dendrite | > 6 pt | Fully branching crystal with main arms, secondary branches at 35% and 65%, and tertiary tips |

All shapes rotate slowly at individual speeds and carry a slight per-flake colour tint.

### Drift accumulation & melt

When accumulation is enabled, the **Drift Depth** slider sets the maximum height (Dusting ~ 40 pt to Blizzard ~ 300 pt). Snow deposits spread across adjacent columns for a natural profile. Every 30 frames a box-blur smoothing pass rounds the surface. Once a column reaches the cap, a slow melt removes a small amount each frame — columns near the cap melt gently while any overshoot resolves quickly. The result is a living drift surface that breathes at a steady-state depth.

### Rain effects

Raindrops spawn splashes on impact — each splash is a pair of expanding elliptical rings with four radiating droplet dots. When puddles mode is on, 8-12 puddles are placed randomly across the screen. Drops landing near a puddle grow it (capped at 18 pt) and trigger a ripple ring that expands and fades. Each puddle has a body ellipse, a specular shine highlight, and an active ripple layer.

### AI Storm mode

A digital glitch storm with neon-coloured particles that move erratically with occasional teleport glitches. Secondary effects include:

- **Scan lines** — horizontal distortion bands that sweep down the screen at varying speeds
- **Data bolts** — circuit-trace lightning with right-angle segments that flash briefly
- **Corruption patches** — rectangular static regions that appear and fade (enabled via the Corruption toggle)
- **Alien ships** — small craft that steer organically toward wandering target points, leaving fading trails
- **Screen fractures** — jagged crack patterns radiating from random impact points with a brief flash on spawn

## Versioning

Version and build number are managed in Xcode build settings:
- `MARKETING_VERSION` — user-visible version (currently `1.0`)
- `CURRENT_PROJECT_VERSION` — monotonic build number

Edit via **Project Navigator → wthrr target → General tab**.

## Author

**Todd Dube** — [GitHub](https://github.com/todddube)

## License

MIT
