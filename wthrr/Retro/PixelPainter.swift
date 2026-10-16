// PixelPainter.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Pixel painter

/// Accumulates grid-aligned cells into one `Path` per ink so an entire pixel-art
/// layer costs a single `fill` call instead of one per pixel.
///
/// Every coordinate handed to the painter is snapped to a square grid of `px`
/// points. That snapping — not any filter or upscale — is what produces the 8-bit
/// look: there are no curves, no anti-aliased edges and no sub-cell positions.
struct PixelPainter {

    /// One colour + opacity pair and the cells painted with it so far.
    struct Ink {
        let color: Color
        let opacity: Double
        var path = Path()
    }

    /// Edge length of one grid cell, in points.
    let px: CGFloat

    /// Inks in the order they were registered, which is also the order they fill.
    private(set) var inks: [Ink] = []

    init(px: CGFloat) {
        self.px = max(1, px)
    }

    // MARK: Inks

    /// Registers a new ink and returns its handle. Inks fill in registration order,
    /// so register background colours first.
    mutating func ink(_ color: Color, opacity: Double = 1) -> Int {
        inks.append(Ink(color: color, opacity: opacity))
        return inks.count - 1
    }

    // MARK: Grid helpers

    /// Converts a point coordinate to its grid cell index.
    ///
    /// Non-finite or absurdly distant values are clamped rather than trapping in the
    /// `Int` conversion: a bad coordinate should draw off-screen, not crash every frame.
    func grid(_ v: CGFloat) -> Int {
        let cell = (v / px).rounded(.down)
        guard cell.isFinite else { return 0 }
        return Int(max(-100_000, min(100_000, cell)))
    }

    // MARK: Painting

    /// Fills a `w × h` block of cells whose top-left cell is (`gx`, `gy`).
    mutating func cells(_ ink: Int, gx: Int, gy: Int, w: Int = 1, h: Int = 1) {
        guard w > 0, h > 0 else { return }
        inks[ink].path.addRect(CGRect(
            x: CGFloat(gx) * px, y: CGFloat(gy) * px,
            width: CGFloat(w) * px, height: CGFloat(h) * px
        ))
    }

    /// Fills the cell containing the point (`x`, `y`), optionally widened to a block.
    mutating func dot(_ ink: Int, x: CGFloat, y: CGFloat, w: Int = 1, h: Int = 1) {
        cells(ink, gx: grid(x), gy: grid(y), w: w, h: h)
    }

    /// Fills a rectangle given in points, snapped outward to whole cells.
    mutating func rect(_ ink: Int, _ r: CGRect) {
        let gx0 = grid(r.minX), gy0 = grid(r.minY)
        let gx1 = Int((r.maxX / px).rounded(.up))
        let gy1 = Int((r.maxY / px).rounded(.up))
        cells(ink, gx: gx0, gy: gy0, w: gx1 - gx0, h: gy1 - gy0)
    }

    /// Stamps a sprite centred on the point (`x`, `y`).
    ///
    /// - Parameters:
    ///   - inks: Maps the sprite's ink digits to painter inks; digit `1` → `inks[0]`.
    ///     Digits beyond the array are skipped.
    ///   - scale: Each sprite cell becomes a `scale × scale` block of grid cells.
    ///   - flipX: Mirrors the sprite horizontally.
    mutating func sprite(
        _ sprite: PixelSprite,
        x: CGFloat, y: CGFloat,
        inks: [Int],
        scale: Int = 1,
        flipX: Bool = false
    ) {
        let s = max(1, scale)
        let ox = grid(x) - (sprite.width * s) / 2
        let oy = grid(y) - (sprite.height * s) / 2
        for c in sprite.cells where c.ink <= inks.count {
            let dx = flipX ? sprite.width - 1 - c.dx : c.dx
            cells(inks[c.ink - 1], gx: ox + dx * s, gy: oy + c.dy * s, w: s, h: s)
        }
    }

