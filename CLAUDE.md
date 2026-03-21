# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**wthrr** is a macOS menu bar app that renders animated weather overlays across all connected displays. Effects include snow, rain, thunderstorm, fog, aurora borealis, and AI storm. It supports live weather data via Open-Meteo as well as fully manual, user-configurable effects.

## Build & Test

Use the Xcode MCP tools to build and validate:

- **Build**: `BuildProject` MCP tool
- **Code diagnostics**: `XcodeRefreshCodeIssuesInFile` for fast per-file feedback without a full build
- **Run snippets**: `ExecuteSnippet` to try logic in the context of an existing file
- **Tests**: `RunAllTests` / `RunSomeTests` MCP tools (Testing framework for unit tests, XCUIAutomation for UI tests)

There is no command-line build script — all builds go through Xcode.

## Architecture

The app uses a modular folder structure with clear separation between weather modules:

```
wthrr/
├── App/            wthrrApp.swift — entry point, AppDelegate, lifecycle, global hotkey
├── Models/         WeatherSettings, Particle, ScreenGeometry, WeatherPreset,
│                   HotkeyBinding, ColorTheme — shared data & domain types
├── Snow/           SnowParticle (shapes + factory), SnowRenderer (drawing)
├── Rain/           RainParticle (splash/puddle + factory), RainRenderer (drawing)
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer (neon effects)
├── Fog/            FogParticle (bands + factory), FogRenderer (gradient bands + wisps)
├── Aurora/         AuroraParticle (factory), AuroraRenderer (rippling vertical bands)
├── Clouds/         Cloud (factory), CloudRenderer (shared across rain/thunderstorm)
├── Animation/      WeatherAnimationModel — display-synced physics engine
├── Views/          WeatherView (TimelineView + Canvas), ContentView (menu bar popover),
│                   SplashView, OnboardingView, WhatsNewView
├── Windows/        OverlayWindowController — per-display overlay windows
└── Assets.xcassets
```

### `WeatherSettings` (`@Observable` singleton)
Central source of truth for all weather modes. Persists all settings to `UserDefaults` via `didSet`. Passed into SwiftUI views via `.environment(WeatherSettings.shared)`.

### Menu bar popover — `ContentView`
Shown inside a `MenuBarExtra`. Features:
- Live 64px weather preview strip at the top
- Icons-only segmented picker for weather type (with per-icon tooltips)
- Intensity quick-taps (Light / Medium / Heavy) with "Custom" label when manually adjusted
- Collapsible sections in order: Particles → Environment → Colors → Displays → Presets → Behavior
- Reroll/shuffle button in the header next to Pause
- Footer: "About" (plain, secondary) and "Quit" (plain, tertiary) — low prominence

### Overlay windows — `OverlayWindowController`
Manages one borderless `NSWindow` per active display. Windows sit just below normal window level, are fully transparent and ignore mouse events. Rebuilds windows on `NSApplication.didChangeScreenParametersNotification`.

### Weather animation — `WeatherView` + `WeatherAnimationModel`
- `WeatherAnimationModel` (`@Observable @MainActor`) advances particle physics each frame. Driven by `TimelineView(.animation)` which syncs redraws to the display refresh rate.
- `WindModel` simulates gusting wind with smoothed velocity transitions.
- `SeededRNG` (xorshift64) produces deterministic per-particle randomness.
- `WeatherView` uses `TimelineView(.animation)` + `Canvas`, delegating to the appropriate renderer.

### Snow module — `Snow/`
- `SnowShape` enum defines crystal types (dot, star, dendrite).
- `SnowParticleFactory` creates snowflakes with size-dependent shape distribution.
- `SnowRenderer` draws crystals with per-flake rotation and accumulated drift.

### Rain module — `Rain/`
- `Splash` and `Puddle` structs model rain-specific effects.
- `RainParticleFactory` creates thin, fast-falling rain streaks.
- `RainRenderer` draws wind-tilted streaks, expanding splashes, and puddles with shine/ripples.

### Fog module — `Fog/`
- `FogRenderer` draws slow-drifting translucent gradient bands and large soft wisp particles.

### Aurora module — `Aurora/`
- `AuroraRenderer` draws rippling vertical color bands using pure gradient animation (no particle physics).

### Clouds module — `Clouds/`
- `CloudRenderer` draws layered cloud shapes shared across rain and thunderstorm modes.

### AI Storm module — `AIStorm/`
- `ScanLine`, `DataBolt`, `CorruptionPatch`, `AlienShip`, `ScreenFracture` value types model digital glitch effects.
- `AIStormParticleFactory` creates neon glitch particles with erratic movement.
- `AIStormRenderer` draws glitch particles, scan lines, data bolts, corruption patches, alien ships, and screen fractures.

### Live Weather — `LiveWeatherService`
- Fetches real conditions from Open-Meteo using device location.
- Auto-applies weather type and intensity; shows location name + temperature in the header.
- Manual controls are disabled while live weather is active.

### Key data flow
```
WeatherSettings.shared
    ├── ContentView (menu bar popover) — reads/writes settings
    └── OverlayWindowController
            └── per-display NSWindow
                    └── WeatherView (TimelineView + Canvas) + WeatherAnimationModel
                            ├── SnowRenderer + SnowParticleFactory
                            ├── RainRenderer + RainParticleFactory
                            ├── FogRenderer + FogParticleFactory
                            ├── AuroraRenderer + AuroraParticleFactory
                            ├── AIStormRenderer + AIStormParticleFactory
                            └── CloudRenderer + CloudFactory  (shared)
```

## Versioning

Version and build number live in Xcode build settings:
- `MARKETING_VERSION` → user-visible version (e.g. `1.0.0`)
- `CURRENT_PROJECT_VERSION` → monotonically increasing build number

Edit via: **Project Navigator → wthrr target → General tab** (or Build Settings). `ContentView` reads both at runtime from `Bundle.main`.
