# FUTURE.md — wthrr Roadmap & Feature Ideas

Captured from brainstorming session. Items are grouped by theme; see CLAUDE.md for architecture context.

---

## Must-Have / High Impact

### ~~Preset System~~ ✅ Implemented
Save and load named configurations. Ship with built-in presets:
- ~~*Blizzard*, *Light Flurry*, *Spring Rain*, *Monsoon*, *Glitch Overload*, *Digital Ghost*~~ ✅
- ~~User-saveable presets with custom names~~ ✅
- ~~Import/export as JSON for sharing between machines~~ ✅

### ~~Seasonal / Time-of-Day Awareness~~ ✅ Implemented
- ~~Automatically switch to snow in winter, rain in spring, etc. based on system date~~ ✅
- ~~Adjust particle opacity subtly based on system clock (dimmer at night)~~ ✅
Toggle in Behavior section. Winter→Snow, Spring→Rain, Summer→Thunderstorm, Autumn→Fog. Night dimming 10pm-5am.

### ~~Color Theming~~ ✅ Implemented
- ~~**Snow**: tint color picker (cool blue, warm yellow for golden hour, etc.)~~ ✅
- ~~**Rain**: streak color (gray, blue-green)~~ ✅
- ~~**AI Storm**: swappable neon palette (cyberpunk cyan, synthwave purple, matrix green)~~ ✅
Hue sliders for snow/rain/fog with "Default" reset. AI Storm has 4 named palettes (Cyberpunk, Synthwave, Matrix, Inferno).

---

## Polished UX Wins

### ~~Global Pause / Resume Hotkey~~ ✅ Implemented
~~User-configurable global keyboard shortcut to freeze/resume all effects instantly.~~
~~Essential for screencasts, video calls, and presentations.~~
~~Menu bar icon should reflect paused state visually.~~
Global hotkey: Cmd+Shift+P. Menu bar icon shows pause state. Also in right-click context menu.

### ~~Pause Button in Settings~~ ✅ Implemented
~~Single button to freeze all animations without quitting. Complements the global hotkey.~~

### Per-Display Settings
Different weather type on different monitors simultaneously.
Snow on the main display, rain on the secondary — strong visual wow factor for multi-display users.

### ~~Intensity Quick-Tap Presets~~ ✅ Implemented
~~Three tap targets below the sliders: **Light · Medium · Heavy**~~
~~Instantly sets amount + speed to sensible values. Faster than sliders for most users.~~
Sets amount, speed, wind, and opacity. Active intensity is highlighted.

---

## Visual / Effect Upgrades

### ~~Thunderstorm Mode~~ ✅ Implemented
~~Composite weather type layering rain + lightning + dark cloud overlay + screen flashes.~~
~~Reuses existing renderers — mostly a settings preset + UI label.~~
New WeatherType. Uses RainRenderer + forced lightning + forced clouds. Built-in "Thunderstorm" preset.

### ~~Fog / Mist Effect~~ ✅ Implemented
~~Slow-drifting translucent gradient bands across the screen.~~
~~Very subtle, beautiful on dark wallpapers. Low physics complexity.~~
New WeatherType with FogRenderer + FogParticleFactory. Drifting gradient bands + blurred wisp particles. Built-in "Foggy Morning" preset.

### Aurora Borealis
Slow rippling vertical bands of color (green / purple / teal) across the full screen.
Zero particle physics — purely canvas gradient animation. Would be visually unique among menu bar apps.

### Screen Frost (Snow Mode)
Ice crystal formations that slowly creep inward from screen edges at high accumulation levels.
Pure canvas path drawing, no physics required. Pairs naturally with the existing accumulation system.

---

## App Store / Distribution Polish

### ~~Onboarding Flow~~ ✅ Implemented
~~First-launch walkthrough: pick a weather style, set intensity, done in 3 taps.~~
~~Reduces friction for new users and showcases the visual range of the app immediately.~~
3-step flow: Welcome → Pick Weather (5 types) → Set Intensity (Light/Medium/Heavy). Gated by UserDefaults.

### Animated Menu Bar Icon
Extend the existing icon sync so the icon animates subtly:
- Snowflake rotates slowly (2–3 frame template image sequence)
- Lightning bolt pulses during AI Storm
- Raindrop falls and loops

### ~~"What's New" on Update~~ ✅ Implemented
~~A lightweight version of the splash screen that appears once after an update,~~
~~showing a brief changelog bullet or two. Version-gated by `CFBundleVersion`.~~
WhatsNewView with animated changelog entries. Version-gated by build number. Updates entries array each release.

---

## AI Storm Tuning Knobs
All currently hardcoded; candidates for future sliders:
- Data bolt spawn rate (currently 3–10 sec interval)
- Corruption patch density (currently 0.3–1.5 sec when enabled)
- Screen fracture interval (currently 5–15 sec)
- Alien ship count (currently 2–4, 0.1% spawn chance)
- Effect Density slider grouping all of the above

## Rain / Snow Behavior Knobs
- Snow melt rate (currently 0.08/frame hardcoded)
- Puddle ripple speed (currently 40 pts/sec hardcoded)
- Puddle growth rate per raindrop (currently 0.025 height/hit hardcoded)
- Lightning bolt duration (currently 0.30–0.45 sec hardcoded)
- Accumulation Rate slider

## Cloud Behavior
- Per-cloud speed variance (currently random 12–40 pts/s with no user control)
- Cloud opacity independent of size

## Wind
- Wind angle control (diagonal fall instead of purely horizontal drift)
- Wind gust visual indicator in the UI

---

## Performance
- Adaptive quality: reduce particle count automatically when CPU > threshold
- Offscreen particle culling
- Battery % threshold to trigger Low Power mode automatically (not just system toggle)
