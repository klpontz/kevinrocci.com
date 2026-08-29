#!/usr/bin/env python3
"""Generate the watercolor swatch PNGs for the Off the clock section.

Standard library only — no numpy, no Pillow. Writes RGBA PNGs by hand.

The physics is a cheap version of the pigment model in Curtis et al.,
"Computer-Generated Watercolor" (1997), keeping the three effects that
actually make a wash read as watercolor:

  1. Edge darkening. Water evaporates fastest at the rim, so pigment
     migrates outward and deposits in a dark ring. This is the single
     strongest cue, and the one flat CSS gradients never have.
  2. Granulation. Heavy pigments settle into the paper's low spots,
     giving a mottled grain rather than an even film.
  3. Backruns and blooms. Water pushed back into a drying wash carries
     pigment with it and leaves pale islands with hard edges.

Pigment is applied by Beer-Lambert: a thicker deposit transmits less
light. Output alpha comes from the deposit, so the page ground shows
through the thin areas the way paper does.

Run:  python3 tools/make-swatches.py [palette ...]
      With no arguments it renders magpie, the palette the site ships.
Out:  img/<palette>/swatch-<name>.png  (240x216, 2x display size)

Deterministic — a given SEED always produces the same six swatches.
Change SEED for a different set of accidents.
"""

import math
import os
import random
import struct
import sys
import zlib

W, H = 240, 216
SEED = 20260829

# Each palette is six pigments, in the order the page shows them.
# Sampled from photographs of the bird, then adjusted so the set works
# as an interface: two large neutrals, one mid, one accent, one
# highlight, one fill.
PALETTES = {
    # American kestrel (Falco sparverius) — the original.
    "kestrel": [
        ("slate",  "#5C6E85"),
        ("rufous", "#B5561D"),
        ("buff",   "#EFE0C8"),
        ("bone",   "#FAF7F2"),
        ("ink",    "#211E1C"),
        ("gold",   "#E8B33A"),
    ],
    # Great blue heron (Ardea herodias) — softer, cooler, warm bill.
    "heron": [
        ("slate",  "#6E7E99"),  # body and folded wing
        ("rust",   "#7C4B4E"),  # shoulder patch
        ("cream",  "#E7DFCD"),  # neck and breast plumes
        ("mist",   "#F2F0E9"),  # pale throat
        ("storm",  "#2C3547"),  # crown stripe
        ("bill",   "#E39A2E"),  # bill
    ],
    # Yellow-billed magpie (Pica nuttalli) — Central Valley endemic.
    # Two big neutrals, two saturated marks. Nothing in between.
    "magpie": [
        ("wing",   "#123F52"),  # iridescent wing and tail, deep teal
        ("azure",  "#1F6EA8"),  # the blue that catches the light
        ("chalk",  "#F5F3EE"),  # belly and scapulars
        ("pewter", "#93A5B2"),  # flight-feather grey
        ("ink",    "#161C24"),  # head and breast, a warm blue-black
        ("bill",   "#F0AD1B"),  # bill and eye ring
    ],
}

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "img")


# ---------------------------------------------------------------- noise

def value_noise(rng, cells):
    """A cells x cells grid of random values, sampled with bilinear
    interpolation and a smoothstep ease. Cheap, seamless enough, and it
    needs nothing but the standard library."""
    grid = [[rng.random() for _ in range(cells + 1)] for _ in range(cells + 1)]

    def sample(u, v):
        # Wrap, so callers may sample past 1.0 to get a finer grain
        # without walking off the grid.
        x, y = (u % 1.0) * cells, (v % 1.0) * cells
        x0, y0 = int(x), int(y)
        x1, y1 = min(x0 + 1, cells), min(y0 + 1, cells)
        fx, fy = x - x0, y - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        a = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx
        b = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx
        return a * (1 - fy) + b * fy

    return sample


def fbm(rng, octaves):
    """Fractal sum of value noise. Coarse octaves give the wash its
    uneven pooling, fine octaves give the paper grain."""
    layers = []
    cells, amp, total = 3, 1.0, 0.0
    for _ in range(octaves):
        layers.append((value_noise(rng, cells), amp))
        total += amp
        cells *= 2
        amp *= 0.55

    def sample(u, v):
        return sum(fn(u, v) * amp for fn, amp in layers) / total

    return sample


# ---------------------------------------------------------------- shape

def blob_radius(rng):
    """An irregular outline: unit radius perturbed by a few low harmonics,
    the way a brush stroke pools rather than drawing a circle."""
    harmonics = [(k, rng.uniform(0.02, 0.075), rng.uniform(0, math.tau))
                 for k in (2, 3, 5, 7, 11)]

    def radius(theta):
        r = 1.0
        for k, amp, phase in harmonics:
            r += amp * math.sin(k * theta + phase)
        return r

    return radius


