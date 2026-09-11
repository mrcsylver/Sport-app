#!/usr/bin/env python3
"""Turn the vendored game-icons into vector assets Xcode can use.

The web app renders these as inline SVG. iOS has no SVG renderer, and mapping
them onto SF Symbols would put the same symbol on ten different animals — the
exact thing we were told not to do. So each icon is converted, here at build
time, into a single-page vector PDF and dropped into the asset catalog with
`template-rendering-intent`, which lets SwiftUI tint it with foregroundStyle
the same way `currentColor` tints the SVG.

Doing the maths in Python rather than in Swift is deliberate: this file can be
run and checked (see tools/check_ios_icons.py), a Swift path parser could not.

Usage:  python3 tools/build_ios_icons.py
"""
import json
import math
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "vendor", "game-icons.js")
OUT = os.path.join(ROOT, "ios", "IronLeague", "Assets.xcassets", "Icons")
VIEWBOX = 512.0

# ---------------------------------------------------------------- source ----

def icon_markup():
    """{key: "<path d=...><path d=...>"} straight out of the vendored file."""
    text = open(SRC, encoding="utf-8").read()
    start = text.index("var GI_ICONS = ") + len("var GI_ICONS = ")
    end = text.index("};", start) + 1
    return json.loads(text[start:end])


def sets():
    """The four named sets, so we only ship what the app can actually use."""
    text = open(SRC, encoding="utf-8").read()
    out = {}
    for name in ("GI_AVATARS", "GI_CRESTS"):
        m = re.search(name + r"\s*=\s*\[(.*?)\];", text, re.S)
        out[name] = re.findall(r"['\"]([a-z0-9\-]+)['\"]", m.group(1))
    for name in ("GI_BADGE_ART", "GI_CAT"):
        m = re.search(name + r"\s*=\s*(\{.*?\});", text, re.S)
        table = json.loads(m.group(1))
        out[name] = list(table.values())
        out["_" + name.replace("GI_", "").replace("_ART", "") + "_MAP"] = table
    return out


# ---------------------------------------------------------------- parsing ---

NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def tokenize(d):
    """A path string into ('C', [numbers]) pairs, one per command."""
    out, i, n = [], 0, len(d)
    cmd = None
    while i < n:
        ch = d[i]
        if ch in " ,\t\r\n":
            i += 1
            continue
        if ch.isalpha():
            cmd = ch
            i += 1
            args = []
        else:
            if cmd is None:
                raise ValueError("number before any command in %r" % d[:40])
            args = []
        # gather the numbers that belong to this command
        while i < n:
            m = NUM.match(d, i)
            if not m:
                if d[i] in " ,\t\r\n":
                    i += 1
                    continue
                break
            args.append(float(m.group(0)))
            i = m.end()
        out.append((cmd, args))
        # an implicit repeat of the last command keeps the same letter, except
        # that a repeated moveto means lineto (SVG 8.3.2)
        if cmd == "M":
            cmd = "L"
        elif cmd == "m":
            cmd = "l"
    return out


ARITY = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 4, "A": 7, "Z": 0}


