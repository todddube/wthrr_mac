# wthrr

A macOS menu bar app that renders animated weather overlays (snow and rain) across all your displays. Purely decorative — no live weather data, just beautiful particle effects you can tweak from your menu bar.

![macOS](https://img.shields.io/badge/macOS-26.4+-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Snow & Rain modes** — switch between snowfall and rainfall; menu bar icon updates to match
- **Realistic snow crystals** — three procedurally drawn shapes (round pellets, 6-arm star plates, branching dendrites) sized by flake diameter; each crystal slowly spins and has a slight individual colour tint
- **Snow drift accumulation** — flakes pile up at the screen bottom with a smooth QuadCurve surface; drift depth is adjustable (Dusting → Blizzard) and the surface breathes via a slow melt when it reaches the cap
- **Dock awareness** — the overlay window sits below all app windows so the Dock naturally occludes the drift; geometry updates live when the Dock is resized or moved
- **Rain with splashes & puddles** — fast wind-angled streaks; expanding ripple splashes on impact; persistent puddles that grow and display ripple rings, with a specular highlight layer
- **Wind simulation** — smoothly varying gusts that tilt rain streaks and drift snowflakes; strength and direction change organically over time
- **Light & dark mode** — snow is blue-tinted in light mode with a subtle shadow pass; rain adapts its streak and puddle colours to the system appearance
- **Multi-display** — overlays span all connected displays, or choose specific monitors
- **Menu bar control** — lives entirely in the menu bar; no Dock icon, no windows to manage
- **Persistent settings** — all preferences saved to `UserDefaults` and restored on launch
- **Single instance** — automatically prevents duplicate copies from running
- **Lightweight** — ~60 fps SwiftUI `Canvas` rendering; transparent overlay windows pass all mouse events through

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
SnowSettings.shared          (@Observable singleton, persists to UserDefaults)
    |
    +-- ContentView           (MenuBarExtra popover — sliders, toggles, display picker)
    |
    +-- SnowflakeWindowController
            |
            +-- per-display NSWindow (borderless, transparent, below normal level)
                    |
                    +-- SnowflakeView (SwiftUI Canvas) + SnowflakeAnimationModel (~60 fps timer)
```

**Key components:**

| File | Role |
|------|------|
| `wthrrApp.swift` | App entry point, `MenuBarExtra` scene with dynamic icon, `AppDelegate` lifecycle |
| `SnowSettings.swift` | All user settings with `UserDefaults` persistence; weather-type display helpers |
| `ContentView.swift` | Menu bar popover UI — all controls adapt labels and visibility to weather type |
| `SnowflakeWindowController.swift` | Creates/manages one overlay `NSWindow` per active display; `ScreenGeometry` tracks Dock insets |
| `SnowflakeView.swift` | Dual-mode particle simulation (`SnowflakeAnimationModel`, `WindModel`, `SeededRNG`) and `Canvas` rendering for snow crystals, rain streaks, drift, splashes, and puddles |

## Usage

| Control | Range / Options | Description |
|---------|-----------------|-------------|
| Weather | Snow / Rain | Switch weather effect; menu bar icon and all labels update |
| Amount | 20–400 | Particles per screen ("flakes" or "drops") |
| Speed | 0.25×–3.0× | Fall speed (Gentle→Blizzard for snow; Mist→Monsoon for rain) |
| Wind | 0–100% | Wind strength (Calm→Storm); tilts rain streaks |
| Accumulation | On / Off | Snow: drift piles up. Rain: puddles grow at the bottom |
| Drift Depth | Dusting–Blizzard | Max drift height before melt keeps the surface steady (snow only, shown when accumulation is on) |
| Displays | All / Choose | Select which monitors show the overlay |
| Re-randomise | — | Generate a new particle layout ("Flakes" or "Drops") |

### Snow crystal types

Crystals are assigned by flake size with some randomised overlap at boundaries:

| Shape | Size range | Description |
|-------|-----------|-------------|
| Dot | < 3.5 pt | Round soft pellet (graupel) |
| Star | 3.5–6 pt | Hexagonal plate with 6 arms and crossbars |
| Dendrite | > 6 pt | Fully branching crystal with secondary and tertiary arms |

All shapes rotate slowly at individual speeds and carry a slight per-flake colour tint.

### Drift depth & melt

When accumulation is enabled, the **Drift Depth** slider sets the maximum height (Dusting ≈ 40 pt → Blizzard ≈ 300 pt). Once a column reaches that cap, landed flakes trigger a slow melt that removes a small amount of snow each frame. Columns near the cap melt gently; any temporary overshoot resolves quickly. The result is a living drift surface that breathes at a steady-state depth rather than freezing into a flat wall.

## Versioning

Version and build number are managed in Xcode build settings:
- `MARKETING_VERSION` — user-visible version (currently `1.0`)
- `CURRENT_PROJECT_VERSION` — monotonic build number

Edit via **Project Navigator → wthrr target → General tab**.

## Author

**Todd Dube** — [GitHub](https://github.com/todddube)

## License

MIT
