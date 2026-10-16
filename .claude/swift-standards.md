# wthrr — project Swift standards

Overrides and project facts for the `swift-code-reviewer` agent. Where this file and
`~/.claude/swift-standards.md` disagree, this file wins.

Last verified: 2026-10-16

## Platform baseline

| Setting | Value |
|---|---|
| Build system | Xcode project (`wthrr.xcodeproj`), no SwiftPM manifest |
| Toolchain seen | Apple Swift 6.4 (Xcode-beta, `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`) |
| `SWIFT_VERSION` | 6.0 (Swift 6 language mode) |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES |
| `MACOSX_DEPLOYMENT_TARGET` | 26.4 |
| `MARKETING_VERSION` | 1.1 |
| Targets | `wthrr` (app), `wthrrTests` (swift-testing) |

## Header target labels

The project does not use the global `<Target> · <Project>` header. Every file uses:

```swift
// FileName.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI
```

| Path | Line 2 label |
|---|---|
| `wthrr/**` | `wthrr — macOS decorative weather overlay` |
| `wthrrTests/**` | `wthrr — macOS decorative weather overlay` (same) |

## Existing conventions (do not flag)

- Header style above, not the global one. No one-line summary in the header; the
  type's `///` comment carries the role.
- Imports are **not** ASCII-sorted: the primary framework comes first (`SwiftUI`,
  `Testing`), then others (e.g. `import SwiftUI` / `import Darwin`). In tests,
  `@testable import wthrr` follows the plain imports with no blank line.
- `// MARK: - Section` on top-level sections, `// MARK: Sub` inside types.
- Renderers are caseless `enum` namespaces with `static func draw(context:size:…)`.
- Implicit `@MainActor` from default isolation; explicit `@MainActor` appears on a
  few types and is not required.
- Builds and tests go through Xcode (MCP `BuildProject` / `RunAllTests`); there is
  no command-line build script.

## Project rules

- Renderers run every frame (60–120 fps) inside a SwiftUI `Canvas`: avoid per-frame
  heap allocation in per-particle loops and cache anything derived only from immutable
  model state.
- When a user-visible feature changes, `WhatsNewView` and `README.md` are updated
  in the same change (owner preference).

## Changes

- 2026-10-16 — Created from the observed codebase during the Retro 8-bit review.
