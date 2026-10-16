# Release Process

## Prerequisites

- [Homebrew](https://brew.sh) installed
- `create-dmg` installed: `brew install create-dmg`
- `gh` CLI installed and authenticated: `brew install gh && gh auth login`
- Xcode with the `wthrr` scheme building cleanly

---

## Step 1 — Bump the Version in Xcode

1. Open `wthrr.xcodeproj` in Xcode
2. Go to **Project Navigator → wthrr target → General tab**
3. Update:
   - **Version** (`MARKETING_VERSION`) — user-visible, e.g. `1.1`
   - **Build** (`CURRENT_PROJECT_VERSION`) — monotonically increasing integer
4. Commit the version bump before tagging

---

## Step 1b — Run the Tests

```bash
xcodebuild -project wthrr.xcodeproj -scheme wthrr -destination 'platform=macOS' test
```

The suite covers the pure logic — sun position, render budget, seeded RNG, factories,
crystal geometry, weather-type persistence. It runs in well under a second.

---

## Step 2 — Build the DMG

```bash
./scripts/build-dmg.sh
```

Produces `build/wthrr-<version>.dmg`. The script:
1. Renders the styled DMG background (aurora gradient, no external deps)
2. Builds the Release `.app` via `xcodebuild`
3. Packages it into a Finder-window DMG with an Applications shortcut

---

## Step 3 — Write Release Notes

Create `release-notes/<version>.md` (e.g. `release-notes/1.1.md`).

Use the entries from `WhatsNewView.swift` as the source of truth — group them into sections matching the in-app changelog. See `release-notes/1.0b.md` as a template.

---

## Step 4 — Tag and Publish

```bash
./scripts/release.sh <version>
```

For example:

```bash
./scripts/release.sh 1.1
```

The script will:
1. Create annotated git tag `v<version>`
2. Push the tag to GitHub
3. Create a GitHub Release titled `wthrr v<version>`
4. Attach the DMG from `build/wthrr-<version>.dmg`
5. Use `release-notes/<version>.md` as the release body

To publish as a draft first:

```bash
./scripts/release.sh 1.1 --draft
```

---

## Release History

| Version | Date       | Notes |
|---------|------------|-------|
| v1.2    | 2026-10-16 | [Release notes](release-notes/1.2.md) — Retro 8-bit mode for every weather type, pixel size picker, `scripts/install.sh` + app-builder agent |
| v1.1    | 2026-08-09 | [Release notes](release-notes/1.1.md) — Clear Skies weather mode, Live Weather WMO mapping fixes, ~2× CPU reduction, frame-rate cap, occlusion suspension, Swift 6, unit test target |
| v1.0    | 2026-07-02 | [Release notes](release-notes/1.0.md) — open-source release under MIT |
| v1.0b2  | 2026-03-22 | [Release notes](release-notes/1.0b.md) — full 1.0b feature set: Aurora, Thunderstorm, Fog, AI Storm, Live Weather, presets, color theming, multi-display, Launch at Login |

---

## CI Workflow

`.github/workflows/build.yml` triggers on `v*` tags and:
1. Builds the DMG from source on macOS 15
2. Creates a GitHub Release using `release-notes/<version>.md` if it exists, otherwise auto-generates notes

This is useful for CI-verified builds. The local `scripts/release.sh` path is preferred for releases that are already built and tested locally.
