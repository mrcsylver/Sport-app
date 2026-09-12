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
# Five numbers separate the three figures, and they are pushed far enough
# apart to be obvious at a glance: a picker whose result you cannot see is a
# picker that looks broken. Shoulders and hips move in opposite directions,
# which is the difference the eye actually reads.
FORMS = {
    'masc':    dict(sh=1.18, ch=1.14, wa=1.06, hi=0.88, li=1.10),
    'neutral': dict(sh=1.00, ch=1.00, wa=1.00, hi=1.00, li=1.00),
    'fem':     dict(sh=0.84, ch=0.88, wa=0.86, hi=1.20, li=0.92),
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

    def ap(self, d, y, side=1):
        """A point on the hanging arm: d out from its inner edge, at height y.

        The arm cannot be positioned off the chest alone. On the wide-hipped
        figure the chest is narrow and the hip is not, so a chest-relative arm
        hangs straight through the hip; on the broad-shouldered one a
        hip-relative arm floats a thumb's width off the ribs. So it hangs from
        the shoulder at the top and clears the hip at the bottom, and angles
        out in between exactly as much as it needs to — which is what arms do.
        """
        top = self.f['sh'] * 38
        bot = max(top, self.f['hi'] * 37 + 5)
        t = min(1.0, max(0.0, (y - 90.0) / 184.0))
        return (CX + (top + (bot - top) * t + d) * side, y)


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
    a = lambda d, y: b.ap(d, y, side)                              # noqa: E731
    pts = [
        a(-4, 84), a(12, 96), a(15, 128), a(15, 162), a(16, 196), a(17, 230),
        a(15, 258), a(12, 274), a(4, 274), a(3, 240), a(2, 204), a(1, 168),
        a(0, 132), a(-4, 104),
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
    # deltoid, two heads: the front slip that runs onto the chest, and the
    # side cap over the joint. One region, drawn the way it looks.
    add('shoulders', [(b.sh(19), 82), (b.sh(29), 84), b.ap(2, 104),
                      b.ap(0, 118), (b.ch(26), 116), (b.ch(23), 98)], 0.9)
    add('shoulders', [(b.sh(29), 82), b.ap(7, 90), b.ap(14, 106),
                      b.ap(12, 124), b.ap(3, 124), b.ap(1, 102)], 0.92)
    # pectoral: the clavicular slip along the top, then the main fan with its
    # lower border sitting flat above the ribs
    add('chest', [(b.x(4), 92), (b.ch(18), 90), (b.ch(28), 98),
                  (b.ch(26), 106), (b.ch(14), 102), (b.x(4), 100)], 0.85)
    add('chest', [(b.x(4), 104), (b.ch(16), 102), (b.ch(29), 110),
                  (b.ch(29), 126), (b.ch(19), 137), (b.x(7), 136),
                  (b.x(4), 126)], 0.9)
    # biceps: two heads, the short one inside and a little lower
    add('biceps', [b.ap(2, 128), b.ap(8, 136), b.ap(8, 162),
                   b.ap(6, 176), b.ap(2, 172), b.ap(2, 140)], 0.95)
    add('biceps', [b.ap(8, 132), b.ap(14, 142), b.ap(13, 166),
                   b.ap(9, 176), b.ap(7, 168), b.ap(8, 142)], 0.95)
    # forearm: brachioradialis on the thumb side, the flexor mass behind it
    add('forearms', [b.ap(6, 186), b.ap(14, 200), b.ap(14, 226),
                     b.ap(11, 252), b.ap(8, 250), b.ap(8, 216),
                     b.ap(5, 194)], 0.95)
    add('forearms', [b.ap(3, 192), b.ap(7, 206), b.ap(7, 232),
                     b.ap(6, 252), b.ap(3, 250), b.ap(3, 214)], 0.95)
    # serratus and external oblique, down the flank
    add('obliques', [(b.ch(21), 142), (b.wa(27), 156), (b.wa(26), 180),
                     (b.hi(24), 198), (b.x(16), 194), (b.x(17), 162),
                     (b.x(19), 146)], 0.9)
    # quadriceps, the three heads you can see: the outer sweep, the rectus
    # down the middle, and the teardrop low and inside
    add('quads', [(b.hi(31), 218), (b.hi(35), 248), (b.li(31), 276),
                  (b.li(26), 296), (b.li(21), 292), (b.li(22), 250),
                  (b.hi(24), 220)], 0.9)
    add('quads', [(b.hi(22), 222), (b.li(21), 254), (b.li(20), 288),
                  (b.li(15), 298), (b.x(12), 286), (b.x(12), 244),
                  (b.x(15), 224)], 0.9)
    add('quads', [(b.li(20), 274), (b.li(24), 288), (b.li(22), 302),
                  (b.li(14), 304), (b.x(12), 292), (b.x(14), 278)], 0.95)
    # from the front: the tibialis down the shin, and the outer calf behind it
    add('calves', [(b.li(15), 334), (b.li(19), 356), (b.li(16), 388),
                   (b.li(12), 404), (b.x(8), 398), (b.x(9), 358),
                   (b.x(11), 336)], 0.9)
    add('calves', [(b.li(23), 336), (b.li(25), 356), (b.li(21), 382),
                   (b.li(17), 390), (b.li(16), 358), (b.li(18), 336)], 0.95)

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
    # posterior deltoid, and the side head coming round the joint
    add('shoulders', [(b.sh(20), 84), (b.sh(30), 86), b.ap(3, 104),
                      b.ap(1, 120), (b.ch(27), 118), (b.ch(24), 100)], 0.9)
    add('shoulders', [(b.sh(30), 84), b.ap(8, 92), b.ap(14, 108),
                      b.ap(12, 126), b.ap(3, 126), b.ap(1, 102)], 0.92)
    # latissimus: wide under the armpit, tapering into the waist
    add('lats', [(b.ch(25), 108), (b.ch(32), 124), (b.ch(31), 152),
                 (b.wa(27), 178), (b.wa(16), 192), (b.x(10), 186),
                 (b.x(11), 150), (b.x(16), 124)], 0.9)
    # triceps: the long head running high and inside, the lateral head
    # outside it — the horseshoe, as far as a silhouette shows one
    add('triceps', [b.ap(2, 124), b.ap(7, 134), b.ap(7, 164),
                    b.ap(5, 180), b.ap(2, 176), b.ap(1, 138)], 0.95)
    add('triceps', [b.ap(7, 130), b.ap(14, 142), b.ap(13, 168),
                    b.ap(9, 179), b.ap(7, 170), b.ap(7, 142)], 0.95)
    add('forearms', [b.ap(6, 186), b.ap(14, 200), b.ap(14, 226),
                     b.ap(11, 252), b.ap(8, 250), b.ap(8, 216),
                     b.ap(5, 194)], 0.95)
    add('forearms', [b.ap(3, 192), b.ap(7, 206), b.ap(7, 232),
                     b.ap(6, 252), b.ap(3, 250), b.ap(3, 214)], 0.95)
    # erector spinae, either side of the spine
    add('lowerback', [(b.x(4), 152), (b.x(15), 158), (b.wa(16), 184),
                      (b.wa(13), 202), (b.x(4), 202)], 0.85)
    # gluteus maximus
    add('glutes', [(b.x(3), 206), (b.hi(22), 204), (b.hi(34), 216),
                   (b.hi(33), 240), (b.hi(20), 252), (b.x(4), 248)], 0.95)
    # hamstrings: biceps femoris outside, semitendinosus inside
    add('hamstrings', [(b.hi(30), 256), (b.li(30), 284), (b.li(26), 306),
                       (b.li(21), 308), (b.li(21), 268), (b.hi(24), 256)], 0.9)
    add('hamstrings', [(b.hi(22), 258), (b.li(20), 286), (b.li(19), 306),
                       (b.li(13), 306), (b.x(10), 288), (b.x(10), 260)], 0.9)
    # gastrocnemius: the two heads, and the achilles taper between them
    add('calves', [(b.li(23), 334), (b.li(26), 354), (b.li(22), 382),
                   (b.li(17), 390), (b.li(16), 356), (b.li(18), 334)], 0.95)
    add('calves', [(b.li(15), 334), (b.li(17), 356), (b.li(15), 386),
                   (b.li(11), 396), (b.x(8), 386), (b.x(9), 354),
                   (b.x(11), 336)], 0.95)
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
