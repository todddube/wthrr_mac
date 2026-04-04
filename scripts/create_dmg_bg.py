#!/usr/bin/env python3
"""
Generate the wthrr DMG background PNG using only Python stdlib.
Output: scripts/dmg-background.png  (1400x840 — 2x retina for 700x420 window)

Visual composition:
  - Near-black base with aurora gradient wash at top (cyan → violet → green)
  - LEFT ZONE  (x 0–560):   drifting snowflakes
  - RIGHT ZONE (x 840–1400): angled rain streaks
  - CENTER-RIGHT:            lightning bolt with glow
  - BOTTOM:                  fog wisps fading up
  - Scattered sparkle stars throughout
  - Soft radial glows beneath each drop-zone icon position
"""

import struct
import zlib
import math
import os

W, H = 1400, 840   # 2× retina  (display window = 700×420)

# Drop-zone centres in 2× pixel space
# wthrr.app  → DMG window coords (185, 210) → 2× → (370, 420)
# Applications → (515, 210) → 2× → (1030, 420)
APP_CX,  APP_CY  = 370,  420
APPS_CX, APPS_CY = 1030, 420

# ── Math helpers ──────────────────────────────────────────────────────────────

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v + 0.5)))

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

# ── Tiny LCG RNG (no random import needed, deterministic output) ───────────────

_seed = 0xDEADBEEF

def rng():
    global _seed
    _seed = (_seed * 1664525 + 1013904223) & 0xFFFF_FFFF
    return _seed / 0xFFFF_FFFF

# ── Pixel buffer helpers ───────────────────────────────────────────────────────

def blend(buf, x, y, r, g, b, a):
    """Alpha-composite (r,g,b,a) over existing pixel."""
    if 0 <= x < W and 0 <= y < H:
        i = y * W + x
        er, eg, eb = buf[i]
        buf[i] = (clamp(er + r * a), clamp(eg + g * a), clamp(eb + b * a))

def draw_line(buf, x0, y0, x1, y1, r, g, b, a):
    """Draw a single-pixel Bresenham line with alpha blend."""
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    dx = abs(x1 - x0); dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    x, y = x0, y0
    while True:
        blend(buf, x, y, r, g, b, a)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x += sx
        if e2 < dx:
            err += dx
            y += sy

# ── Phase 1 — Aurora base background ─────────────────────────────────────────

def phase_aurora(buf):
    aurora_stops = [
        (0.00, (0,   220, 255)),   # cyan
        (0.25, (120,  60, 255)),   # violet
        (0.50, (0,   200, 100)),   # green
        (0.75, (180,  20, 220)),   # magenta-purple
        (1.00, (0,   180, 255)),   # cyan again
    ]

    for y in range(H):
        fy = y / H
        base_r = lerp(16, 4, fy)
        base_g = lerp(16, 4, fy)
        base_b = lerp(34, 8, fy)
        aurora_a = max(0.0, 1.0 - fy / 0.45) ** 1.8

        for x in range(W):
            fx = x / W
            wave = math.sin(fx * math.pi * 3 + fy * math.pi * 2) * 0.04
            sx = (fx + wave) % 1.0

            col = aurora_stops[0][1]
            for i in range(len(aurora_stops) - 1):
                t0, c0 = aurora_stops[i]
                t1, c1 = aurora_stops[i + 1]
                if t0 <= sx <= t1:
                    tt = smoothstep((sx - t0) / (t1 - t0))
                    col = tuple(lerp(c0[j], c1[j], tt) for j in range(3))
                    break

            band = (math.sin(fy * math.pi * 5 + fx * 0.5) * 0.5 + 0.5) * 0.6 + 0.4
            aa = aurora_a * band * 0.30

            # Soft radial glow beneath each drop-zone icon
            d_app  = math.sqrt((x - APP_CX)  ** 2 + (y - APP_CY)  ** 2)
            d_apps = math.sqrt((x - APPS_CX) ** 2 + (y - APPS_CY) ** 2)
            ga  = max(0.0, 1.0 - d_app  / 280.0) ** 2.5 * 0.18
            gaa = max(0.0, 1.0 - d_apps / 280.0) ** 2.5 * 0.14

            r = base_r + col[0] * aa + ga * 25  + gaa * 50
            g = base_g + col[1] * aa + ga * 80  + gaa * 80
            b = base_b + col[2] * aa + ga * 200 + gaa * 160

            buf[y * W + x] = (clamp(r), clamp(g), clamp(b))

# ── Phase 2 — Rain streaks (right zone x 820–1400, y 100–780) ─────────────────

def phase_rain(buf):
    for _ in range(110):
        rx = rng() * 580 + 820
        ry = rng() * 680 + 100
        length = rng() * 55 + 25
        # Steep diagonal: angle ~ -70° ± 8°  (down-left, like wind-driven rain)
        ang = math.radians(-70 + rng() * 16)
        ex = rx + math.cos(ang) * length
        ey = ry - math.sin(ang) * length
        a = rng() * 0.28 + 0.08
        # Thin blue-white streak
        draw_line(buf, rx, ry, ex, ey, 140, 200, 255, a)
        # Faint glow alongside the streak
        draw_line(buf, rx - 1, ry, ex - 1, ey, 80, 140, 220, a * 0.35)
        draw_line(buf, rx + 1, ry, ex + 1, ey, 80, 140, 220, a * 0.35)

# ── Phase 3 — Snowflakes (left zone x 0–560, y 140–780) ──────────────────────

