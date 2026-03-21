#!/usr/bin/env python3
"""
Generate the wthrr DMG background PNG using only Python stdlib.
Output: scripts/dmg-background.png  (1400x840 — 2x retina for 700x420 window)

Color aesthetic matches the app:
  - Near-black base (#080810)
  - Aurora gradient wash at top (cyan → purple)
  - Subtle radial glow in center
  - wthrr wordmark + drag instruction text rendered as simple pixel art
    (skipped here — let create-dmg handle text positioning)
"""

import struct
import zlib
import math
import sys
import os

W, H = 1400, 840   # 2× retina (display window = 700×420)


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


def make_pixels():
    """Return flat list of (r,g,b) tuples, top-left to bottom-right."""
    pixels = []

    # Aurora band colors — sampled from AuroraRenderer palette in the app
    aurora_stops = [
        (0.00, (0,   220, 255)),   # cyan
        (0.25, (120,  60, 255)),   # violet
        (0.50, (0,   200, 100)),   # green
        (0.75, (180,  20, 220)),   # magenta-purple
        (1.00, (0,   180, 255)),   # cyan again
    ]

    for y in range(H):
        fy = y / H

        # Base dark gradient: top slightly lighter navy → deep black at bottom
        base_r = clamp(lerp(14, 4, fy))
        base_g = clamp(lerp(14, 4, fy))
        base_b = clamp(lerp(28, 8, fy))

        # Aurora wash — strongest in top 40%, fades by 70%
        aurora_alpha = max(0.0, 1.0 - fy / 0.45) ** 1.8

        for x in range(W):
            fx = x / W

            # Aurora: sample a smooth color along x using stops
            # Add slight vertical wave
            wave = math.sin(fx * math.pi * 3 + fy * math.pi * 2) * 0.04
            sx = (fx + wave) % 1.0

            # Find surrounding stops
            col = aurora_stops[0][1]
            for i in range(len(aurora_stops) - 1):
                t0, c0 = aurora_stops[i]
                t1, c1 = aurora_stops[i + 1]
                if t0 <= sx <= t1:
                    tt = (sx - t0) / (t1 - t0)
                    # smooth step
                    tt = tt * tt * (3 - 2 * tt)
                    col = tuple(int(lerp(c0[j], c1[j], tt)) for j in range(3))
                    break

            # Aurora brightness pulse along y (bands)
            band = (math.sin(fy * math.pi * 5 + fx * 0.5) * 0.5 + 0.5) * 0.6 + 0.4
            aa = aurora_alpha * band * 0.28   # keep it subtle

            # Radial glow from center-ish (slightly left, mid-height)
            cx, cy = 0.38, 0.42
            dist = math.sqrt((fx - cx) ** 2 + (fy - cy) ** 2)
            glow = max(0.0, 1.0 - dist / 0.55) ** 3 * 0.08
            glow_r = clamp(glow * 80)
            glow_g = clamp(glow * 140)
            glow_b = clamp(glow * 200)

            r = clamp(base_r + col[0] * aa + glow_r)
            g = clamp(base_g + col[1] * aa + glow_g)
            b = clamp(base_b + col[2] * aa + glow_b)

            pixels.append((r, g, b))

    return pixels


def write_png(path, width, height, pixels):
    def chunk(tag, data):
        payload = tag + data
        return (struct.pack('>I', len(data))
                + payload
                + struct.pack('>I', zlib.crc32(payload) & 0xFFFFFFFF))

    rows = []
    for y in range(height):
        row_pixels = pixels[y * width:(y + 1) * width]
        row = b'\x00' + bytes(v for px in row_pixels for v in px)
        rows.append(row)

    compressed = zlib.compress(b''.join(rows), 6)

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    png = (sig
           + chunk(b'IHDR', ihdr_data)
           + chunk(b'IDAT', compressed)
           + chunk(b'IEND', b''))

    with open(path, 'wb') as f:
        f.write(png)
    print(f"  Written: {path}  ({width}x{height}, {os.path.getsize(path)//1024} KB)")


if __name__ == '__main__':
    out = os.path.join(os.path.dirname(__file__), 'dmg-background.png')
    print(f"Generating DMG background ({W}x{H})...")
    pixels = make_pixels()
    write_png(out, W, H, pixels)
    print("Done.")
