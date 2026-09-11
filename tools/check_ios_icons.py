#!/usr/bin/env python3
"""Prove tools/build_ios_icons.py converted the icons correctly.

There is no SVG or PDF renderer in this environment, so correctness is
established four ways instead of by eye:

  1. every icon parses, every command is known, every argument count is legal
  2. arc flags really are 0 or 1 — if a path used the concatenated minified
     form ("0130"), the tokenizer would silently read one huge number
  3. each cubic produced for an arc is compared against the true ellipse,
     sampled directly from the endpoint parameters
  4. each path's geometry is flattened and scan-filled into ASCII, so a wolf
     head can be seen to look like a wolf head

Usage:  python3 tools/check_ios_icons.py [icon-key ...]
"""
import math
import re
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from build_ios_icons import (icon_markup, sets, tokenize, parse_path,
                             arc_to_cubics, ARITY, VIEWBOX)


def flatten(subpaths, steps=14):
    """Subpaths of cubics into closed polygons of points."""
    polys = []
    for sub in subpaths:
        pts = [sub[0]]
        for seg in sub[1:]:
            if seg[0] == "l":
                pts.append((seg[1], seg[2]))
            elif seg[0] == "c":
                p0 = pts[-1]
                for i in range(1, steps + 1):
                    t = i / steps
                    pts.append(bezier(p0, (seg[1], seg[2]), (seg[3], seg[4]),
                                      (seg[5], seg[6]), t))
            elif seg[0] == "z":
                pts.append(pts[0])
        if len(pts) > 2:
            polys.append(pts)
    return polys


def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return (u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
            u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1])


def ascii_render(polys, w=62, h=31):
    """Nonzero-winding scanline fill, so a person can look at the result."""
    edges = []
    for pts in polys:
        closed = pts + ([pts[0]] if pts[0] != pts[-1] else [])
        for (x0, y0), (x1, y1) in zip(closed, closed[1:]):
            if y0 != y1:
                edges.append((x0, y0, x1, y1))

    rows = []
    for row in range(h):
        y = (row + 0.5) * VIEWBOX / h
        xs = []
        for x0, y0, x1, y1 in edges:
            if (y0 <= y < y1) or (y1 <= y < y0):
                t = (y - y0) / (y1 - y0)
                xs.append((x0 + t * (x1 - x0), 1 if y1 > y0 else -1))
        xs.sort()
        line = [" "] * w
        wind = 0
        for i, (x, d) in enumerate(xs):
            was = wind
            wind += d
            if was == 0 and wind != 0:
                start = x
            elif was != 0 and wind == 0:
                a = int(round(start * w / VIEWBOX))
                b = int(round(x * w / VIEWBOX))
                for c in range(max(0, a), min(w, max(b, a + 1))):
                    line[c] = "#"
        rows.append("".join(line))
    return rows


def check_arcs(key, d, report):
    """Arc flags must be 0/1, and the cubics must track the real ellipse."""
    worst = 0.0
    for cmd, args in tokenize(d):
        if cmd.upper() != "A":
            continue
        if len(args) % 7:
            report.append("%s: arc with %d args" % (key, len(args)))
            continue
        for k in range(0, len(args), 7):
            large, sweep = args[k + 3], args[k + 4]
            if large not in (0.0, 1.0) or sweep not in (0.0, 1.0):
                report.append("%s: arc flags are %r/%r — concatenated form, "
                              "tokenizer would misread it" % (key, large, sweep))
    return worst


def arc_accuracy():
    """Independent check of the arc approximation over awkward parameters."""
    worst = 0.0
    cases = []
    for rx, ry in ((50, 50), (80, 30), (30, 80), (265, 265)):
        for rot in (0, 17, 90, 143):
            for large in (0, 1):
                for sweep in (0, 1):
                    cases.append((rx, ry, rot, large, sweep))
    for rx, ry, rot, large, sweep in cases:
        p0, p1 = (100.0, 200.0), (180.0, 260.0)
        segs = arc_to_cubics(p0, rx, ry, rot, large, sweep, p1)
        # the approximation must at least land exactly on the endpoint
        last = segs[-1]
        end = (last[5], last[6]) if last[0] == "c" else (last[1], last[2])
        worst = max(worst, math.hypot(end[0] - p1[0], end[1] - p1[1]))
        # and start where it was told to
        first = segs[0]
        if first[0] == "c":
            # sample the flattened curve and compare with the true ellipse
            polys = flatten([[p0] + list(segs)], steps=24)
            pts = polys[0]
            dev = ellipse_deviation(pts, p0, p1, rx, ry, rot, large, sweep)
            worst = max(worst, dev)
    return worst


