# FUTURE.md — wthrr Roadmap

See [README.md](README.md) for the full list of currently implemented features.

---

## Remaining Ideas

### Screen Frost (Snow Mode)
Ice crystal formations that slowly creep inward from screen edges at high accumulation levels.
Pure canvas path drawing, no physics required. Pairs naturally with the existing accumulation system.
**Effort: Medium** — most visually stunning remaining idea, strong Snow mode differentiator.

### Per-Display Settings
Different weather type on different monitors simultaneously.
Snow on the main display, rain on the secondary — strong visual wow factor for multi-display users.
**Effort: High** — requires per-screen WeatherSettings architecture rethink.

### Adaptive Quality
Auto-reduce particle count when CPU exceeds a threshold, or when battery drops below a configurable %.
Prevents the app from spinning up fans on MacBooks; users notice when a fun app hurts battery life.
**Effort: Medium** — pairs naturally with the existing Low Power Mode toggle.

### Additional Tuning Knobs
- Puddle ripple speed (currently 40 pts/sec hardcoded)
- Puddle growth rate per raindrop (currently 0.025 height/hit hardcoded)
- Lightning bolt duration (currently 0.30-0.45 sec hardcoded)
- Accumulation rate slider
- Per-cloud speed variance

### Performance
- Offscreen particle culling
- Battery % threshold to trigger Low Power mode automatically

---

## Monetization

See [specs_money.md](specs_money.md) for the full monetization plan including:

- **$4.99 one-time license** via LemonSqueezy
- **14-day full trial** then 10-minute sessions
- **LicenseManager** with Keychain storage
- **Sparkle auto-updates** for direct distribution
- **Code signing + notarization** ($99/year Apple Developer Program)
- **Marketing plan** with Product Hunt, Reddit, Hacker News launch strategy
- **90-day launch calendar**

### Implementation Phases (from specs_money.md)

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | LicenseManager (Keychain, API validation) | Not started |
| 2 | Trial + session timer logic | Not started |
| 3 | License prompt UI | Not started |
| 4 | LemonSqueezy account setup | Not started |
| 5 | Polish (offline handling, error states) | Not started |

---

## Completed Features

All items below have been implemented and are in the current codebase.

- **Dedicated Settings Window** — tabbed System Preferences-style window (520×530) with 4 tabs: Appearance, Environment, Presets, Behavior; opened via Settings button in the compact popover or right-click context menu (Cmd+,)
- **Compact Popover Redesign** — menu bar popover streamlined to core everyday controls only (weather type, intensity, live weather, displays); advanced settings moved to the dedicated Settings window
- **Preset System** — 9 built-in presets, user-saveable presets, JSON import/export, empty-state hint
- **Seasonal / Time-of-Day Awareness** — auto-switch by month, night dimming 10pm-5am
- **Color Theming** — hue sliders for snow/rain/fog/aurora, 4 AI Storm palettes (Cyberpunk, Synthwave, Matrix, Inferno)
- **Global Pause / Resume Hotkey** — customizable shortcut (default Cmd+Shift+P), menu bar icon reflects state
- **Intensity Quick-Tap Presets** — Light / Medium / Heavy buttons; "Custom" label when manually adjusted
- **Thunderstorm Mode** — composite rain + forced lightning + forced clouds
- **Fog / Mist Effect** — drifting gradient bands + soft wisp particles
- **Aurora Borealis** — rippling vertical color bands, pure gradient animation
- **Onboarding Flow** — 3-step first-launch walkthrough
- **"What's New" on Update** — version-gated changelog screen, also accessible from splash + settings
- **Animated Menu Bar Icon** — 3-frame animation per weather type, pauses when effects are paused
- **Tuning Knobs** — snow melt rate, AI Storm density, cloud opacity, wind angle
- **macOS Vibrancy** — .regularMaterial background on popover and settings window
- **Live Weather** — Open-Meteo integration, auto weather type + intensity, location name + temperature in header
- **Settings Panel UX Polish**:
  - Live 64px weather preview strip at the top of the popover
  - Icons-only segmented weather type picker with per-icon hover tooltips
  - Reroll/shuffle button in the header next to Pause
  - Wind + Atmosphere merged into single "Environment" tab
  - Right-click context menu includes Settings (Cmd+,), Open wthrr, Pause/Resume, About, Quit