    /// Rasterises a straight line onto the grid with Bresenham's algorithm.
    ///
    /// Consecutive cells along a row (or, for steep lines, a column) are merged into
    /// one rectangle, so a vertical rain streak is a single path element rather than
    /// one per cell.
    mutating func line(_ ink: Int, from a: CGPoint, to b: CGPoint, thickness: Int = 1) {
        var x0 = grid(a.x), y0 = grid(a.y)
        let x1 = grid(b.x), y1 = grid(b.y)
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        let t = max(1, thickness)
        let off = t / 2

        // Current run, in cells: top-left (rx, ry), size rw × rh. Only one of rw/rh
        // ever exceeds 1.
        var rx = x0, ry = y0, rw = 1, rh = 1
        func emit() { cells(ink, gx: rx - off, gy: ry - off, w: rw + t - 1, h: rh + t - 1) }

        // Belt-and-braces cap: Bresenham always reaches (x1, y1) within
        // max(dx, -dy) + 1 steps, so this never truncates a valid line.
        var budget = dx - dy + 1
        while budget > 0, !(x0 == x1 && y0 == y1) {
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
            budget -= 1

            if rh == 1, y0 == ry, x0 == rx + rw {
                rw += 1
            } else if rh == 1, y0 == ry, x0 == rx - 1 {
                rx -= 1; rw += 1
            } else if rw == 1, x0 == rx, y0 == ry + rh {
                rh += 1
            } else if rw == 1, x0 == rx, y0 == ry - 1 {
                ry -= 1; rh += 1
            } else {
                emit()
                rx = x0; ry = y0; rw = 1; rh = 1
            }
        }
        emit()
    }

    /// Rasterises a polyline (consecutive points joined by `line`).
    mutating func polyline(_ ink: Int, _ points: [CGPoint], thickness: Int = 1) {
        guard points.count >= 2 else { return }
        for i in 1..<points.count {
            line(ink, from: points[i - 1], to: points[i], thickness: thickness)
        }
    }

    /// Fills a disc of the given radius (in points) as horizontal cell runs.
    mutating func disc(_ ink: Int, cx: CGFloat, cy: CGFloat, radius: CGFloat) {
        let gcx = grid(cx), gcy = grid(cy)
        let r = max(1, Int((radius / px).rounded()))
        for dy in -r...r {
            let half = Int((Double(r * r - dy * dy)).squareRoot().rounded())
            cells(ink, gx: gcx - half, gy: gcy + dy, w: half * 2 + 1)
        }
    }

    // MARK: Output

    /// Fills every ink into the context, in registration order.
    func flush(into context: GraphicsContext) {
        for ink in inks where !ink.path.isEmpty && ink.opacity > 0.004 {
            var ctx = context
            ctx.opacity = ink.opacity
            ctx.fill(ink.path, with: .color(ink.color))
        }
    }

    // MARK: Retro quantisation

    /// A stepped full-screen flash — three brightness notches rather than a smooth fade.
    static func flash(context: GraphicsContext, size: CGSize, color: Color, opacity: Double) {
        guard opacity > 0.01 else { return }
        var ctx = context
        ctx.opacity = stepped(opacity, levels: 3) * 0.8
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color))
    }

    /// Snaps a 0–1 value to the nearest of `levels` steps. Old hardware had no smooth
    /// fades — brightness moved in visible notches, and so should ours. Rounding to
    /// nearest (not up) keeps faint values faint and lets fades actually reach zero.
    static func stepped(_ v: Double, levels: Int = 4) -> Double {
        let l = Double(max(1, levels))
        return (max(0, min(1, v)) * l).rounded() / l
    }

    /// Cheap deterministic hash → 0–1, for per-cell flicker and dither noise.
    static func hash01(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> Double {
        var h = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663 ^ c &* 83_492_791))
        h ^= h >> 33; h &*= 0xff51_afd7_ed55_8ccd; h ^= h >> 33
        return Double(h & 0xFFFF) / 65535.0
    }
}

// MARK: - Pixel sprite

/// A small bitmap described as rows of characters, parsed once at load time.
///
/// `.` or space is transparent; the digits `1`–`9` select an ink slot, so a single
/// sprite can carry an outline, a body and a highlight in different colours.
struct PixelSprite: Sendable {
    struct Cell: Sendable {
        let dx: Int
        let dy: Int
        let ink: Int
    }

    let width: Int
    let height: Int
    let cells: [Cell]

    init(_ rows: [String]) {
        var cells: [Cell] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if let d = ch.wholeNumberValue, d > 0 {
                    cells.append(Cell(dx: x, dy: y, ink: d))
                }
            }
        }
        self.cells = cells
        self.width = rows.map(\.count).max() ?? 0
        self.height = rows.count
    }
}
