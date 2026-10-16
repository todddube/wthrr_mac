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

For a Release build installed into `/Applications`, run `./scripts/install.sh` (or delegate to the
`app-builder` agent in `.claude/agents/`). It runs the unit tests, builds, signs, quits the running
copy, replaces the bundle and relaunches. `scripts/build-dmg.sh` / `scripts/release.sh` package releases.
If `xcode-select` points at the Command Line Tools, prefix raw `xcodebuild` calls with
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` (the install script does this itself).

## Architecture

The app uses a modular folder structure with clear separation between weather modules:

```
wthrr/
├── App/            wthrrApp.swift — entry point, AppDelegate, lifecycle, global hotkey
├── Models/         WeatherSettings, Particle, ScreenGeometry, WeatherPreset,
│                   HotkeyBinding, ColorTheme — shared data & domain types
│                   RenderBudget — resolves frame-rate cap + suspension per canvas
│                   PerformanceMonitor — frame-time percentiles + os_signpost intervals
├── Clear/          ClearParticle (SkyState + mote factory), ClearSkyRenderer
│                   (sun/moon arc, light shafts, lens flare, stars, motes)
├── Birds/          BirdRenderer — shared flock used by Clear Skies and Aurora
├── Snow/           SnowParticle (shapes + factory), SnowRenderer (drawing)
├── Rain/           RainParticle (splash/puddle + factory), RainRenderer (drawing)
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer (neon effects)
├── Fog/            FogParticle (bands + factory), FogRenderer (gradient bands + wisps)
├── Aurora/         AuroraParticle (factory), AuroraRenderer (rippling vertical bands)
├── Clouds/         Cloud (factory), CloudRenderer (shared across rain/thunderstorm)
├── Retro/          8-bit style: PixelPainter (grid-snapped batched cells, Bresenham lines,
│                   PixelSprite), RetroPalette + RetroSprites, RetroRenderer (dispatch,
│                   cached cloud rasterisation, birds), RetroPrecipitationRenderer,
│                   RetroSkyRenderer (clear/aurora/fog), RetroAIStormRenderer (invaders)
├── Animation/      WeatherAnimationModel — display-synced physics engine
├── Views/          WeatherView (TimelineView + Canvas), ContentView (menu bar popover),
│                   SettingsWindowView (tabbed settings window), SplashView,
│                   OnboardingView, WhatsNewView
├── Windows/        OverlayWindowController — per-display overlay windows
└── Assets.xcassets
```

### `WeatherSettings` (`@Observable` singleton)
Central source of truth for all weather modes. Persists all settings to `UserDefaults` via `didSet`. Passed into SwiftUI views via `.environment(WeatherSettings.shared)`.

### Menu bar popover — `ContentView`
Compact 350px popover shown on left-click. Contains only the controls users touch on every visit:
- Header: weather icon + temperature/label, shuffle/reroll button, Pause button with hover-reveal hotkey badge
- Live 64px weather preview strip
- Live Weather toggle (enables Open-Meteo auto-mode)
- Icons-only segmented weather type picker (disabled in live weather mode)
- Intensity quick-taps (Light / Medium / Heavy) with "Custom" label when manually adjusted
- Retro 8-bit switch (pixel size is in Settings → Appearance → Style)
- Display selection (All / Choose with per-screen toggles)
- Footer: "Settings" button (opens SettingsWindowView) and "Quit"

### Settings window — `SettingsWindowView`
Dedicated 520×530 tabbed settings window (System Preferences style icon toolbar). Four tabs:
- **Appearance** (scrolls) — Style (Retro 8-bit, pixel size) + Particles (amount, speed, opacity, melt rate, AI density) + per-weather-type colour controls
- **Environment** — Wind (strength, direction, fall angle) + Atmosphere (clouds, accumulation/drift, lightning)
- **Presets** — Save/load/delete named presets, import/export JSON, built-in preset pills
- **Behavior** — Launch at Login, Seasonal auto-switch, Night Dimming, Low Power Mode, About/links (Onboarding, What's New)

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

### Retro 8-bit mode — `Retro/`
- `WeatherSettings.retroModeEnabled` / `retroPixelSize` (one of `RetroPalette.pixelSizeOptions`).
- `WeatherView` still runs `configure` + `advance` every frame, then hands the whole frame to
  `RetroRenderer.draw` instead of the smooth renderers. Retro is presentation-only: never add
  simulation state for it; read what `WeatherAnimationModel` already exposes.
- Draw through `PixelPainter`: register inks back-to-front, paint grid cells, `flush` once. One
  fill per ink keeps a frame to a handful of draw calls. Quantise fades with `PixelPainter.stepped`.
- Colours come only from `RetroPalette` (user hues snap via `RetroPalette.nearest`); AI Storm uses
  `NeonPalette` so the palette picker still applies.
- When adding a weather type, add a retro branch in `RetroRenderer.draw` too.
- `BirdRenderer.poses(...)` is the single source of flock motion for both styles.

### Live Weather — `LiveWeatherService`
- Fetches real conditions from Open-Meteo using device location.
- Auto-applies weather type and intensity; shows location name + temperature in the header.
- Manual controls are disabled while live weather is active.

### Key data flow
```
WeatherSettings.shared
    ├── ContentView (menu bar popover) — core controls: type, intensity, retro toggle, displays
    ├── SettingsWindowView (settings window) — advanced: appearance, env, presets, behavior
    └── OverlayWindowController
            └── per-display NSWindow
                    └── WeatherView (TimelineView + Canvas) + WeatherAnimationModel
                            ├── SnowRenderer + SnowParticleFactory
                            ├── RainRenderer + RainParticleFactory
                            ├── FogRenderer + FogParticleFactory
                            ├── AuroraRenderer + AuroraParticleFactory
                            ├── AIStormRenderer + AIStormParticleFactory
                            ├── CloudRenderer + CloudFactory  (shared)
                            └── RetroRenderer  (replaces all of the above when retro mode is on)
```

## Versioning

Version and build number live in Xcode build settings:
- `MARKETING_VERSION` → user-visible version (e.g. `1.0.0`)
- `CURRENT_PROJECT_VERSION` → monotonically increasing build number

Edit via: **Project Navigator → wthrr target → General tab** (or Build Settings). `ContentView` reads both at runtime from `Bundle.main`.