def _snowflake(buf, cx, cy, size, a):
    """Six-arm snowflake with small tick marks on each arm."""
    for arm_deg in range(0, 360, 60):
        ang = math.radians(arm_deg)
        ex = cx + math.cos(ang) * size
        ey = cy + math.sin(ang) * size
        draw_line(buf, cx, cy, ex, ey, 200, 230, 255, a)

        # Tick marks at 60% of arm length
        tick_x = cx + math.cos(ang) * size * 0.6
        tick_y = cy + math.sin(ang) * size * 0.6
        perp = math.radians(arm_deg + 90)
        tick = size * 0.28
        t0x = tick_x - math.cos(perp) * tick
        t0y = tick_y - math.sin(perp) * tick
        t1x = tick_x + math.cos(perp) * tick
        t1y = tick_y + math.sin(perp) * tick
        draw_line(buf, t0x, t0y, t1x, t1y, 200, 230, 255, a * 0.7)

def phase_snow(buf):
    for _ in range(22):
        sx = rng() * 560
        sy = rng() * 640 + 140
        size = rng() * 18 + 8
        a = rng() * 0.38 + 0.15
        _snowflake(buf, sx, sy, size, a)

# ── Phase 4 — Lightning bolt (center-right, clear of both icon zones) ─────────

def phase_lightning(buf):
    # Bolt origin near (1160, 180), ends around (1080, 420)
    bolt = [
        (1160, 180),
        (1125, 270),
        (1148, 270),   # inner step — classic zigzag
        (1095, 390),
        (1115, 390),   # second step
        (1080, 460),
    ]

    # Outer glow passes (wide, faint yellow)
    for gw in [7, 5, 3]:
        ga = 0.025 * (8 - gw)
        for i in range(len(bolt) - 1):
            x0, y0 = bolt[i]
            x1, y1 = bolt[i + 1]
            for ox in range(-gw, gw + 1):
                for oy in range(-gw, gw + 1):
                    if ox * ox + oy * oy <= gw * gw:
                        draw_line(buf, x0 + ox, y0 + oy, x1 + ox, y1 + oy,
                                  255, 200, 30, ga)

    # Core — bright white-yellow
    for i in range(len(bolt) - 1):
        x0, y0 = bolt[i]
        x1, y1 = bolt[i + 1]
        draw_line(buf, x0, y0, x1, y1, 255, 255, 180, 0.95)
        draw_line(buf, x0 + 1, y0, x1 + 1, y1, 255, 240, 120, 0.50)

# ── Phase 5 — Fog wisps (bottom 22%) ──────────────────────────────────────────

def phase_fog(buf):
    fog_start = int(H * 0.78)
    for y in range(fog_start, H):
        fy = (y - fog_start) / (H - fog_start)
        base_fog = smoothstep(fy) * 0.22
        for x in range(W):
            fx = x / W
            wisp = (math.sin(fx * math.pi * 5 + 1.3) * 0.5 + 0.5) * 0.55 + 0.45
            blend(buf, x, y, 155, 175, 210, base_fog * wisp)

# ── Phase 6 — Sparkle stars scattered in upper 72% ────────────────────────────

def phase_stars(buf):
    for _ in range(140):
        px = int(rng() * W)
        py = int(rng() * H * 0.72)
        pa = rng() * 0.55 + 0.08
        blend(buf, px, py, 230, 245, 255, pa)
        if pa > 0.40:
            # Cross-hair for brighter stars
            for d in (1, 2):
                fa = pa * (0.45 - d * 0.12)
                blend(buf, px + d, py,     230, 245, 255, fa)
                blend(buf, px - d, py,     230, 245, 255, fa)
                blend(buf, px,     py + d, 230, 245, 255, fa)
                blend(buf, px,     py - d, 230, 245, 255, fa)

# ── PNG writer (stdlib only) ──────────────────────────────────────────────────

def write_png(path, width, height, buf):
    def chunk(tag, data):
        payload = tag + data
        return (struct.pack('>I', len(data))
                + payload
                + struct.pack('>I', zlib.crc32(payload) & 0xFFFF_FFFF))

    rows = []
    for y in range(height):
        row_pixels = buf[y * width:(y + 1) * width]
        row = b'\x00' + bytes(v for px in row_pixels for v in px)
        rows.append(row)

    compressed = zlib.compress(b''.join(rows), 6)
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    png_data = (sig
                + chunk(b'IHDR', ihdr_data)
                + chunk(b'IDAT', compressed)
                + chunk(b'IEND', b''))

    with open(path, 'wb') as f:
        f.write(png_data)
    print(f"  Written: {path}  ({width}x{height}, {os.path.getsize(path) // 1024} KB)")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    out = os.path.join(os.path.dirname(__file__), 'dmg-background.png')
    print(f"Generating DMG background ({W}x{H})…")

    buf = [(0, 0, 0)] * (W * H)

    print("  Phase 1/6  aurora background…")
    phase_aurora(buf)
    print("  Phase 2/6  rain streaks…")
    phase_rain(buf)
    print("  Phase 3/6  snowflakes…")
    phase_snow(buf)
    print("  Phase 4/6  lightning bolt…")
    phase_lightning(buf)
    print("  Phase 5/6  fog wisps…")
    phase_fog(buf)
    print("  Phase 6/6  sparkle stars…")
    phase_stars(buf)

    write_png(out, W, H, buf)
    print("Done.")
