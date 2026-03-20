# FUTURE.md — wthrr Roadmap

See [README.md](README.md) for the full list of currently implemented features.

---

## Completed Features

All items below have been implemented and are in the current codebase.

- **Preset System** — 9 built-in presets, user-saveable presets, JSON import/export
- **Seasonal / Time-of-Day Awareness** — auto-switch by month, night dimming 10pm-5am
- **Color Theming** — hue sliders for snow/rain/fog, 4 AI Storm palettes (Cyberpunk, Synthwave, Matrix, Inferno)
- **Global Pause / Resume Hotkey** — customizable shortcut (default Cmd+Shift+P), menu bar icon reflects state
- **Pause Button in Settings** — centered below weather summary
- **Intensity Quick-Tap Presets** — Light / Medium / Heavy buttons
- **Thunderstorm Mode** — composite rain + forced lightning + forced clouds
- **Fog / Mist Effect** — drifting gradient bands + soft wisp particles
- **Aurora Borealis** — rippling vertical color bands, pure gradient animation
- **Onboarding Flow** — 3-step first-launch walkthrough
- **"What's New" on Update** — version-gated changelog screen
- **Animated Menu Bar Icon** — 3-frame animation per weather type, pauses when effects are paused
- **Tuning Knobs** — snow melt rate, AI Storm density, cloud opacity, wind angle
- **Collapsible Settings Sections** — persisted expand/collapse state, summary badges
- **macOS Vibrancy** — .regularMaterial background on settings popover

---

## Remaining Ideas

### Per-Display Settings
Different weather type on different monitors simultaneously.
Snow on the main display, rain on the secondary — strong visual wow factor for multi-display users.
**Effort: High** — requires per-screen WeatherSettings architecture.

### Screen Frost (Snow Mode)
Ice crystal formations that slowly creep inward from screen edges at high accumulation levels.
Pure canvas path drawing, no physics required. Pairs naturally with the existing accumulation system.

### Additional Tuning Knobs
- Puddle ripple speed (currently 40 pts/sec hardcoded)
- Puddle growth rate per raindrop (currently 0.025 height/hit hardcoded)
- Lightning bolt duration (currently 0.30-0.45 sec hardcoded)
- Accumulation rate slider
- Per-cloud speed variance

### Performance
- Adaptive quality: reduce particle count automatically when CPU > threshold
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