def smoothstep(edge0, edge1, x):
    if edge1 == edge0:
        return 0.0 if x < edge0 else 1.0
    t = (x - edge0) / (edge1 - edge0)
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- render

def render(rng, rgb):
    r_pig, g_pig, b_pig = rgb
    radius = blob_radius(rng)
    grain = fbm(rng, 5)
    pooling = fbm(rng, 3)

    # Two or three backruns: pale islands with a harder rim. Each gets
    # its own perturbed outline — a circular backrun reads as a bubble.
    blooms = []
    for _ in range(rng.randint(1, 2)):
        blooms.append((
            rng.uniform(0.28, 0.72),
            rng.uniform(0.28, 0.72),
            rng.uniform(0.09, 0.19),
            [(k, rng.uniform(0.06, 0.16), rng.uniform(0, math.tau))
             for k in (2, 3, 5)],
        ))

    cx, cy = W / 2.0, H / 2.0
    rx, ry = W * 0.46, H * 0.46
    px = bytearray()

    for y in range(H):
        px.append(0)  # PNG filter byte: none
        for x in range(W):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            dist = math.hypot(nx, ny)
            theta = math.atan2(ny, nx)
            edge = radius(theta)

            # Outside the stroke: fully transparent.
            if dist > edge + 0.06:
                px.extend((0, 0, 0, 0))
                continue

            u, v = x / float(W), y / float(H)

            # Soft boundary. Watercolor does not have a crisp outline
            # unless the paper was dry and the brush was fast.
            coverage = 1.0 - smoothstep(edge - 0.055, edge + 0.045, dist)
            if coverage <= 0.0:
                px.extend((0, 0, 0, 0))
                continue

            # 1. Edge darkening — pigment migrates to the drying rim.
            rim = smoothstep(edge - 0.22, edge - 0.015, dist)
            deposit = 0.58 + 1.05 * rim

            # 2. Pooling and granulation.
            deposit *= 0.58 + 0.90 * pooling(u, v)
            deposit *= 0.70 + 0.58 * grain(u * 2.4, v * 2.4)
            deposit *= 0.86 + 0.28 * grain(u * 7.3 + 0.37, v * 7.3 + 0.11)

            # 3. Backruns lift pigment and stack it at their own edge.
            for bx, by, br, harm in blooms:
                du, dv = u - bx, v - by
                d = math.hypot(du, dv)
                if d > br * 1.5:
                    continue
                bt = math.atan2(dv, du)
                wobble = 1.0 + sum(a * math.sin(k * bt + ph) for k, a, ph in harm)
                edge_b = br * wobble
                if d < edge_b:
                    lift = 1.0 - smoothstep(edge_b * 0.72, edge_b, d)
                    deposit *= 1.0 - 0.16 * lift
                elif d < edge_b * 1.14:
                    deposit *= 1.0 + 0.13 * (1.0 - smoothstep(edge_b, edge_b * 1.14, d))

            deposit = max(0.0, deposit)

            # Beer-Lambert: thicker deposit transmits less light.
            opacity = 1.0 - math.exp(-1.95 * deposit)
            alpha = coverage * opacity

            # Dense areas read slightly deeper, thin areas slightly warmer,
            # which is what a real single-pigment wash does.
            shade = 0.80 + 0.24 * min(1.4, deposit)
            r = int(max(0, min(255, r_pig * shade)))
            g = int(max(0, min(255, g_pig * shade)))
            b = int(max(0, min(255, b_pig * shade)))

            px.extend((r, g, b, int(max(0, min(255, alpha * 255)))))

    return bytes(px)


# ---------------------------------------------------------------- png

def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, raw):
    header = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)  # 8-bit RGBA
    blob = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(blob)
    return len(blob)


def main(argv):
    # The site ships magpie. Kestrel and heron stay defined as a
    # record of the exploration; render them by naming them.
    wanted = argv[1:] or ["magpie"]
    unknown = [n for n in wanted if n not in PALETTES]
    if unknown:
        raise SystemExit("unknown palette(s): %s\nknown: %s"
                         % (", ".join(unknown), ", ".join(PALETTES)))

    for palette in wanted:
        out = os.path.join(OUT_DIR, palette)
        os.makedirs(out, exist_ok=True)
        print(palette)
        for i, (name, hexval) in enumerate(PALETTES[palette]):
            rgb = tuple(int(hexval[j:j + 2], 16) for j in (1, 3, 5))
            # Seed off the pigment name so a swatch keeps its own
            # accidents no matter which palettes get rendered together.
            # crc32, not hash() — hash() is salted per process, and this
            # script promises the same output every run.
            rng = random.Random(SEED + zlib.crc32((palette + name).encode()))
            path = os.path.join(out, "swatch-%s.png" % name)
            size = write_png(path, render(rng, rgb))
            print("  %-18s %s  %6.1f KB" % (name, hexval, size / 1024.0))


if __name__ == "__main__":
    main(sys.argv)
