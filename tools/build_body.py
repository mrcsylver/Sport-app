#!/usr/bin/env python3
"""Draw the muscle figure and splice it into app.js.

An anatomical figure, not a diagram of boxes. Every region is a closed
outline with the shape the muscle actually has — a pectoral fans, a deltoid
caps, a triceps is a horseshoe, a quadriceps is three heads with the teardrop
low and inside — because a shape you recognise is a shape you can read at a
glance, and a rounded rectangle is not.

Outlines are written as point lists and smoothed through a Catmull-Rom to
Bezier conversion. That is the whole trick: authoring twenty anatomical
curves by hand is a week of fiddling with control points, while authoring
twenty polygons and rounding them is an afternoon, and the result is
organic rather than lumpy.

Three silhouettes share one skeleton and differ in five widths, so a region
lands on the same part of the body whichever figure somebody picked, and a
change to the shoulder line does not mean redrawing nine muscles.

Usage:  python3 tools/build_body.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from exercise_bank import MUSCLE_ORDER, MUSCLE_VIEW                # noqa: E402

W, H = 220.0, 470.0
CX = 110.0

# Five numbers separate the three figures. Everything else is shared.
FORMS = {
    'masc':    dict(sh=1.10, ch=1.10, wa=1.04, hi=0.94, li=1.06),
    'neutral': dict(sh=1.00, ch=1.00, wa=1.00, hi=1.00, li=1.00),
    'fem':     dict(sh=0.90, ch=0.90, wa=0.92, hi=1.12, li=0.95),
}


def r2(v):
    return round(v, 1)


def smooth(pts, tension=1.0):
    """A closed outline through these points, rounded.

    Catmull-Rom gives a curve that passes through every point it is given,
    which is what you want when the points ARE the anatomy: the belly of a
    biceps, the notch above a knee. Converting each span to a cubic is four
    lines and means the browser draws it as an ordinary path.
    """
    n = len(pts)
    d = 'M%s %s' % (r2(pts[0][0]), r2(pts[0][1]))
    for i in range(n):
        p0 = pts[(i - 1) % n]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6.0 * tension,
              p1[1] + (p2[1] - p0[1]) / 6.0 * tension)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6.0 * tension,
              p2[1] - (p3[1] - p1[1]) / 6.0 * tension)
        d += 'C%s %s %s %s %s %s' % (r2(c1[0]), r2(c1[1]), r2(c2[0]), r2(c2[1]),
                                     r2(p2[0]), r2(p2[1]))
    return d + 'Z'


class Body(object):
    """Coordinates for one form. `x` mirrors, so every muscle is written
    once for the right-hand side and drawn twice."""

    def __init__(self, f):
        self.f = f

    def x(self, dx, side=1):
        return CX + dx * side

    def sh(self, dx, side=1):
        return CX + dx * self.f['sh'] * side

    def ch(self, dx, side=1):
        return CX + dx * self.f['ch'] * side

    def wa(self, dx, side=1):
        return CX + dx * self.f['wa'] * side

    def hi(self, dx, side=1):
        return CX + dx * self.f['hi'] * side

    def li(self, dx, side=1):
        return CX + dx * self.f['li'] * side


def head(b):
    return smooth([(CX, 16), (b.x(13), 24), (b.x(18), 42), (b.x(15), 58),
                   (b.x(7), 66), (CX, 68), (b.x(-7), 66), (b.x(-15), 58),
                   (b.x(-18), 42), (b.x(-13), 24)], 0.9)


def torso(b):
    """Head to feet, arms excluded. One half, mirrored, so it cannot come
    out lopsided."""
    right = [
        (b.x(9), 64), (b.x(13), 74), (b.sh(22), 80), (b.sh(32), 90),
        (b.ch(33), 108), (b.ch(31), 140), (b.wa(26), 172), (b.wa(27), 192),
        (b.hi(37), 212), (b.hi(38), 240), (b.li(34), 268),
        (b.li(28), 300), (b.li(24), 326), (b.li(25), 352),
        (b.li(18), 400), (b.li(14), 424), (b.li(20), 442), (b.li(19), 452),
        (b.li(4), 452), (b.x(4), 424), (b.x(5), 380), (b.x(6), 320),
        (b.x(7), 262), (b.x(2), 246),
    ]
    return smooth(right + [(2 * CX - x, y) for x, y in reversed(right)], 0.85)


def arm(b, side=1):
    """One hanging arm, clear of the torso. Written for the right, mirrored
    for the left, so the two can never drift apart."""
    pts = [
        (b.sh(36, side), 84), (b.sh(52, side), 98), (b.sh(55, side), 130),
        (b.ch(55, side), 162), (b.ch(56, side), 196), (b.ch(57, side), 230),
        (b.ch(55, side), 258), (b.ch(52, side), 274), (b.ch(45, side), 274),
        (b.ch(44, side), 240), (b.ch(43, side), 204), (b.ch(42, side), 168),
        (b.ch(41, side), 132), (b.sh(36, side), 104),
    ]
    return smooth(pts, 0.9)


def outline(b):
    return ' '.join([head(b), torso(b), arm(b, 1), arm(b, -1)])


def front(b):
    out = []

    def add(m, pts, tension=1.0, mirror=True):
        out.append({'m': m, 'd': smooth(pts, tension)})
        if mirror:
            out.append({'m': m, 'd': smooth([(2 * CX - x, y) for x, y in pts],
                                            tension)})

    # upper trapezius: the slope from the neck out to the shoulder
    add('traps', [(b.x(5), 66), (b.x(16), 70), (b.sh(28), 86), (b.sh(24), 94),
                  (b.x(15), 84), (b.x(5), 78)], 0.8)
    # deltoid: caps the joint, so it reaches across the gap onto the arm
    add('shoulders', [(b.sh(20), 80), (b.sh(36), 82), (b.sh(50), 96),
                      (b.sh(53), 120), (b.sh(45), 130), (b.ch(30), 124),
                      (b.ch(26), 100)], 0.9)
    # pectoral: fans from the sternum up and out under the shoulder
    add('chest', [(b.x(3), 94), (b.ch(19), 92), (b.ch(29), 102),
                  (b.ch(30), 124), (b.ch(21), 136), (b.x(8), 134),
                  (b.x(3), 122)], 0.9)
    # biceps: the belly sits high on the upper arm
    add('biceps', [(b.sh(44), 126), (b.sh(53), 136), (b.ch(53), 160),
                   (b.ch(50), 176), (b.ch(44), 172), (b.ch(43), 140)], 0.95)
    # forearm: the brachioradialis swell, then a taper to the wrist
    add('forearms', [(b.ch(44), 188), (b.ch(54), 202), (b.ch(54), 230),
                     (b.ch(50), 256), (b.ch(45), 254), (b.ch(44), 218),
                     (b.ch(43), 196)], 0.95)
    # serratus and external oblique, down the flank
    add('obliques', [(b.ch(21), 142), (b.wa(27), 156), (b.wa(26), 180),
                     (b.hi(24), 198), (b.x(16), 194), (b.x(17), 162),
                     (b.x(19), 146)], 0.9)
    # quadriceps: the outer head long, the teardrop low and inside
    add('quads', [(b.hi(31), 218), (b.hi(35), 248), (b.li(30), 278),
                  (b.li(25), 300), (b.li(16), 302), (b.x(10), 282),
                  (b.x(10), 240), (b.x(17), 220)], 0.9)
    # tibialis and the outer calf head, seen from the front
    add('calves', [(b.li(22), 332), (b.li(25), 354), (b.li(21), 386),
                   (b.li(15), 404), (b.x(9), 398), (b.x(10), 356),
                   (b.x(14), 332)], 0.9)

    # rectus abdominis: three pairs of bricks and the low block
    for y in (142, 160, 178):
        for s in (-1, 1):
            add('abs', [(b.x(3, s), y - 7), (b.wa(16, s), y - 6),
                        (b.wa(17, s), y + 6), (b.x(3, s), y + 7)], 0.6,
                mirror=False)
    for s in (-1, 1):
        add('abs', [(b.x(3, s), 188), (b.wa(16, s), 190), (b.wa(12, s), 206),
                    (b.x(3, s), 210)], 0.7, mirror=False)
    return out


def back(b):
    out = []

    def add(m, pts, tension=1.0, mirror=True):
        out.append({'m': m, 'd': smooth(pts, tension)})
        if mirror:
            out.append({'m': m, 'd': smooth([(2 * CX - x, y) for x, y in pts],
                                            tension)})

    # trapezius: the whole diamond, neck to mid-back
    add('traps', [(CX, 64), (b.sh(26), 84), (b.sh(24), 98), (b.x(14), 122),
                  (CX, 136), (b.x(-14), 122), (b.sh(-24), 98), (b.sh(-26), 84)],
        0.85, mirror=False)
    # posterior deltoid
    add('shoulders', [(b.sh(20), 80), (b.sh(36), 82), (b.sh(50), 96),
                      (b.sh(53), 120), (b.sh(45), 130), (b.ch(30), 124),
                      (b.ch(26), 100)], 0.9)
    # latissimus: wide under the armpit, tapering into the waist
    add('lats', [(b.ch(25), 108), (b.ch(32), 124), (b.ch(31), 152),
                 (b.wa(27), 178), (b.wa(16), 192), (b.x(10), 186),
                 (b.x(11), 150), (b.x(16), 124)], 0.9)
    # triceps: the horseshoe on the back of the upper arm
    add('triceps', [(b.sh(44), 124), (b.sh(53), 134), (b.ch(53), 162),
                    (b.ch(50), 178), (b.ch(44), 174), (b.ch(43), 138)], 0.95)
    add('forearms', [(b.ch(44), 188), (b.ch(54), 202), (b.ch(54), 230),
                     (b.ch(50), 256), (b.ch(45), 254), (b.ch(44), 218),
                     (b.ch(43), 196)], 0.95)
    # erector spinae, either side of the spine
    add('lowerback', [(b.x(4), 152), (b.x(15), 158), (b.wa(16), 184),
                      (b.wa(13), 202), (b.x(4), 202)], 0.85)
    # gluteus maximus
    add('glutes', [(b.x(3), 206), (b.hi(22), 204), (b.hi(34), 216),
                   (b.hi(33), 240), (b.hi(20), 252), (b.x(4), 248)], 0.95)
    # hamstrings
    add('hamstrings', [(b.hi(30), 256), (b.li(30), 284), (b.li(25), 306),
                       (b.li(15), 310), (b.x(9), 292), (b.x(9), 260)], 0.9)
    # gastrocnemius, two heads and the achilles taper
    add('calves', [(b.li(23), 332), (b.li(26), 354), (b.li(22), 384),
                   (b.li(15), 398), (b.x(9), 390), (b.x(9), 354),
                   (b.x(14), 332)], 0.95)
    return out


def main():
    body = {}
    for name, f in FORMS.items():
        b = Body(f)
        body[name] = {'outline': outline(b), 'front': front(b), 'back': back(b)}

    for name, v in body.items():
        for view in ('front', 'back'):
            drawn = {p['m'] for p in v[view]}
            want = {m for m in MUSCLE_ORDER if MUSCLE_VIEW[m] in (view, 'both')}
            assert drawn == want, (name, view, sorted(want ^ drawn))

    js = ('  /* BODY BEGIN */\n'
          '  /* GENERATED by tools/build_body.py — do not edit by hand.\n'
          '     An anatomical figure: every region is the shape the muscle\n'
          '     actually has, in three silhouettes sharing one skeleton.\n'
          '     `m` is the muscle key, `d` the path. */\n'
          '  var BODY_BOX = [%g, %g];\n' % (W, H)
          + '  var BODY = ' + json.dumps(body, separators=(',', ':')) + ';\n'
          + '  /* BODY END */')

    app = os.path.join(ROOT, 'app.js')
    text = open(app, encoding='utf-8').read()
    a = text.index('  /* BODY BEGIN */')
    b2 = text.index('/* BODY END */', a) + len('/* BODY END */')
    out = text[:a] + js + text[b2:]
    if out != text:
        open(app, 'w', encoding='utf-8').write(out)
        print('spliced app.js')
    else:
        print('app.js already up to date')
    print('%d forms, %d front + %d back outlines'
          % (len(FORMS), len(body['neutral']['front']), len(body['neutral']['back'])))


if __name__ == '__main__':
    main()
