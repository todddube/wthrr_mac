# Contributing to wthrr

Thanks for your interest in contributing! wthrr is free, open-source software released under the [MIT License](LICENSE).

## Ways to Contribute

- **Bug reports** — open an issue with reproduction steps, macOS version, and display setup
- **Feature requests** — open an issue describing the use case and expected behavior
- **Code contributions** — bug fixes, new weather effects, performance improvements, or UI polish
- **Documentation** — README improvements, clearer setup instructions, architecture notes

## Getting Started

**Requirements:** macOS 26.4+, Xcode 26+

```bash
git clone https://github.com/todddube/wthrr_mac.git
cd wthrr_mac
open wthrr.xcodeproj
```

Select the **wthrr** scheme, choose **My Mac**, and hit **Cmd+R**.

## Submitting a Pull Request

1. Fork the repo and create a branch from `main`
2. Make your changes — keep commits focused and descriptive
3. Test on at least one display configuration (single and multi-monitor if relevant)
4. Open a PR against `main` with a clear description of what changed and why

There are no automated CI tests for UI behavior — describe what you tested manually.

## Code Style

- Swift 6, SwiftUI, AppKit — match the conventions already in the file you're editing
- File headers follow this format:

```swift
// FileName.swift
// wthrr — macOS decorative weather overlay
//
// Author: Your Name (or "Contributor")
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details
```

- Keep comments minimal — only add one when the *why* is non-obvious
- New weather effects belong in their own module folder (see `Snow/`, `Rain/`, `Aurora/` etc.)

## Architecture Reference

See [CLAUDE.md](CLAUDE.md) for a full architecture overview — module layout, data flow, and how the animation engine works. It's the best starting point before touching the rendering pipeline.

## Issues and Discussions

Open issues on GitHub:  
**[github.com/todddube/wthrr_mac/issues](https://github.com/todddube/wthrr_mac/issues)**

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

*wthrr is maintained by [Todd Dube](https://github.com/todddube).*