def parse_path(d):
    """A path string into subpaths of cubics.

    Returns [[(x0,y0), ('c', x1,y1, x2,y2, x,y), ...], ...] — every curve is a
    cubic, because that is all PDF understands.
    """
    subs, cur = [], None
    x = y = 0.0
    sx = sy = 0.0            # subpath start, for Z
    px = py = None           # previous control point, for S / T
    last = None

    for cmd, args in tokenize(d):
        up = cmd.upper()
        rel = cmd.islower()
        if up == "Z":
            if cur is not None:
                cur.append(("z",))
                x, y = sx, sy
            px = py = None
            last = up
            continue

        need = ARITY[up]
        if need == 0 or not args:
            continue
        if len(args) % need:
            raise ValueError("%s wants a multiple of %d numbers, got %d"
                             % (cmd, need, len(args)))

        for k in range(0, len(args), need):
            a = args[k:k + need]

            if up == "M":
                x, y = (x + a[0], y + a[1]) if rel else (a[0], a[1])
                if k == 0:
                    cur = [(x, y)]
                    subs.append(cur)
                    sx, sy = x, y
                else:
                    # extra pairs after a moveto are linetos (SVG 8.3.2)
                    cur = ensure(subs, cur, x, y)
                    cur.append(("l", x, y))
                px = py = None

            elif up in ("L", "H", "V"):
                if up == "L":
                    nx, ny = (x + a[0], y + a[1]) if rel else (a[0], a[1])
                elif up == "H":
                    nx, ny = (x + a[0]) if rel else a[0], y
                else:
                    nx, ny = x, (y + a[0]) if rel else a[0]
                cur = ensure(subs, cur, x, y)
                cur.append(("l", nx, ny))
                x, y = nx, ny
                px = py = None

            elif up == "C":
                if rel:
                    c1 = (x + a[0], y + a[1]); c2 = (x + a[2], y + a[3]); e = (x + a[4], y + a[5])
                else:
                    c1 = (a[0], a[1]); c2 = (a[2], a[3]); e = (a[4], a[5])
                cur = ensure(subs, cur, x, y)
                cur.append(("c", c1[0], c1[1], c2[0], c2[1], e[0], e[1]))
                px, py = c2
                x, y = e

            elif up == "S":
                # first control point mirrors the previous curve's second one
                if last in ("C", "S") and px is not None:
                    c1 = (2 * x - px, 2 * y - py)
                else:
                    c1 = (x, y)
                if rel:
                    c2 = (x + a[0], y + a[1]); e = (x + a[2], y + a[3])
                else:
                    c2 = (a[0], a[1]); e = (a[2], a[3])
                cur = ensure(subs, cur, x, y)
                cur.append(("c", c1[0], c1[1], c2[0], c2[1], e[0], e[1]))
                px, py = c2
                x, y = e

            elif up == "Q":
                if rel:
                    q = (x + a[0], y + a[1]); e = (x + a[2], y + a[3])
                else:
                    q = (a[0], a[1]); e = (a[2], a[3])
                cur = ensure(subs, cur, x, y)
                cur.append(quad_to_cubic((x, y), q, e))
                px, py = q
                x, y = e

            elif up == "T":
                if last in ("Q", "T") and px is not None:
                    q = (2 * x - px, 2 * y - py)
                else:
                    q = (x, y)
                e = (x + a[0], y + a[1]) if rel else (a[0], a[1])
                cur = ensure(subs, cur, x, y)
                cur.append(quad_to_cubic((x, y), q, e))
                px, py = q
                x, y = e

            elif up == "A":
                rx, ry, rot, large, sweep = a[0], a[1], a[2], a[3], a[4]
                e = (x + a[5], y + a[6]) if rel else (a[5], a[6])
                cur = ensure(subs, cur, x, y)
                for seg in arc_to_cubics((x, y), rx, ry, rot, large, sweep, e):
                    cur.append(seg)
                x, y = e
                px = py = None

            last = up
    return [s for s in subs if len(s) > 1]


def ensure(subs, cur, x, y):
    """A path may start with a drawing command; give it a subpath to live in."""
    if cur is None:
        cur = [(x, y)]
        subs.append(cur)
    return cur


def quad_to_cubic(p0, q, p1):
    return ("c",
            p0[0] + 2.0 / 3.0 * (q[0] - p0[0]), p0[1] + 2.0 / 3.0 * (q[1] - p0[1]),
            p1[0] + 2.0 / 3.0 * (q[0] - p1[0]), p1[1] + 2.0 / 3.0 * (q[1] - p1[1]),
            p1[0], p1[1])


