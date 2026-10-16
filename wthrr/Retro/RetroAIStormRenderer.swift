// RetroAIStormRenderer.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import SwiftUI

// MARK: - Retro AI storm renderer

/// 8-bit AI Storm: glitch fragments become pixel glyphs, alien ships become
/// two-frame space invaders, and corruption patches become flickering cell noise.
/// Colours come from the user's chosen AI Storm palette so the theme picker still
/// applies in retro mode.
enum RetroAIStormRenderer {

    /// Renders one retro AI Storm frame: screen flashes, then fractures, scan lines,
    /// corruption, glitch glyphs, invaders and finally data bolts on top.
    ///
    /// - Parameters:
    ///   - opacity: User particle opacity × night dimming; applied to glitch glyphs only,
    ///     matching the smooth renderer, which leaves the event effects at full strength.
    ///   - time: Wall-clock seconds, used only to pick sprite and noise frames.
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        px: CGFloat,
        particles: [Particle],
        scanLines: [ScanLine],
        dataBolts: [DataBolt],
        corruptionPatches: [CorruptionPatch],
        alienShips: [AlienShip],
        screenFractures: [ScreenFracture],
        opacity: Double,
        time: Double
    ) {
        for bolt in dataBolts {
            PixelPainter.flash(context: context, size: size,
                               color: NeonPalette.indexed(bolt.colorIndex).opacity(0.5),
                               opacity: bolt.flashOpacity)
        }
        for fracture in screenFractures {
            PixelPainter.flash(context: context, size: size, color: RetroPalette.white,
                               opacity: fracture.flashOpacity)
        }

        let neon = (0..<4).map { NeonPalette.indexed($0) }
        var painter = PixelPainter(px: px)

        // Fractures: Bresenham cracks that fade in stepped notches.
        for fracture in screenFractures {
            let progress = fracture.age / fracture.lifetime
            let alpha = PixelPainter.stepped(Double(max(0, 1 - progress * 0.8)), levels: 3)
            guard alpha > 0.05 else { continue }
            let ink = painter.ink(neon[fracture.colorIndex % 4], opacity: alpha)
            for arm in fracture.arms {
                guard let first = arm.first else { continue }
                painter.line(ink, from: fracture.origin, to: first)
                painter.polyline(ink, arm)
            }
            if fracture.flashOpacity > 0.05 {
                let impact = painter.ink(RetroPalette.white, opacity: fracture.flashOpacity)
                painter.disc(impact, cx: fracture.origin.x, cy: fracture.origin.y, radius: 18)
            }
        }

        // Scan lines: whole-row bands with a white leading edge.
        for line in scanLines {
            let band = painter.ink(neon[line.colorIndex % 4], opacity: line.opacity)
            let edge = painter.ink(RetroPalette.white, opacity: line.opacity * 0.6)
            let gy = painter.grid(line.y)
            let cols = Int((size.width / px).rounded(.up))
            let rows = max(1, Int((line.width / px).rounded()))
            painter.cells(edge, gx: 0, gy: gy, w: cols)
            if rows > 1 { painter.cells(band, gx: 0, gy: gy + 1, w: cols, h: rows - 1) }
        }

        // Corruption: random cells re-rolled ~15 times a second, so the static crawls.
        let frame = Int(time * 15)
        for (n, patch) in corruptionPatches.enumerated() {
            let alpha = PixelPainter.stepped(Double(1 - patch.age / patch.lifetime) * 0.6, levels: 3)
            guard alpha > 0.05 else { continue }
            let inks = [painter.ink(neon[patch.colorIndex % 4], opacity: alpha),
                        painter.ink(neon[(patch.colorIndex + 1) % 4], opacity: alpha),
                        painter.ink(RetroPalette.white, opacity: alpha)]
            let gx0 = painter.grid(patch.x), gy0 = painter.grid(patch.y)
            let w = max(1, Int(patch.width / px)), h = max(1, Int(patch.height / px))
            for gy in 0..<h {
                for gx in 0..<w {
                    let roll = PixelPainter.hash01(gx + n * 997, gy, frame)
                    guard roll < 0.55 else { continue }
                    painter.cells(inks[roll < 0.3 ? 0 : (roll < 0.5 ? 1 : 2)], gx: gx0 + gx, gy: gy0 + gy)
                }
            }
        }

        // Glitch fragments, bucketed by palette colour.
        let glyphs = neon.map { painter.ink($0, opacity: min(1, 0.85 * opacity)) }
        let glyphInks = glyphs.map { [$0] }   // sprite ink lists, built once per frame
        for p in particles {
            let slot = min(3, Int(p.tint * 4))
            let ink = glyphs[slot]
            switch p.shape {
            case .dot:
                painter.dot(ink, x: p.x, y: p.y)
            case .star:
                // Spin is quantised to a left/right flip — no rotated sprites on a NES.
                painter.sprite(RetroSprites.bracket, x: p.x, y: p.y, inks: glyphInks[slot],
                               flipX: sin(p.rotation) < 0)
            case .dendrite:
                painter.sprite(RetroSprites.slash, x: p.x, y: p.y, inks: glyphInks[slot],
                               flipX: cos(p.rotation) < 0)
            }
        }

        // Invaders with dotted exhaust trails. Frames toggle twice a second.
        let step = Int(time * 2).isMultiple(of: 2)
        let invaderWidth = CGFloat(RetroSprites.invaderA1.width) * px
        for ship in alienShips {
            let color = neon[ship.colorIndex % 4]
            let trail = painter.ink(color, opacity: 0.4)
            for (idx, pos) in ship.trail.enumerated() where idx % 3 == 0 && idx < ship.trail.count / 2 {
                painter.dot(trail, x: pos.0, y: pos.1)
            }
            let body = painter.ink(color, opacity: 1)
            let scale = max(1, Int((ship.size * 2.6 / invaderWidth).rounded()))
            let sprite: PixelSprite
            if ship.colorIndex.isMultiple(of: 2) {
                sprite = step ? RetroSprites.invaderA1 : RetroSprites.invaderA2
            } else {
                sprite = step ? RetroSprites.invaderB1 : RetroSprites.invaderB2
            }
            painter.sprite(sprite, x: ship.x, y: ship.y, inks: [body], scale: scale)
        }

        // Data bolts last: right-angle circuit traces, neon glow under a white core.
        for bolt in dataBolts where bolt.segments.count >= 2 {
            let progress = bolt.age / bolt.lifetime
            let alpha: Double
            if progress < 0.15 { alpha = 1 }
            else if progress > 0.4 && progress < 0.5 { alpha = 0.6 }
            else { alpha = Double(max(0, 1 - progress * 1.4)) }
            guard alpha > 0.05 else { continue }
            let a = PixelPainter.stepped(alpha, levels: 3)
            let glow = painter.ink(neon[bolt.colorIndex % 4], opacity: a * 0.7)
            let core = painter.ink(RetroPalette.white, opacity: a)
            painter.polyline(glow, bolt.segments, thickness: 3)
            painter.polyline(core, bolt.segments)
        }

        painter.flush(into: context)
    }
}
