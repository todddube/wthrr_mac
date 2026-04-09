#!/usr/bin/env python3
"""
Generate the wthrr DMG background PNG using only Python stdlib.
Output: scripts/dmg-background.png  (1720x1040 — 2x retina for 860x520 window)

Visual composition:
  - Near-black base with rich aurora gradient wash (top 55%)
  - "wthrr" brand title rendered as large pixel-art glyphs (top center)
  - LEFT ZONE  (x 0–680):   drifting snowflakes
  - RIGHT ZONE (x 1040–1720): angled rain streaks
  - CENTER:                  lightning bolt with glow
  - Neon arrow between the two drop-zone icon positions
  - Soft radial glows beneath each drop-zone icon position
  - BOTTOM:                  fog wisps fading up
  - Sparkle stars throughout upper area
"""

import struct
import zlib
import math
import os

W, H = 1720, 1040  # 2× retina  (display window = 860×520)

# Drop-zone centres in 2× pixel space
# wthrr.app    → DMG window coords (215, 260) → 2× → (430, 520)
# Applications → DMG window coords (645, 260) → 2× → (1290, 520)
APP_CX,  APP_CY  = 430,  520
APPS_CX, APPS_CY = 1290, 520

# ── Math helpers ──────────────────────────────────────────────────────────────

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v + 0.5)))

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

# ── Tiny LCG RNG (deterministic output) ───────────────────────────────────────

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
    """Bresenham line with alpha blend."""
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
        if e2 > -dy: err -= dy; x += sx
        if e2 < dx:  err += dx; y += sy

def radial_glow(buf, cx, cy, radius, r, g, b, peak_a):
    """Soft radial glow centered at (cx, cy)."""
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            d = math.sqrt(dx * dx + dy * dy)
            if d < radius:
                t = 1.0 - d / radius
                a = peak_a * smoothstep(t)
                blend(buf, cx + dx, cy + dy, r, g, b, a)

# ── Phase 1 — Rich aurora base ─────────────────────────────────────────────────

def phase_aurora(buf):
    aurora_stops = [
        (0.00, ( 0, 230, 255)),   # electric cyan
        (0.20, (100,  40, 255)),  # deep violet
        (0.40, ( 0, 210, 120)),   # vivid green
        (0.60, (200,  10, 230)),  # hot magenta
        (0.80, ( 20, 180, 255)),  # sky blue
        (1.00, ( 0, 230, 255)),   # back to cyan
    ]

    for y in range(H):
        fy = y / H
        base_r = lerp(10, 3, fy)
        base_g = lerp(10, 3, fy)
        base_b = lerp(22, 6, fy)
        # Aurora fades out below 55% of image height
        aurora_a = max(0.0, 1.0 - fy / 0.55) ** 1.6

        for x in range(W):
            fx = x / W
            wave = math.sin(fx * math.pi * 4 + fy * math.pi * 2.5) * 0.05
            sx = (fx + wave) % 1.0

            col = aurora_stops[0][1]
            for i in range(len(aurora_stops) - 1):
                t0, c0 = aurora_stops[i]
                t1, c1 = aurora_stops[i + 1]
                if t0 <= sx <= t1:
                    tt = smoothstep((sx - t0) / (t1 - t0))
                    col = tuple(lerp(c0[j], c1[j], tt) for j in range(3))
                    break

            band = (math.sin(fy * math.pi * 6 + fx * 0.8) * 0.5 + 0.5) * 0.5 + 0.5
            aa = aurora_a * band * 0.35

            # Radial glows beneath each icon drop zone
            d_app  = math.sqrt((x - APP_CX)  ** 2 + (y - APP_CY)  ** 2)
            d_apps = math.sqrt((x - APPS_CX) ** 2 + (y - APPS_CY) ** 2)
            ga  = max(0.0, 1.0 - d_app  / 320.0) ** 2.2 * 0.22
            gaa = max(0.0, 1.0 - d_apps / 320.0) ** 2.2 * 0.18

            r = base_r + col[0] * aa + ga * 30  + gaa * 60
            g = base_g + col[1] * aa + ga * 90  + gaa * 90
            b = base_b + col[2] * aa + ga * 210 + gaa * 180

            buf[y * W + x] = (clamp(r), clamp(g), clamp(b))

# ── Phase 2 — "wthrr" pixel-art title ─────────────────────────────────────────
#  Each glyph is defined on a 5-wide × 7-tall pixel grid.

