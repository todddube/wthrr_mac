# wthrr

Animated weather effects for your macOS desktop — rendered across all your displays, controlled from the menu bar.

![macOS](https://img.shields.io/badge/macOS-26.4+-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green) ![Free](https://img.shields.io/badge/free-open--source-brightgreen)

---

## Screenshots

<p align="center">
  <a href="images/Snow.png"><img src="images/Snow.png" alt="Snow" width="32%"></a>
  <a href="images/Rain.png"><img src="images/Rain.png" alt="Rain" width="32%"></a>
  <a href="images/Thunderstorm.png"><img src="images/Thunderstorm.png" alt="Thunderstorm" width="32%"></a>
</p>
<p align="center">
  <a href="images/Fog.jpeg"><img src="images/Fog.jpeg" alt="Fog" width="32%"></a>
  <a href="images/Aurora.png"><img src="images/Aurora.png" alt="Aurora Borealis" width="32%"></a>
  <a href="images/AI%20Storm.png"><img src="images/AI%20Storm.png" alt="AI Storm" width="32%"></a>
</p>

<p align="center">
  <a href="images/Popup%20Menu.jpeg"><img src="images/Popup%20Menu.jpeg" alt="Menu bar popover" width="18%"></a>
  &nbsp;
  <a href="images/Settings%20Appearence.png"><img src="images/Settings%20Appearence.png" alt="Appearance settings" width="22%"></a>
  <a href="images/Settings%20Env.png"><img src="images/Settings%20Env.png" alt="Environment settings" width="22%"></a>
  <a href="images/Settings%20Presets.png"><img src="images/Settings%20Presets.png" alt="Presets" width="22%"></a>
  <a href="images/Settings%20Behavior.png"><img src="images/Settings%20Behavior.png" alt="Behavior settings" width="22%"></a>
</p>

---

## Install

Download the latest `.dmg` from the [Releases](https://github.com/todddube/wthrr_mac/releases) page, open it, and drag **wthrr** into your Applications folder.

> **First launch — Gatekeeper bypass**
>
> wthrr is distributed outside the App Store, so macOS will ask you to confirm it's safe the first time. Two easy ways — you only need to do this once:
>
> **Option 1 — Secondary-click (quickest)**
> Right-click (or Control-click) **wthrr** in Applications → choose **Open** → click **Open** in the dialog.
>
> **Option 2 — System Settings**
> Try to open wthrr normally. macOS will block it and show a notification. Open **System Settings → Privacy & Security**, scroll to the Security section, and click **"Open Anyway"** next to wthrr.
>
> <details>
> <summary>Terminal fallback (if neither option appears)</summary>
>
> ```sh
> xattr -dr com.apple.quarantine /Applications/wthrr.app
> ```
>
> </details>

---

## Weather Modes

### Clear Skies
Fair weather as its own scene. The sun tracks an arc across the sky driven by the local clock — low and golden on the left at sunrise, high and blue-white at midday, low on the right at sunset — with volumetric light shafts fanning out, lens-flare ghosts along the axis to screen centre, and drifting pollen motes that brighten and warm as they pass near the light. Large sunlit cumulus drift slowly beneath it, every cloud shaded from the same direction as the sun. After sunset the scene becomes a cratered moon over a field of twinkling stars. Birds cross the sky using the same flock controls as Aurora.

### Snow
Procedural snowfall with three crystal shapes (graupel dots, star plates, branching dendrites) assigned by size. Per-flake rotation, blue tint, and wobble. Drift accumulation with adjustable depth and steady-state melt.

### Rain
Wind-angled streaks, expanding double-ring impact splashes with radiating droplets, and persistent puddles with specular shine and ripple rings.

### Thunderstorm
Heavy rain combined with dark storm clouds, forced lightning strikes, and all intensity knobs turned up.

### Fog
Slow-drifting translucent gradient bands and large soft wisp particles. Beautiful on dark wallpapers with very low performance cost.

### Aurora Borealis
Rippling vertical bands of green, purple, and teal — pure gradient animation, no particle physics needed. Animated silhouette birds drift across the sky, flapping organically. Bird count, size, and wildness (per-bird variation) are all configurable in Appearance settings.

### AI Storm
Neon glitch particles, scan line distortion, circuit-trace data bolts, corruption patches, alien ships with organic steering, and screen fracture crack patterns. 4 swappable color palettes: Cyberpunk, Synthwave, Matrix, Inferno.

---

## Features

### Retro 8-bit Mode
Flip **Retro 8-bit** in the menu bar popover (or Settings → Appearance → Style) and every weather type redraws as chunky pixel art with a fixed console palette. The simulation underneath is unchanged — the same particles, clouds, bolts and timers are painted onto a coarse grid — so you can toggle it at any moment without resetting the scene, and Live Weather, presets and every slider keep working.

| Scene | In 8-bit |
|-------|----------|
| Clear Skies | Pixel sun with stepped, rotating dashed rays (orange at golden hour); cratered moon and twinkling four-point stars at night; blinking motes |
| Snow | Three flake sprites matching the dot / star / dendrite crystals; stepped drift with a white cap |
| Rain / Thunderstorm | Stair-stepped streaks that tilt with the wind, hopping splash droplets, tapered puddles, a blocky lightning bolt and notched screen flash |
| Fog | Broken, drifting scanlines that thin toward each bank's edges, plus three-row puffs |
| Aurora | Two-cell-wide curtain stripes with a magenta fringe and a dithered hem, over a starfield |
| AI Storm | Two-frame space invaders in place of alien ships, pixel glitch glyphs, crawling corruption noise and right-angle data bolts — still using your chosen neon palette |

Clouds are rasterised once per cloud into three-tone blocks (sunlit top, body, shadowed underside) and cached, and each layer is drawn with one fill per colour, so retro mode costs about the same as the smooth renderers. **Pixel Size** (Fine 3 pt / Classic 4 pt / Chunky 6 pt / Huge 8 pt) sets how coarse the grid is.

### Live Weather
Pulls real conditions from [Open-Meteo](https://open-meteo.com) and auto-applies weather type and intensity. Shows your location name and temperature in the header. Manual controls are disabled while active.

WMO weather codes map to the matching scene: clear and partly cloudy (0–3) to **Clear Skies**, fog (45, 48) to **Fog**, drizzle and rain (51–67, 80–82) to **Rain**, snow (71–77, 85–86) to **Snow**, and thunderstorms (95–99) to **Thunderstorm** with lightning.

### Presets
9 built-in presets (Blizzard, Light Flurry, Spring Rain, Monsoon, Thunderstorm, Foggy Morning, Aurora Borealis, Glitch Overload, Digital Ghost) plus save/load/delete of custom named presets. Import and export as JSON to share between machines.

### Intensity Quick-Taps
**Light / Medium / Heavy** buttons instantly set amount, speed, wind, and opacity to sensible values. Active level is highlighted; "Custom" appears when you've manually adjusted sliders.

### Pause & Global Hotkey
Pause/Resume button freezes all effects instantly. Customizable global hotkey (default: **Cmd+Shift+P**) works even when the app isn't focused. Menu bar icon reflects paused state.

### Color Theming
Snow, Rain, and Fog each have a hue slider with live preview. AI Storm has 4 named neon palettes. Colors update in real time.

### Multi-Display Support
Overlays span all connected displays, or pick specific monitors. Windows rebuild automatically when displays are added or removed.

### Behavior
- **Launch at Login** — start wthrr automatically when you log in
- **Seasonal auto-switch** — Snow in winter, Rain in spring, Thunderstorm in summer, Fog in autumn
- **Night dimming** — subtly dims effects between 10 pm–5 am with dusk/dawn transitions
- **Low Power Mode** — limits animation to ~30 fps
- **Max Frame Rate** — caps overlay redraws (30 / 60 / 120 / display native); defaults to 60, which looks identical to 120 for weather effects and roughly halves render work on ProMotion displays
- **Hidden overlays suspend** — an overlay that is fully covered by another window, or on a sleeping display, stops rendering entirely rather than drawing where nobody can see it
- **Performance readout** — live FPS and frame-time p50/p99 measured from wthrr's own frames, with `os_signpost` intervals (`frame`, `physics`) for Instruments
- **Adaptive Quality** — reduces particle count when wthrr misses its own frame budget, when wthrr's own CPU share exceeds the threshold, or when the battery is low off mains

Measured on an Apple M4 with a 6K display, heavy snow (400 flakes, accumulation and clouds on), both builds at the display refresh rate: **103% CPU before, 53% after** — a little over 2× faster. Capping to 30 fps takes it to 40%. Fog with 400 wisps went from 24% to 20% once its gradients stopped being rebuilt per particle per frame.

A `Canvas`-symbol renderer for snow crystals (rasterise each once, blit per flake) was also built and measured, and came out 3–5% *slower* than drawing the batched vector geometry directly — resampling a rotated, scaled bitmap per flake costs more than the strokes do. It was removed rather than kept.

### Screenshot Preview
Right-click the menu bar icon → **Screenshot Preview…** to open a clean 1280×800 window with a solid black background. Switch between all seven effects without leaving the window. Use **⌘⇧4** then click to capture frameable screenshots of any effect.

---

## Settings

A compact **menu bar popover** gives you everyday controls — weather type picker, intensity quick-taps, Retro 8-bit toggle, live weather toggle, display selection, and pause. The full **Settings window** (System Preferences-style icon toolbar) has a persistent **weather type picker** at the top so you can switch modes without leaving the window — controls update instantly to show options relevant to that type. Four tabs:

| Tab | Controls |
|-----|----------|
| **Appearance** | Retro 8-bit style and pixel size; particle amount, speed, opacity; per-weather colour controls; snow melt rate; AI Storm density; aurora bird count, size, and wildness |
| **Environment** | Wind strength/direction/angle; cloud size, speed, opacity; drift accumulation depth; lightning frequency |
| **Presets** | Built-in + user presets; save, delete, import/export JSON |
| **Behavior** | Launch at Login, Seasonal auto-switch, Night Dimming, Low Power Mode; Onboarding and What's New |

---

## Building from Source

**Requirements:** macOS 26.4+, Xcode 26+

```bash
git clone https://github.com/todddube/wthrr_mac.git
cd wthrr_mac
open wthrr.xcodeproj
```

Select the **wthrr** scheme, choose **My Mac**, and hit **Cmd+R**. The app appears as a weather icon in your menu bar.

To build a Release copy and install it straight into `/Applications` from the command line:

```bash
./scripts/install.sh              # tests → Release build → sign → replace /Applications/wthrr.app → relaunch
./scripts/install.sh --skip-tests # faster, skips the unit tests
```

The script quits the running copy before swapping the bundle and finds Xcode on its own even if `xcode-select` points at the Command Line Tools. In Claude Code, the project's **app-builder** agent (`.claude/agents/app-builder.md`) runs the same script and summarises any test or compile failures.

---

## Architecture

```
wthrr/
├── App/            Entry point, AppDelegate, lifecycle, global hotkey
├── Models/         WeatherSettings, Particle, ScreenGeometry, WeatherPreset,
│                   HotkeyBinding, ColorTheme, RenderBudget, PerformanceMonitor
├── Clear/          ClearParticle (SkyState + mote factory), ClearSkyRenderer
├── Birds/          BirdRenderer — shared flock used by Clear Skies and Aurora
├── Snow/           SnowParticle (shapes + factory), SnowRenderer
├── Rain/           RainParticle (splash/puddle + factory), RainRenderer
├── AIStorm/        AIStormParticle (glitch types + factory), AIStormRenderer
├── Fog/            FogParticle (bands + factory), FogRenderer
├── Aurora/         AuroraParticle (factory), AuroraRenderer
├── Clouds/         Cloud (factory), CloudRenderer
├── Retro/          PixelPainter (grid-snapped batch drawing + sprites), RetroPalette
│                   + RetroSprites, RetroRenderer (dispatch, clouds, birds) and
│                   per-scene 8-bit renderers for precipitation, sky, and AI Storm
├── Animation/      WeatherAnimationModel — display-synced physics engine
├── Views/          WeatherView, ContentView, SettingsWindowView, SplashView,
│                   OnboardingView, WhatsNewView, WeatherPreviewView
├── Windows/        OverlayWindowController — per-display overlay windows
└── Assets.xcassets
```

`WeatherSettings.shared` is the `@Observable` singleton that drives everything. All settings persist to `UserDefaults` via `didSet`. Each display gets its own borderless, transparent, click-through `NSWindow` managed by `OverlayWindowController`. Particle physics run in `WeatherAnimationModel`, driven by `TimelineView(.animation)` synced to the display refresh rate.

---

## Contributing

wthrr is free, open-source software and contributions are welcome — bug reports, feature ideas, new weather effects, or documentation improvements.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get started, code style guidelines, and how to submit a pull request.

[Open an issue](https://github.com/todddube/wthrr_mac/issues) to report a bug or suggest a feature.

---

## Releasing

See [RELEASE.md](RELEASE.md) for the full release process — version bumping, DMG build, tagging, and publishing to GitHub Releases.

## Roadmap

See [FUTURE.md](FUTURE.md) for planned features and ideas.

---

## Author

**Todd Dube** — [github.com/todddube](https://github.com/todddube)

## License

MIT — free to use, modify, and distribute. See [LICENSE](LICENSE) for details.