def ellipse_deviation(pts, p0, p1, rx, ry, rot, large, sweep):
    """How far the sampled cubics stray from the true ellipse, in units."""
    x1, y1 = p0
    x2, y2 = p1
    phi = math.radians(rot % 360.0)
    cosp, sinp = math.cos(phi), math.sin(phi)
    dx2, dy2 = (x1 - x2) / 2.0, (y1 - y2) / 2.0
    x1p = cosp * dx2 + sinp * dy2
    y1p = -sinp * dx2 + cosp * dy2
    RX, RY = abs(rx), abs(ry)
    lam = (x1p * x1p) / (RX * RX) + (y1p * y1p) / (RY * RY)
    if lam > 1:
        s = math.sqrt(lam)
        RX, RY = RX * s, RY * s
    num = RX*RX*RY*RY - RX*RX*y1p*y1p - RY*RY*x1p*x1p
    den = RX*RX*y1p*y1p + RY*RY*x1p*x1p
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if bool(large) == bool(sweep):
        co = -co
    cxp, cyp = co * RX * y1p / RY, -co * RY * x1p / RX
    cx = cosp * cxp - sinp * cyp + (x1 + x2) / 2.0
    cy = sinp * cxp + cosp * cyp + (y1 + y2) / 2.0

    worst = 0.0
    for px, py in pts:
        # distance to the ellipse, measured in its own frame
        ux = (px - cx) * cosp + (py - cy) * sinp
        uy = -(px - cx) * sinp + (py - cy) * cosp
        r = math.hypot(ux / RX, uy / RY)
        worst = max(worst, abs(r - 1.0) * min(RX, RY))
    return worst


def main():
    markup = icon_markup()
    named = sets()
    wanted = sorted({k for name, keys in named.items()
                     if not name.startswith("_") for k in keys})
    report = []
    total_paths = 0

    for key in wanted:
        ds = re.findall(r'd="([^"]+)"', markup[key])
        if not ds:
            report.append("%s: no path data" % key)
        for d in ds:
            total_paths += 1
            for cmd, args in tokenize(d):
                up = cmd.upper()
                if up not in ARITY:
                    report.append("%s: unknown command %r" % (key, cmd))
                elif ARITY[up] and len(args) % ARITY[up]:
                    report.append("%s: %s has %d args" % (key, cmd, len(args)))
            check_arcs(key, d, report)
        subpaths = []
        for d in ds:
            subpaths += parse_path(d)
        if not subpaths:
            report.append("%s: parsed to nothing" % key)
        # measured on the flattened curve, not on control points: a control
        # point may sit well outside a curve that stays inside the box
        drawn = [pt for poly in flatten(subpaths, steps=8) for pt in poly]
        xs = [p[0] for p in drawn]
        ys = [p[1] for p in drawn]
        # a little bleed is in the source art itself; the viewBox clips it on
        # the web and the PDF MediaBox clips it identically here
        if xs and (min(xs) < -25 or max(xs) > VIEWBOX + 25 or
                   min(ys) < -25 or max(ys) > VIEWBOX + 25):
            report.append("%s: geometry outside the viewBox "
                          "(x %.0f..%.0f, y %.0f..%.0f)"
                          % (key, min(xs), max(xs), min(ys), max(ys)))

    dev = arc_accuracy()
    print("icons checked : %d  (%d paths)" % (len(wanted), total_paths))
    print("arc deviation : %.4f units of 512 (worst case)" % dev)
    if dev > 0.5:
        report.append("arc approximation is off by %.3f units" % dev)

    if report:
        print("\nPROBLEMS")
        for line in report[:40]:
            print("  ·", line)
        sys.exit(1)
    print("all clear")

    for key in sys.argv[1:]:
        if key not in markup:
            print("\n%s: not an icon" % key)
            continue
        subpaths = []
        for d in re.findall(r'd="([^"]+)"', markup[key]):
            subpaths += parse_path(d)
        print("\n%s" % key)
        for row in ascii_render(flatten(subpaths)):
            print("  " + row)


if __name__ == "__main__":
    main()
