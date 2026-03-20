# FUTURE.md — wthrr Roadmap & Feature Ideas

Captured from brainstorming session. Items are grouped by theme; see CLAUDE.md for architecture context.

---

## Must-Have / High Impact

### Preset System
Save and load named configurations. Ship with built-in presets:
- *Blizzard*, *Light Flurry*, *Spring Rain*, *Monsoon*, *Glitch Overload*, *Digital Ghost*
- User-saveable presets with custom names
- Import/export as JSON for sharing between machines

### Seasonal / Time-of-Day Awareness
- Automatically switch to snow in winter, rain in spring, etc. based on system date
- Adjust particle opacity subtly based on system clock (dimmer at night)

### Color Theming
- **Snow**: tint color picker (cool blue, warm yellow for golden hour, etc.)
- **Rain**: streak color (gray, blue-green)
- **AI Storm**: swappable neon palette (cyberpunk cyan, synthwave purple, matrix green)
Personal color control dramatically increases perceived depth of the app.

---

## Polished UX Wins

### Global Pause / Resume Hotkey
User-configurable global keyboard shortcut to freeze/resume all effects instantly.
Essential for screencasts, video calls, and presentations.
Menu bar icon should reflect paused state visually.

### Pause Button in Settings
Single button to freeze all animations without quitting. Complements the global hotkey.

### Per-Display Settings
Different weather type on different monitors simultaneously.
Snow on the main display, rain on the secondary — strong visual wow factor for multi-display users.

### Intensity Quick-Tap Presets
Three tap targets below the sliders: **Light · Medium · Heavy**
Instantly sets amount + speed to sensible values. Faster than sliders for most users.

---

## Visual / Effect Upgrades

### Thunderstorm Mode
Composite weather type layering rain + lightning + dark cloud overlay + screen flashes.
Reuses existing renderers — mostly a settings preset + UI label.

### Fog / Mist Effect
Slow-drifting translucent gradient bands across the screen.
Very subtle, beautiful on dark wallpapers. Low physics complexity.

### Aurora Borealis
Slow rippling vertical bands of color (green / purple / teal) across the full screen.
Zero particle physics — purely canvas gradient animation. Would be visually unique among menu bar apps.

### Screen Frost (Snow Mode)
Ice crystal formations that slowly creep inward from screen edges at high accumulation levels.
Pure canvas path drawing, no physics required. Pairs naturally with the existing accumulation system.

---

## App Store / Distribution Polish

### Onboarding Flow
First-launch walkthrough: pick a weather style, set intensity, done in 3 taps.
Reduces friction for new users and showcases the visual range of the app immediately.

### Animated Menu Bar Icon
Extend the existing icon sync so the icon animates subtly:
- Snowflake rotates slowly (2–3 frame template image sequence)
- Lightning bolt pulses during AI Storm
- Raindrop falls and loops

### "What's New" on Update
A lightweight version of the splash screen that appears once after an update,
showing a brief changelog bullet or two. Version-gated by `CFBundleVersion`.

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
