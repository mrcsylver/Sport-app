#!/usr/bin/env python3
"""Draw the app icon, reusing the icon pipeline rather than shipping a stub.

The mark is a game-icon rasterised over the app's own heat gradient, at the
one size modern Xcode wants (1024, single size). PNG is written by hand —
zlib is in the standard library, an image library is not.

Usage:  python3 tools/build_ios_appicon.py
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from build_ios_icons import icon_markup, parse_path, VIEWBOX      # noqa: E402
from check_ios_icons import flatten                                # noqa: E402

OUT = os.path.join(ROOT, "ios", "IronLeague", "Assets.xcassets", "AppIcon.appiconset")
SIZE = 1024
SS = 3                      # supersampling, so the edges are not staircases
MARK = "muscle-up"      # the app is about lifting your own weight

VOID = (0x07, 0x08, 0x0B)
FLAME = (0xFF, 0x2E, 0x2E)
EMBER = (0xFF, 0x6A, 0x1F)
GOLD = (0xFF, 0xC9, 0x3C)

CONTENTS = """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "tools/build_ios_appicon.py",
    "version" : 1
  }
}
"""


def coverage(polys, size, ss):
    """Nonzero-winding scanline fill at ss× resolution, averaged down."""
    big = size * ss
    scale = big / VIEWBOX
    edges = []
    for pts in polys:
        closed = pts + ([pts[0]] if pts[0] != pts[-1] else [])
        for (x0, y0), (x1, y1) in zip(closed, closed[1:]):
            if y0 != y1:
                edges.append((x0 * scale, y0 * scale, x1 * scale, y1 * scale))

    # bucket edges by scanline so the fill is O(edges) not O(edges × rows)
    rows = [[] for _ in range(big)]
    for x0, y0, x1, y1 in edges:
        lo, hi = sorted((y0, y1))
        for r in range(max(0, int(lo)), min(big, int(hi) + 1)):
            rows[r].append((x0, y0, x1, y1))

    acc = [[0] * size for _ in range(size)]
    for r in range(big):
        y = r + 0.5
        xs = []
        for x0, y0, x1, y1 in rows[r]:
            if (y0 <= y < y1) or (y1 <= y < y0):
                t = (y - y0) / (y1 - y0)
                xs.append((x0 + t * (x1 - x0), 1 if y1 > y0 else -1))
        if not xs:
            continue
        xs.sort()
        wind = 0
        start = 0.0
        out = acc[r // ss]
        for x, d in xs:
            was = wind
            wind += d
            if was == 0 and wind != 0:
                start = x
            elif was != 0 and wind == 0:
                for c in range(max(0, int(start)), min(big, int(x) + 1)):
                    out[c // ss] += 1
    return acc


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def png(path, pixels, size):
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b in row:
            raw += bytes((r, g, b))

    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    head = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    blob = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", head)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(blob)


def main():
    markup = icon_markup()
    if MARK not in markup:
        sys.exit("no such icon: %s" % MARK)

    subpaths = []
    import re
    for d in re.findall(r'd="([^"]+)"', markup[MARK]):
        subpaths += parse_path(d)

    # centre on the mark's own bounding box, not on the viewBox: game-icons
    # are drawn to fill the box loosely and a naive inset lands them low
    polys = flatten(subpaths, steps=18)
    pts = [p for poly in polys for p in poly]
    minx = min(p[0] for p in pts); maxx = max(p[0] for p in pts)
    miny = min(p[1] for p in pts); maxy = max(p[1] for p in pts)
    span = max(maxx - minx, maxy - miny)
    scale = VIEWBOX * 0.60 / span
    dx = VIEWBOX / 2 - (minx + maxx) / 2 * scale
    dy = VIEWBOX / 2 - (miny + maxy) / 2 * scale
    placed = [[(x * scale + dx, y * scale + dy) for x, y in poly] for poly in polys]

    cov = coverage(placed, SIZE, SS)
    full = SS * SS

    pixels = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            # the ground: the heat gradient corner to corner, with the light
            # coming from the top left so the tile has a direction
            t = (x + y) / (2 * (SIZE - 1))
            ground = mix(mix(FLAME, EMBER, min(1, t * 2)), GOLD, max(0, t * 2 - 1))
            fall = ((x / SIZE - 0.28) ** 2 + (y / SIZE - 0.22) ** 2) ** 0.5
            ground = mix(ground, VOID, min(0.72, max(0.0, (fall - 0.42) * 0.95)))

            a = min(1.0, cov[y][x] / full)
            row.append(mix(ground, VOID, a) if a else ground)
        pixels.append(row)

    os.makedirs(OUT, exist_ok=True)
    png(os.path.join(OUT, "AppIcon.png"), pixels, SIZE)
    open(os.path.join(OUT, "Contents.json"), "w").write(CONTENTS)
    print("wrote %s" % os.path.relpath(os.path.join(OUT, "AppIcon.png"), ROOT))


if __name__ == "__main__":
    main()
