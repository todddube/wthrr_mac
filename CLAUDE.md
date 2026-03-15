# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**wthrr** is a macOS menu bar app that renders an animated snowfall overlay across all connected displays. It has no live weather data — the snow effect is purely decorative and user-configurable.

## Build & Test

Use the Xcode MCP tools to build and validate:

- **Build**: `BuildProject` MCP tool
- **Code diagnostics**: `XcodeRefreshCodeIssuesInFile` for fast per-file feedback without a full build
- **Run snippets**: `ExecuteSnippet` to try logic in the context of an existing file
- **Tests**: `RunAllTests` / `RunSomeTests` MCP tools (Testing framework for unit tests, XCUIAutomation for UI tests)

There is no command-line build script — all builds go through Xcode.

## Architecture

The app has two parallel UI surfaces driven by a single shared state object:

### `SnowSettings` (`@Observable` singleton)
Central source of truth. Persists all settings to `UserDefaults` via `didSet`. Passed into SwiftUI views via `.environment(SnowSettings.shared)`.

### Menu bar popover — `ContentView`
Shown inside a `MenuBarExtra`. Lets the user adjust flake count, speed, wind, and which displays are active. Calls `AppDelegate.shared?.snowflakeWindowController?.applySettings()` when display selection changes.

### Overlay windows — `SnowflakeWindowController`
Manages one borderless `NSWindow` per active display. Windows sit just below normal window level (`NSWindow.Level.normal - 1`), are fully transparent and ignore mouse events. Rebuilds windows on `NSApplication.didChangeScreenParametersNotification`.

### Snow animation — `SnowflakeView` + `SnowflakeAnimationModel`
- `SnowflakeAnimationModel` (`@MainActor ObservableObject`) drives a ~60 fps `Timer` scheduled on `RunLoop.main`. Each tick calls `advance()` via `MainActor.assumeIsolated { }` (timer already runs on main thread).
- `WindModel` simulates gusting wind with smoothed velocity transitions.
- `SeededRNG` (xorshift64) produces deterministic per-flake randomness from `SnowSettings.randomSeed`.
- `SnowflakeView` renders with SwiftUI `Canvas` — reading `model.tick` each frame ensures the canvas invalidates and redraws.

### Key data flow
```
SnowSettings.shared
    ├── ContentView (menu bar popover) — reads/writes settings
    └── SnowflakeWindowController
            └── per-display NSWindow
                    └── SnowflakeView (Canvas) + SnowflakeAnimationModel
```

## Versioning

Version and build number live in Xcode build settings:
- `MARKETING_VERSION` → user-visible version (e.g. `1.0.0`)
- `CURRENT_PROJECT_VERSION` → monotonically increasing build number

Edit via: **Project Navigator → wthrr target → General tab** (or Build Settings). `ContentView` reads both at runtime from `Bundle.main`.
