// PixelPainterTests.swift
// wthrr — macOS decorative weather overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac
// License: MIT — see LICENSE for details

import Testing
import SwiftUI
@testable import wthrr

// MARK: - Pixel painter

/// Retro mode's look depends on everything landing on the grid. These tests pin
/// down the snapping, sprite parsing and quantisation that guarantee it.
@Suite("PixelPainter")
struct PixelPainterTests {

    @Test("Points snap down to their grid cell, including negatives")
    func gridSnapping() {
        let painter = PixelPainter(px: 4)
        #expect(painter.grid(0) == 0)
        #expect(painter.grid(3.99) == 0)
        #expect(painter.grid(4) == 1)
        #expect(painter.grid(-0.5) == -1)
    }

    @Test("Pixel size is clamped to at least one point")
    func pixelSizeFloor() {
        #expect(PixelPainter(px: 0).px == 1)
    }

    @Test("Cells fill exactly whole grid squares")
    func cellsAreGridAligned() {
        var painter = PixelPainter(px: 4)
        let ink = painter.ink(.white)
        painter.dot(ink, x: 9, y: 2)
        #expect(painter.inks[ink].path.boundingRect == CGRect(x: 8, y: 0, width: 4, height: 4))
    }

    @Test("Inks fill in registration order")
    func inkOrder() {
        var painter = PixelPainter(px: 4)
        let a = painter.ink(.red)
        let b = painter.ink(.blue)
        #expect(a == 0 && b == 1)
    }

    @Test("Bresenham lines cover both endpoints and stay contiguous")
    func lineEndpoints() {
        var painter = PixelPainter(px: 1)
        let ink = painter.ink(.white)
        painter.line(ink, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 5, y: 3))
        #expect(painter.inks[ink].path.boundingRect == CGRect(x: 0, y: 0, width: 6, height: 4))
    }

    @Test("Stepped quantisation rounds to the nearest notch and clamps")
    func stepped() {
        #expect(PixelPainter.stepped(0.1, levels: 4) == 0)
        #expect(PixelPainter.stepped(0.2, levels: 4) == 0.25)
        #expect(PixelPainter.stepped(0.3, levels: 4) == 0.25)
        #expect(PixelPainter.stepped(0.4, levels: 4) == 0.5)
        #expect(PixelPainter.stepped(2, levels: 4) == 1)
        #expect(PixelPainter.stepped(-1, levels: 4) == 0)
    }

    @Test("Steep, reversed and zero-length lines cover their endpoints")
    func lineOctants() {
        for (a, b) in [((0, 0), (2, 7)), ((6, 5), (0, 0)), ((3, 3), (3, 3)), ((5, 0), (0, 4))] {
            var painter = PixelPainter(px: 1)
            let ink = painter.ink(.white)
            painter.line(ink, from: CGPoint(x: a.0, y: a.1), to: CGPoint(x: b.0, y: b.1))
            let expected = CGRect(x: min(a.0, b.0), y: min(a.1, b.1),
                                  width: abs(a.0 - b.0) + 1, height: abs(a.1 - b.1) + 1)
            #expect(painter.inks[ink].path.boundingRect == expected)
        }
    }

    @Test("Straight lines merge into a single rectangle")
    func straightLinesMerge() {
        var painter = PixelPainter(px: 2)
        let ink = painter.ink(.white)
        painter.line(ink, from: CGPoint(x: 4, y: 0), to: CGPoint(x: 4, y: 20))
        var elements = 0
        painter.inks[ink].path.forEach { if case .move = $0 { elements += 1 } }
        #expect(elements == 1)
        #expect(painter.inks[ink].path.boundingRect == CGRect(x: 4, y: 0, width: 2, height: 22))
    }

    @Test("Thick lines grow symmetrically around the centre cell")
    func lineThickness() {
        var painter = PixelPainter(px: 1)
        let ink = painter.ink(.white)
        painter.line(ink, from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5), thickness: 3)
        #expect(painter.inks[ink].path.boundingRect == CGRect(x: 4, y: 4, width: 3, height: 3))
    }

    @Test("Non-finite coordinates are clamped instead of trapping")
    func nonFiniteCoordinates() {
        let painter = PixelPainter(px: 4)
        #expect(painter.grid(.nan) == 0)
        #expect(painter.grid(.infinity) == 0)
        #expect(painter.grid(1e300) == 100_000)
    }

    @Test("Discs are symmetric about their centre")
    func discSymmetry() {
        var painter = PixelPainter(px: 1)
        let ink = painter.ink(.white)
        painter.disc(ink, cx: 10, cy: 10, radius: 4)
        #expect(painter.inks[ink].path.boundingRect == CGRect(x: 6, y: 6, width: 9, height: 9))
    }

    @Test("hash01 is deterministic and in range")
    func hashRange() {
        for i in 0..<200 {
            let v = PixelPainter.hash01(i, i * 7, -i)
            #expect(v >= 0 && v <= 1)
            #expect(v == PixelPainter.hash01(i, i * 7, -i))
        }
    }
}

// MARK: - Pixel sprite

@Suite("PixelSprite")
struct PixelSpriteTests {

    @Test("Digits become inked cells; dots and spaces are transparent")
    func parsing() {
        let sprite = PixelSprite([
            "1.2",
            " 3.",
        ])
        #expect(sprite.width == 3)
        #expect(sprite.height == 2)
        #expect(sprite.cells.count == 3)
        #expect(sprite.cells.contains { $0.dx == 2 && $0.dy == 0 && $0.ink == 2 })
        #expect(sprite.cells.contains { $0.dx == 1 && $0.dy == 1 && $0.ink == 3 })
    }

    @Test("Sprites centre on the point and flip in place")
    func spritePlacement() {
        let sprite = PixelSprite(["1..", "..."])
        var painter = PixelPainter(px: 1)
        let a = painter.ink(.white), b = painter.ink(.white)
        painter.sprite(sprite, x: 10, y: 10, inks: [a])
        painter.sprite(sprite, x: 10, y: 10, inks: [b], flipX: true)
        // 3×2 sprite centred on (10, 10) → origin (9, 9).
        #expect(painter.inks[a].path.boundingRect == CGRect(x: 9, y: 9, width: 1, height: 1))
        #expect(painter.inks[b].path.boundingRect == CGRect(x: 11, y: 9, width: 1, height: 1))
    }

    @Test("Scaled sprites expand each cell to a block")
    func spriteScale() {
        var painter = PixelPainter(px: 1)
        let ink = painter.ink(.white)
        painter.sprite(PixelSprite(["1"]), x: 10, y: 10, inks: [ink], scale: 3)
        #expect(painter.inks[ink].path.boundingRect.size == CGSize(width: 3, height: 3))
    }

    @Test("Invader animation frames share a size so they don't jitter")
    func invaderFramesMatch() {
        #expect(RetroSprites.invaderA1.width == RetroSprites.invaderA2.width)
        #expect(RetroSprites.invaderA1.height == RetroSprites.invaderA2.height)
        #expect(RetroSprites.invaderB1.width == RetroSprites.invaderB2.width)
        #expect(RetroSprites.birdUp.width == RetroSprites.birdDown.width)
    }

    @Test("Every offered pixel size has a label and the default is offered")
    func pixelSizeOptions() {
        #expect(RetroPalette.pixelSizeOptions.contains(4))
        for size in RetroPalette.pixelSizeOptions {
            #expect(!RetroPalette.pixelSizeLabel(size).isEmpty)
        }
    }
}