GLYPHS = {
    'w': [
        (1,0,0,0,1),
        (1,0,0,0,1),
        (1,0,1,0,1),
        (1,0,1,0,1),
        (1,1,0,1,1),
        (1,0,0,0,1),
        (0,0,0,0,0),
    ],
    't': [
        (1,1,1,1,1),
        (0,0,1,0,0),
        (0,0,1,0,0),
        (0,0,1,0,0),
        (0,0,1,0,0),
        (0,0,1,0,0),
        (0,0,0,0,0),
    ],
    'h': [
        (1,0,0,1,0),
        (1,0,0,1,0),
        (1,1,1,1,0),
        (1,0,0,1,0),
        (1,0,0,1,0),
        (1,0,0,1,0),
        (0,0,0,0,0),
    ],
    'r': [
        (1,1,1,1,0),
        (1,0,0,0,1),
        (1,1,1,1,0),
        (1,1,0,0,0),
        (1,0,1,0,0),
        (1,0,0,1,1),
        (0,0,0,0,0),
    ],
}

def _draw_glyph(buf, glyph, ox, oy, scale, r, g, b):
    """Render a single glyph at (ox, oy) with pixel size `scale`."""
    for row_i, row in enumerate(glyph):
        for col_i, on in enumerate(row):
            if not on:
                continue
            px0 = ox + col_i * scale
            py0 = oy + row_i * scale
            for dy in range(scale):
                for dx in range(scale):
                    # Core pixel at full brightness
                    blend(buf, px0 + dx, py0 + dy, r, g, b, 0.92)
            # Soft halo around each lit pixel block
            halo = scale // 2
            for dy in range(-halo, scale + halo):
                for dx in range(-halo, scale + halo):
                    if 0 <= dx < scale and 0 <= dy < scale:
                        continue
                    d = max(abs(dx - scale//2), abs(dy - scale//2)) - scale//2
                    if d < halo:
                        blend(buf, px0 + dx, py0 + dy,
                              r, g, b, 0.20 * (1.0 - d / halo))

def phase_title(buf):
    """Render 'wthrr' as large pixel-art glyphs centered near the top."""
    word = "wthrr"
    scale    = 16     # pixels per glyph dot
    char_w   = 5 * scale
    char_gap = scale
    total_w  = len(word) * (char_w + char_gap) - char_gap
    ox = (W - total_w) // 2
    oy = 58

    # Subtle glow strip behind the text
    for i in range(7 * scale + 30):
        for j in range(total_w + 80):
            t = 1.0 - abs(i - (7 * scale) / 2) / (7 * scale / 2 + 15)
            blend(buf, ox - 40 + j, oy - 10 + i, 60, 200, 255, 0.045 * smoothstep(t))

    for ch in word:
        glyph = GLYPHS.get(ch)
        if glyph:
            _draw_glyph(buf, glyph, ox, oy, scale, 140, 230, 255)
        ox += char_w + char_gap

# ── Phase 3 — Neon arrow between drop zones ───────────────────────────────────

def phase_arrow(buf):
    """Glowing neon arrow pointing from the app icon toward Applications."""
    cx    = (APP_CX + APPS_CX) // 2      # horizontal midpoint
    ay    = APP_CY + 110                  # below the icons
    x0    = APP_CX  + 160                 # shaft start (clear of app glow)
    x1    = APPS_CX - 160                 # arrowhead tip

    shaft_half = 3                        # shaft half-thickness
    head_len   = 60                       # arrowhead length
    head_half  = 28                       # arrowhead half-width

    # Outer glow
    for px in range(x0, x1 + 1):
        for dy in range(-(shaft_half + 14), shaft_half + 15):
            d = abs(dy) - shaft_half
            if d > 0:
                blend(buf, px, ay + dy, 0, 220, 180, 0.06 * max(0, 1 - d / 14))

    # Shaft
    for px in range(x0, x1 - head_len + 1):
        for dy in range(-shaft_half, shaft_half + 1):
            a = 0.75 * (1.0 - abs(dy) / (shaft_half + 1))
            blend(buf, px, ay + dy, 0, 255, 200, a)

    # Arrowhead (filled triangle)
    for i in range(head_len):
        progress = i / head_len
        spread = int(head_half * (1.0 - progress))
        px = x1 - head_len + i
        for dy in range(-spread, spread + 1):
            a = 0.80 * (1.0 - abs(dy) / (spread + 1)) if spread > 0 else 0.80
            blend(buf, px, ay + dy, 0, 255, 200, a)

    # "drag to install" label dots — three tiny dots on each side as a hint
    for i in range(3):
        dot_x = x0 - 30 - i * 18
        radial_glow(buf, dot_x, ay, 6, 0, 200, 160, 0.35)
    for i in range(3):
        dot_x = x1 + 30 + i * 18
        radial_glow(buf, dot_x, ay, 6, 0, 200, 160, 0.20 * (1 - i * 0.25))

# ── Phase 4 — Rain streaks (right zone) ───────────────────────────────────────

def phase_rain(buf):
    for _ in range(130):
        rx = rng() * 680 + 1040
        ry = rng() * 760 + 80
        length = rng() * 65 + 30
        ang = math.radians(-70 + rng() * 16)
        ex = rx + math.cos(ang) * length
        ey = ry - math.sin(ang) * length
        a  = rng() * 0.30 + 0.08
        draw_line(buf, rx, ry, ex, ey, 140, 200, 255, a)
        draw_line(buf, rx - 1, ry, ex - 1, ey, 80, 140, 220, a * 0.35)
        draw_line(buf, rx + 1, ry, ex + 1, ey, 80, 140, 220, a * 0.35)

# ── Phase 5 — Snowflakes (left zone) ──────────────────────────────────────────

def _snowflake(buf, cx, cy, size, a):
    for arm_deg in range(0, 360, 60):
        ang = math.radians(arm_deg)
        ex = cx + math.cos(ang) * size
        ey = cy + math.sin(ang) * size
        draw_line(buf, cx, cy, ex, ey, 200, 230, 255, a)
        tick_x  = cx + math.cos(ang) * size * 0.6
        tick_y  = cy + math.sin(ang) * size * 0.6
        perp    = math.radians(arm_deg + 90)
        tick    = size * 0.28
        draw_line(buf, tick_x - math.cos(perp)*tick, tick_y - math.sin(perp)*tick,
                       tick_x + math.cos(perp)*tick, tick_y + math.sin(perp)*tick,
                       200, 230, 255, a * 0.7)

def phase_snow(buf):
    for _ in range(28):
        sx = rng() * 680
        sy = rng() * 760 + 80
        size = rng() * 22 + 10
        a    = rng() * 0.38 + 0.15
        _snowflake(buf, sx, sy, size, a)

# ── Phase 6 — Lightning bolt ───────────────────────────────────────────────────

def phase_lightning(buf):
    bolt = [
        (1050, 140),
        (1010, 250),
        (1035, 250),
        (990,  390),
        (1012, 390),
        (975,  480),
    ]
    for gw in (8, 6, 4):
        ga = 0.022 * (9 - gw)
        for i in range(len(bolt) - 1):
            x0, y0 = bolt[i]; x1, y1 = bolt[i + 1]
            for ox in range(-gw, gw + 1):
                for oy in range(-gw, gw + 1):
                    if ox*ox + oy*oy <= gw*gw:
                        draw_line(buf, x0+ox, y0+oy, x1+ox, y1+oy, 255, 200, 30, ga)
    for i in range(len(bolt) - 1):
        x0, y0 = bolt[i]; x1, y1 = bolt[i + 1]
        draw_line(buf, x0, y0, x1, y1, 255, 255, 180, 0.95)
        draw_line(buf, x0+1, y0, x1+1, y1, 255, 240, 120, 0.50)

# ── Phase 7 — Fog wisps (bottom 20%) ──────────────────────────────────────────

def phase_fog(buf):
    fog_start = int(H * 0.80)
    for y in range(fog_start, H):
        fy = (y - fog_start) / (H - fog_start)
        base_fog = smoothstep(fy) * 0.24
        for x in range(W):
            fx = x / W
            wisp = (math.sin(fx * math.pi * 6 + 1.3) * 0.5 + 0.5) * 0.55 + 0.45
            blend(buf, x, y, 155, 175, 210, base_fog * wisp)

# ── Phase 8 — Sparkle stars ────────────────────────────────────────────────────

def phase_stars(buf):
    for _ in range(180):
        px = int(rng() * W)
        py = int(rng() * H * 0.74)
        pa = rng() * 0.60 + 0.10
        blend(buf, px, py, 230, 245, 255, pa)
        if pa > 0.40:
            for d in (1, 2):
                fa = pa * (0.45 - d * 0.12)
                blend(buf, px+d, py,   230, 245, 255, fa)
                blend(buf, px-d, py,   230, 245, 255, fa)
                blend(buf, px,   py+d, 230, 245, 255, fa)
                blend(buf, px,   py-d, 230, 245, 255, fa)

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

    print("  Phase 1/8  aurora background…")
    phase_aurora(buf)
    print("  Phase 2/8  wthrr title…")
    phase_title(buf)
    print("  Phase 3/8  neon arrow…")
    phase_arrow(buf)
    print("  Phase 4/8  rain streaks…")
    phase_rain(buf)
    print("  Phase 5/8  snowflakes…")
    phase_snow(buf)
    print("  Phase 6/8  lightning bolt…")
    phase_lightning(buf)
    print("  Phase 7/8  fog wisps…")
    phase_fog(buf)
    print("  Phase 8/8  sparkle stars…")
    phase_stars(buf)

    write_png(out, W, H, buf)
    print("Done.")
