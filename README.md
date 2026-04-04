# wthrr

Animated weather effects for your macOS desktop. Snow, rain, thunderstorms, fog, aurora borealis, and digital glitch storms — rendered across all your displays, controlled from the menu bar.

![macOS](https://img.shields.io/badge/macOS-26.4+-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

<p align="center">
  <img src="images/Snow.jpeg" alt="Snow mode" width="32%">
  <img src="images/Rain.jpeg" alt="Rain mode" width="32%">
  <img src="images/Fog.jpeg" alt="Fog mode" width="32%">
</p>
<p align="center">
  <img src="images/AI.jpeg" alt="AI Storm mode" width="32%">
  <img src="images/Haze.jpeg" alt="Haze / Aurora mode" width="32%">
</p>

---

## Weather Modes

### Snow
- Three procedural crystal shapes (graupel, star plates, branching dendrites) assigned by size
- Per-flake rotation, blue tint, and wobble driven by seeded RNG
- Drift accumulation with adjustable depth (Dusting to Blizzard) and steady-state melt
- Color theming via hue slider

### Rain
- Wind-angled streaks that tilt based on current wind velocity
- Expanding double-ring impact splashes with radiating droplet dots
- 8-12 persistent puddles with specular shine and ripple rings
- Color theming via hue slider

### Thunderstorm
- Heavy rain with forced lightning strikes and dark storm clouds
- Combines Rain renderer with always-on lightning and cloud overlay
- Dramatic composite effect — all the intensity knobs turned up

### Fog
- Slow-drifting translucent gradient bands across the screen
- Large soft wisp particles rendered with radial gradients
- Beautiful on dark wallpapers with very low performance cost
- Color theming via hue slider

### Aurora Borealis
- Slow rippling vertical bands of green, purple, and teal
- Pure gradient animation — no particle physics needed
- Mesmerizing, slow, and visually unique

### AI Storm
- Neon glitch particles with erratic movement and teleport glitches
- Scan line distortion, circuit-trace data bolts, corruption patches
- Alien ships with organic steering and fading trails
- Screen fracture crack patterns with impact flash effects
- 4 swappable color palettes: Cyberpunk, Synthwave, Matrix, Inferno

---

## Features

### Presets
- **9 built-in presets**: Blizzard, Light Flurry, Spring Rain, Monsoon, Thunderstorm, Foggy Morning, Aurora Borealis, Glitch Overload, Digital Ghost
- Save and load custom presets with named configurations
- Import/export presets as JSON for sharing between machines

### Intensity Quick-Taps
Three buttons — **Light**, **Medium**, **Heavy** — that instantly set amount, speed, wind, and opacity to sensible values. Active intensity is highlighted; "Custom" appears when sliders are manually adjusted.

### Pause & Global Hotkey
- Pause/Resume button freezes all effects instantly
- **Customizable global hotkey** (default: Cmd+Shift+P) — works even when the app isn't focused
- Menu bar icon reflects paused state
- Right-click context menu includes Pause/Resume

### Color Theming
- **Snow / Rain / Fog**: Hue slider with live preview swatch and "Reset to Default"
- **AI Storm**: 4 named neon palettes (Cyberpunk, Synthwave, Matrix, Inferno)
- Per-weather-type color that updates in real time

### Live Weather
- Pulls real conditions from Open-Meteo and auto-applies weather type + intensity
- Shows location name and temperature in the header
- Manual controls disabled while active

### Tuning Knobs
- **Snow melt rate** — control how fast drift melts (Slow to Rapid)
- **AI Storm density** — scales spawn rates for bolts, patches, fractures (Sparse to Chaotic)
- **Cloud opacity** — independent of cloud size (Faint to Dense)
- **Wind angle** — diagonal fall direction (-45 to +45 degrees)

### Display & Performance
- Overlays span all connected displays, or choose specific monitors
- Windows rebuild automatically on display changes
- **Low Power Mode** — limits animation to ~30 fps
- Transparent overlay windows pass all mouse events through
- Clean SIGTERM handling for graceful shutdown

### Behavior
- **Launch at Login** — start wthrr automatically when you log in
- **Seasonal auto-switch**: Snow in winter, Rain in spring, Thunderstorm in summer, Fog in autumn
- **Night dimming**: Subtly dims effects between 10pm–5am with dusk/dawn transitions

### Onboarding & Updates
- **First-launch walkthrough**: 3-step flow — Welcome, Pick Weather, Set Intensity
- **What's New screen**: Version-gated changelog shown once after each update, also accessible from the splash screen

### Settings Panel
Two-panel design: a compact menu bar popover for everyday controls, plus a dedicated Settings window for advanced configuration.

**Menu bar popover** — instant access controls:
- Live 64px weather preview strip
- Weather type picker (icon-only segmented control)
- Intensity quick-taps (Light / Medium / Heavy)
- Live Weather toggle + location status
- Display selection (All or Choose specific monitors)
- Shuffle/reroll button and Pause control in the header

**Settings window** (System Preferences-style icon toolbar, 4 tabs):
- **Appearance** — particle amount, speed, opacity; per-weather-type colour controls (hue sliders or AI Storm neon palettes); snow melt rate; AI Storm effect density
- **Environment** — wind strength, direction, fall angle; clouds (size, speed, opacity); snow drift accumulation depth; lightning frequency
- **Presets** — built-in + user presets as pill buttons; save, delete, import/export JSON
- **Behavior** — Launch at Login, Seasonal auto-switch, Night Dimming, Low Power Mode; links to About, Onboarding, What's New
- macOS vibrancy material background throughout

---

## Requirements

- macOS 26.4 or later
- Xcode 26+ (to build from source)

## Install

Download the latest `.dmg` from the [Releases](https://github.com/todddube/wthrr_mac/releases) page, open it, and drag **wthrr** into your Applications folder.

> **First launch:** macOS will show an "unidentified developer" warning because the app is distributed outside the App Store. Right-click (or Control-click) the app icon and choose **Open** — you only need to do this once.

## Building from Source

1. Clone the repo:
   ```bash
   git clone https://github.com/todddube/wthrr_mac.git
   cd wthrr_mac
   ```

2. Open in Xcode:
   ```bash
   open wthrr.xcodeproj
   ```

3. Select the **wthrr** scheme, choose **My Mac**, and hit **Cmd+R**.

The app appears as a weather icon in your menu bar. Click it to open the settings popover. Right-click for a quick context menu.

## Architecture

```
wthrr/
├── App/            Entry point, AppDelegate, lifecycle, global hotkey
├── Models/         WeatherSettings, Particle, ScreenGeometry, WeatherPreset,
│                   HotkeyBinding, ColorTheme
├── Snow/           SnowParticle (shapes + factory), SnowRenderer
├── Rain/           RainParticle (splash/puddle + factory), RainRenderer
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer
├── Fog/            FogParticle (bands + factory), FogRenderer
├── Aurora/         AuroraParticle (factory), AuroraRenderer
├── Clouds/         Cloud (factory), CloudRenderer
├── Animation/      WeatherAnimationModel (display-synced physics engine)
├── Views/          WeatherView, ContentView, SettingsWindowView, SplashView,
│                   OnboardingView, WhatsNewView
├── Windows/        OverlayWindowController (per-display overlay windows)
└── Assets.xcassets
```

### Data flow

```
WeatherSettings.shared          (@Observable @MainActor singleton)
    |
    +-- ContentView              (menu bar popover — core controls: type, intensity, displays)
    |
    +-- SettingsWindowView       (tabbed settings window — appearance, env, presets, behavior)
    |
    +-- OverlayWindowController
            |
            +-- per-display NSWindow (borderless, transparent, click-through)
                    |
                    +-- WeatherView (TimelineView + Canvas) + WeatherAnimationModel
                            |
                            +-- SnowRenderer      (snow)
                            +-- RainRenderer       (rain, thunderstorm)
                            +-- FogRenderer        (fog)
                            +-- AuroraRenderer     (aurora borealis)
                            +-- AIStormRenderer    (AI storm)
                            +-- CloudRenderer      (clouds, shared)
```

## Releasing

See [RELEASE.md](RELEASE.md) for the full release process — version bumping, DMG build, tagging, and publishing to GitHub Releases.

## Roadmap

See [FUTURE.md](FUTURE.md) for the full roadmap, remaining feature ideas, and monetization plan.

## Author

**Todd Dube** — [GitHub](https://github.com/todddube)

## License

MIT
