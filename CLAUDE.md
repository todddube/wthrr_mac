# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**wthrr** is a macOS menu bar app that renders animated weather overlays (snow, rain, and AI storm) across all connected displays. It has no live weather data — the effects are purely decorative and user-configurable.

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
├── App/            wthrrApp.swift — entry point, AppDelegate, lifecycle
├── Models/         WeatherSettings, Particle, ScreenGeometry — shared data
├── Snow/           SnowParticle (shapes + factory), SnowRenderer (drawing)
├── Rain/           RainParticle (splash/puddle + factory), RainRenderer (drawing)
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer (neon effects)
├── Animation/      WeatherAnimationModel — display-synced physics engine
├── Views/          WeatherView (TimelineView + Canvas), ContentView (menu bar popover), SplashView
├── Windows/        OverlayWindowController — per-display overlay windows
└── Assets.xcassets
```

### `WeatherSettings` (`@Observable` singleton)
Central source of truth for both snow and rain modes. Persists all settings to `UserDefaults` via `didSet`. Passed into SwiftUI views via `.environment(WeatherSettings.shared)`.

### Menu bar popover — `ContentView`
Shown inside a `MenuBarExtra`. Lets the user adjust particle count, speed, wind, weather type, and which displays are active. Calls `AppDelegate.shared?.overlayWindowController?.applySettings()` when display selection changes.

### Overlay windows — `OverlayWindowController`
Manages one borderless `NSWindow` per active display. Windows sit just below normal window level, are fully transparent and ignore mouse events. Rebuilds windows on `NSApplication.didChangeScreenParametersNotification`.

### Weather animation — `WeatherView` + `WeatherAnimationModel`
- `WeatherAnimationModel` (`@Observable @MainActor`) advances particle physics each frame. Driven by `TimelineView(.animation)` which syncs redraws to the display refresh rate.
- `WindModel` simulates gusting wind with smoothed velocity transitions.
- `SeededRNG` (xorshift64) produces deterministic per-particle randomness.
- `WeatherView` uses `TimelineView(.animation)` + `Canvas`, delegating to `SnowRenderer`, `RainRenderer`, or `AIStormRenderer`.

### Snow module — `Snow/`
- `SnowShape` enum defines crystal types (dot, star, dendrite).
- `SnowParticleFactory` creates snowflakes with size-dependent shape distribution.
- `SnowRenderer` draws crystals with per-flake rotation and accumulated drift.

### Rain module — `Rain/`
- `Splash` and `Puddle` structs model rain-specific effects.
- `RainParticleFactory` creates thin, fast-falling rain streaks.
- `RainRenderer` draws wind-tilted streaks, expanding splashes, and puddles with shine/ripples.

### AI Storm module — `AIStorm/`
- `ScanLine`, `DataBolt`, `CorruptionPatch`, `AlienShip`, `ScreenFracture` value types model digital glitch effects.
- `AIStormParticleFactory` creates neon glitch particles with erratic movement.
- `AIStormRenderer` draws glitch particles, scan lines, data bolts, corruption patches, alien ships, and screen fractures.

### Key data flow
```
WeatherSettings.shared
    ├── ContentView (menu bar popover) — reads/writes settings
    └── OverlayWindowController
            └── per-display NSWindow
                    └── WeatherView (TimelineView + Canvas) + WeatherAnimationModel
                            ├── SnowRenderer + SnowParticleFactory
                            ├── RainRenderer + RainParticleFactory
                            └── AIStormRenderer + AIStormParticleFactory
```

## Versioning

Version and build number live in Xcode build settings:
- `MARKETING_VERSION` → user-visible version (e.g. `1.0.0`)
- `CURRENT_PROJECT_VERSION` → monotonically increasing build number

Edit via: **Project Navigator → wthrr target → General tab** (or Build Settings). `ContentView` reads both at runtime from `Bundle.main`.
