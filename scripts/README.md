# wthrr — scripts

Build, package, and release scripts for wthrr. Run all scripts from the **repo root** or from anywhere — each script resolves its own `PROJECT_ROOT` from its location.

---

## Scripts

### `install.sh` — Build and install into /Applications

Runs the unit tests, builds Release, signs (Developer ID if present, otherwise ad-hoc), quits the running copy, replaces `/Applications/wthrr.app`, and relaunches it.

```bash
./scripts/install.sh               # full run
./scripts/install.sh --skip-tests  # skip unit tests
./scripts/install.sh --no-launch   # install without relaunching
./scripts/install.sh --dest ~/Applications
```

Logs land in `build/logs/` (`test.log`, `build.log`, `sign.log`). Exit codes: `0` ok, `1` no Xcode / bad flag, `2` tests failed, `3` build failed, `4` install failed. If `xcode-select` points at the Command Line Tools, the script uses the first `/Applications/Xcode*.app` automatically.

The Claude Code **app-builder** agent (`.claude/agents/app-builder.md`) wraps this script and reports failures as `file:line — message`.

---

### `build-dmg.sh` — Build the app and package a DMG installer

Compiles wthrr in Release configuration, generates the DMG background, then packages a styled `.dmg` using `create-dmg`.

```bash
# Full build + DMG (most common)
./scripts/build-dmg.sh

# Skip the Xcode build — re-package the existing .app into a fresh DMG
./scripts/build-dmg.sh --dmg-only

# Regenerate only the background image (no build, no DMG)
./scripts/build-dmg.sh --bg-only
```

**Output:** `build/wthrr-<version>.dmg`

**Prerequisites:**
```bash
brew install create-dmg
```

**What it does, step by step:**
1. Reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` from Xcode build settings
2. Regenerates `scripts/dmg-background.png` via `create_dmg_bg.py`
3. Cleans `build/` and runs `xcodebuild` (Release, **no code signing** — see Gatekeeper note below)
4. Locates `wthrr.app` inside `build/DerivedData`
5. Copies the app to a staging area (`build/stage/`)
6. Calls `create-dmg` to produce the final installer

**DMG window layout** (860×520 Finder window):
- wthrr.app icon at position (215, 260)
- Applications folder alias at position (645, 260)
- Icon size: 128 px (create-dmg maximum)
- Text size: 14 pt
- Background: `scripts/dmg-background.png` (1720×1040 @2x retina)

---

### `release.sh` — Tag and publish a GitHub Release

Creates a git tag, pushes it, then publishes a GitHub Release and attaches the DMG. Requires the DMG to already exist in `build/`.

```bash
# Publish a release
./scripts/release.sh 1.01b

# Publish as a draft (review on GitHub before making public)
./scripts/release.sh 1.01b --draft
```

**Prerequisites:**
```bash
brew install gh
gh auth login
```

**What it does, step by step:**
1. Validates that `build/wthrr-<version>.dmg` exists
2. Validates that `release-notes/<version>.md` exists
3. Warns if you have uncommitted changes and prompts to continue
4. Creates and pushes an annotated git tag `v<version>` (reuses existing tag if present)
5. If a GitHub Release for that tag already exists, deletes it first, then recreates it with the updated notes and DMG

**Typical full release workflow:**
```bash
# 1. Build the app and DMG
./scripts/build-dmg.sh

# 2. Write release notes
nano release-notes/1.01b.md

# 3. Commit, then publish
git add . && git commit -m "Release 1.01b"
./scripts/release.sh 1.01b
```

---

### `create_dmg_bg.py` — Generate the DMG background image

Pure Python 3 (stdlib only — no Pillow or dependencies). Produces `scripts/dmg-background.png` at 1720×1040 pixels (2× retina for the 860×520 Finder window).

```bash
# Run directly to regenerate the background
python3 scripts/create_dmg_bg.py

# Or via the shell script flag
./scripts/build-dmg.sh --bg-only
```

**Visual composition (8 phases):**

| Phase | Content |
|-------|---------|
| 1 | Aurora gradient wash — cyan → violet → green → magenta, fading in the lower half |
| 2 | "WTHRR" pixel-art title centered near the top in neon cyan with a soft glow |
| 3 | Neon teal arrow between the two drop-zone positions hinting at the drag-to-install action |
| 4 | Rain streaks in the right zone (angled, wind-driven) |
| 5 | Snowflakes in the left zone (six-arm crystals with tick marks) |
| 6 | Lightning bolt with yellow glow in the upper center |
| 7 | Fog wisps fading up from the bottom 20% |
| 8 | Sparkle stars scattered across the upper 74% |

**Drop-zone glow positions** (2× pixel space):
- wthrr.app → (430, 520)
- Applications → (1290, 520)

These match the `--icon` and `--app-drop-link` positions in `build-dmg.sh`. If you change the icon layout in the shell script, update `APP_CX/APP_CY` and `APPS_CX/APPS_CY` here to keep the glows and arrow aligned.

---

## Gatekeeper / First-launch

wthrr is built **without code signing or notarization**, so macOS Gatekeeper will quarantine the downloaded app. Users will see a crossed-out icon or an "unidentified developer" warning and cannot launch the app by double-clicking.

**Fix (run once in Terminal after dragging to Applications):**

```sh
xattr -dr com.apple.quarantine /Applications/wthrr.app
```

This removes the quarantine extended attribute that macOS sets on files downloaded from the internet. After running it, the app launches normally with no further prompts.

> If you ever want to distribute without this friction, the proper solution is to obtain an Apple Developer ID certificate, sign the build, notarize it with `notarytool`, and staple the ticket to the DMG.

---

## Versioning

Version numbers live in Xcode, not in these scripts. To update before a release:

- **Open Xcode** → select the `wthrr` target → **General** tab
  - `Version` field → `MARKETING_VERSION` (e.g. `1.01b`) — user-visible
  - `Build` field → `CURRENT_PROJECT_VERSION` (e.g. `0405`) — monotonically increasing

Both are read automatically by `build-dmg.sh` at build time.

---

## Outputs

| Path | Created by | Description |
|------|------------|-------------|
| `build/wthrr-<ver>.dmg` | `build-dmg.sh` | Distributable installer |
| `build/DerivedData/` | `build-dmg.sh` | Xcode derived data (gitignored) |
| `build/stage/` | `build-dmg.sh` | Staging area for create-dmg (gitignored) |
| `scripts/dmg-background.png` | `create_dmg_bg.py` | DMG Finder window background |