def arc_to_cubics(p0, rx, ry, rot_deg, large, sweep, p1):
    """SVG elliptical arc to cubics — the F.6.5 endpoint parameterisation."""
    x1, y1 = p0
    x2, y2 = p1
    if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2):
        return [("l", x2, y2)]

    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rot_deg % 360.0)
    cosp, sinp = math.cos(phi), math.sin(phi)

    # step 1: the endpoints in the ellipse's own frame
    dx2, dy2 = (x1 - x2) / 2.0, (y1 - y2) / 2.0
    x1p = cosp * dx2 + sinp * dy2
    y1p = -sinp * dx2 + cosp * dy2

    # step 2: radii big enough to reach
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx, ry = rx * s, ry * s

    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if bool(large) == bool(sweep):
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx

    cx = cosp * cxp - sinp * cyp + (x1 + x2) / 2.0
    cy = sinp * cxp + cosp * cyp + (y1 + y2) / 2.0

    def angle(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        n = math.hypot(ux, uy) * math.hypot(vx, vy)
        if n == 0:
            return 0.0
        a = math.acos(max(-1.0, min(1.0, dot / n)))
        return -a if (ux * vy - uy * vx) < 0 else a

    theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dtheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                   (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dtheta > 0:
        dtheta -= 2 * math.pi
    elif sweep and dtheta < 0:
        dtheta += 2 * math.pi

    # step 4: never approximate more than 90 degrees with one cubic
    pieces = max(1, int(math.ceil(abs(dtheta) / (math.pi / 2) - 1e-9)))
    step = dtheta / pieces
    alpha = 4.0 / 3.0 * math.tan(step / 4.0)

    out = []
    t = theta1
    for _ in range(pieces):
        t2 = t + step
        p_a = ellipse_point(cx, cy, rx, ry, cosp, sinp, t)
        p_b = ellipse_point(cx, cy, rx, ry, cosp, sinp, t2)
        d_a = ellipse_deriv(rx, ry, cosp, sinp, t)
        d_b = ellipse_deriv(rx, ry, cosp, sinp, t2)
        out.append(("c",
                    p_a[0] + alpha * d_a[0], p_a[1] + alpha * d_a[1],
                    p_b[0] - alpha * d_b[0], p_b[1] - alpha * d_b[1],
                    p_b[0], p_b[1]))
        t = t2
    return out


def ellipse_point(cx, cy, rx, ry, cosp, sinp, t):
    ct, st = math.cos(t), math.sin(t)
    return (cx + rx * ct * cosp - ry * st * sinp,
            cy + rx * ct * sinp + ry * st * cosp)


def ellipse_deriv(rx, ry, cosp, sinp, t):
    ct, st = math.cos(t), math.sin(t)
    return (-rx * st * cosp - ry * ct * sinp,
            -rx * st * sinp + ry * ct * cosp)


# ------------------------------------------------------------------- PDF ----

def content_stream(subpaths, even_odd=False):
    """Geometry into a PDF content stream, flipped into PDF's y-up space."""
    out = ["1 0 0 -1 0 %g cm" % VIEWBOX, "0 g"]
    for sub in subpaths:
        x0, y0 = sub[0]
        out.append("%s %s m" % (f(x0), f(y0)))
        for seg in sub[1:]:
            if seg[0] == "l":
                out.append("%s %s l" % (f(seg[1]), f(seg[2])))
            elif seg[0] == "c":
                out.append("%s %s %s %s %s %s c"
                           % tuple(f(v) for v in seg[1:7]))
            elif seg[0] == "z":
                out.append("h")
    out.append("f*" if even_odd else "f")
    return "\n".join(out)


def f(v):
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def pdf_bytes(stream):
    """A one-page PDF, written by hand so the build needs no dependencies."""
    body = stream.encode("ascii")
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        ("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %g %g] "
         "/Contents 4 0 R /Resources << >> >>" % (VIEWBOX, VIEWBOX)).encode("ascii"),
        b"<< /Length " + str(len(body)).encode("ascii") + b" >>\nstream\n" + body + b"\nendstream",
    ]
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for i, o in enumerate(objs, start=1):
        offsets.append(len(out))
        out += str(i).encode("ascii") + b" 0 obj\n" + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 " + str(len(objs) + 1).encode("ascii") + b"\n"
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += ("%010d 00000 n \n" % off).encode("ascii")
    out += (b"trailer\n<< /Size " + str(len(objs) + 1).encode("ascii")
            + b" /Root 1 0 R >>\nstartxref\n"
            + str(xref).encode("ascii") + b"\n%%EOF\n")
    return bytes(out)


CONTENTS = """{
  "images" : [
    {
      "filename" : "%s.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "tools/build_ios_icons.py",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
"""

ROOT_CONTENTS = """{
  "info" : {
    "author" : "tools/build_ios_icons.py",
    "version" : 1
  },
  "properties" : {
    "provides-namespace" : false
  }
}
"""


SWIFT_HEAD = """// Generated by tools/build_ios_icons.py — do not edit.
//
// The same four icon sets the web app uses, in the same order, so a choice
// made on either side means the same thing. Keeping this generated is what
// stops the two apps drifting apart.

enum IconSet {
"""


def swift_catalogue(named):
    """Emit the four sets as Swift, straight from the vendored JavaScript."""
    out = [SWIFT_HEAD]
    out.append("    /// What a person can wear as their mark — %d of them."
               % len(named["GI_AVATARS"]))
    out.append("    static let avatars: [String] = [")
    out += wrap(named["GI_AVATARS"])
    out.append("    ]\n")
    out.append("    /// What a league can wear as its crest — %d, and never a"
               " face, so a crest can never be mistaken for a player."
               % len(named["GI_CRESTS"]))
    out.append("    static let crests: [String] = [")
    out += wrap(named["GI_CRESTS"])
    out.append("    ]\n")
    out.append("    /// Badge artwork, keyed by the badge the server hands out.")
    out.append("    static let badgeArt: [String: String] = [")
    out += ["        %s: %s," % (q(k), q(v)) for k, v in named["_BADGE_MAP"].items()]
    out.append("    ]\n")
    out.append("    /// One mark per muscle group, used in menus.")
    out.append("    static let category: [String: String] = [")
    out += ["        %s: %s," % (q(k), q(v)) for k, v in named["_CAT_MAP"].items()]
    out.append("    ]")
    out.append("}")
    return "\n".join(out) + "\n"


def wrap(keys, per_line=4):
    lines = []
    for i in range(0, len(keys), per_line):
        lines.append("        " + ", ".join(q(k) for k in keys[i:i + per_line]) + ",")
    return lines


def q(s):
    return '"%s"' % s


def main():
    markup = icon_markup()
    named = sets()
    wanted = sorted({k for name, keys in named.items()
                     if not name.startswith("_") for k in keys})
    missing = [k for k in wanted if k not in markup]
    if missing:
        sys.exit("icons missing from vendor/game-icons.js: %s" % missing)

    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    open(os.path.join(OUT, "Contents.json"), "w").write(ROOT_CONTENTS)

    written = 0
    for key in wanted:
        ds = re.findall(r'd="([^"]+)"', markup[key])
        if not ds:
            sys.exit("no path data for %s" % key)
        even_odd = 'fill-rule="evenodd"' in markup[key]
        subpaths = []
        for d in ds:
            subpaths += parse_path(d)
        name = "gi-" + key
        folder = os.path.join(OUT, name + ".imageset")
        os.makedirs(folder)
        open(os.path.join(folder, "Contents.json"), "w").write(CONTENTS % name)
        with open(os.path.join(folder, name + ".pdf"), "wb") as fh:
            fh.write(pdf_bytes(content_stream(subpaths, even_odd)))
        written += 1

    catalogue = os.path.join(ROOT, "ios", "IronLeague", "Design", "IconSets.swift")
    with open(catalogue, "w") as fh:
        fh.write(swift_catalogue(named))

    print("wrote %d vector icons to %s" % (written, os.path.relpath(OUT, ROOT)))
    print("wrote %s" % os.path.relpath(catalogue, ROOT))


if __name__ == "__main__":
    main()
