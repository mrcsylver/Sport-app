#!/usr/bin/env python3
"""Draw the muscle figure and splice it into app.js.

An artist's mannequin rather than an anatomy plate: every region is one
rounded plate, because a plate is a thing a thumb can hit on a phone and an
anatomical outline is not. Fourteen regions across two views, in three
silhouettes that differ only in width.

The geometry is generated rather than hand-drawn so the three forms cannot
drift apart and a change to the shoulder line does not mean re-drawing nine
paths. Everything is built from two primitives — a rounded plate and a
tapered limb segment — which is also why it reads as one figure instead of a
collection of blobs.

Usage:  python3 tools/build_body.py
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from exercise_bank import MUSCLE_ORDER, MUSCLE_VIEW                # noqa: E402

W, H = 220.0, 460.0            # the viewBox every figure is drawn in

# The three silhouettes. Only widths differ: the same skeleton, so a region
# lands on the same part of the body whichever figure somebody picked.
FORMS = {
    'masc':    dict(shoulder=52, chest=44, waist=33, hip=38, thigh=22, arm=12),
    'neutral': dict(shoulder=47, chest=39, waist=31, hip=37, thigh=21, arm=11),
    'fem':     dict(shoulder=42, chest=35, waist=28, hip=42, thigh=22, arm=10),
}

# Vertical landmarks, shared by every form.
Y = dict(head=44, chin=68, neck=80, shoulder=94, chestTop=104, chestLow=148,
         waist=176, hip=204, crotch=222, knee=306, ankle=396, foot=418,
         elbow=196, wrist=256)


def r2(v):
    return round(v, 1)


def path(points, close=True):
    d = 'M%s %s' % (r2(points[0][0]), r2(points[0][1]))
    for x, y in points[1:]:
        d += 'L%s %s' % (r2(x), r2(y))
    return d + ('Z' if close else '')


def blob(cx, cy, rx, ry, squish=0.55, tilt=0.0):
    """A rounded plate: an ellipse drawn as four cubics so it can be tilted
    and squashed without the browser having to compose transforms."""
    k = squish * 1.3
    pts = []
    cos, sin = math.cos(tilt), math.sin(tilt)

    def at(x, y):
        return (cx + x * cos - y * sin, cy + x * sin + y * cos)

    p0, p1, p2, p3 = at(0, -ry), at(rx, 0), at(0, ry), at(-rx, 0)
    c = [at(rx * k, -ry), at(rx, -ry * k),
         at(rx, ry * k), at(rx * k, ry),
         at(-rx * k, ry), at(-rx, ry * k),
         at(-rx, -ry * k), at(-rx * k, -ry)]
    d = 'M%s %s' % (r2(p0[0]), r2(p0[1]))
    for a, b, e in ((c[0], c[1], p1), (c[2], c[3], p2),
                    (c[4], c[5], p3), (c[6], c[7], p0)):
        d += 'C%s %s %s %s %s %s' % (r2(a[0]), r2(a[1]), r2(b[0]), r2(b[1]),
                                     r2(e[0]), r2(e[1]))
    pts.append(d)
    return d + 'Z'


def segment(x1, y1, w1, x2, y2, w2, cap=6.0):
    """A tapered limb plate from (x1,y1) half-width w1 to (x2,y2) half-width
    w2, with rounded ends. Arms and legs are all this shape."""
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / L, dx / L          # unit normal
    ux, uy = dx / L, dy / L           # unit along
    a = (x1 + nx * w1, y1 + ny * w1)
    b = (x2 + nx * w2, y2 + ny * w2)
    c = (x2 - nx * w2, y2 - ny * w2)
    e = (x1 - nx * w1, y1 - ny * w1)
    k = cap * 0.66
    return ('M%s %s' % (r2(a[0]), r2(a[1]))
            + 'L%s %s' % (r2(b[0]), r2(b[1]))
            + 'C%s %s %s %s %s %s' % (
                r2(b[0] + ux * k), r2(b[1] + uy * k),
                r2(c[0] + ux * k), r2(c[1] + uy * k), r2(c[0]), r2(c[1]))
            + 'L%s %s' % (r2(e[0]), r2(e[1]))
            + 'C%s %s %s %s %s %s' % (
                r2(e[0] - ux * k), r2(e[1] - uy * k),
                r2(a[0] - ux * k), r2(a[1] - uy * k), r2(a[0]), r2(a[1]))
            + 'Z')


def arm_line(f, side):
    """Where the arm hangs: shoulder, elbow, wrist. Slightly out from the
    body so the torso plates are never crowded."""
    s = side
    sx = 100 + s * (f['shoulder'] - 6)
    ex = 100 + s * (f['hip'] + 10)
    wx = 100 + s * (f['hip'] + 16)
    return (sx, Y['shoulder'] + 6), (ex, Y['elbow']), (wx, Y['wrist'])


def leg_line(f, side):
    s = side
    hx = 100 + s * f['hip'] * 0.45
    kx = 100 + s * f['hip'] * 0.42
    ax = 100 + s * f['hip'] * 0.34
    return (hx, Y['crotch'] - 4), (kx, Y['knee']), (ax, Y['ankle'])


def silhouette(f):
    """The body outline the plates sit inside, drawn once per form."""
    parts = []
    parts.append(blob(100, Y['head'] - 6, 21, 25, 0.58))            # head
    parts.append(segment(100, Y['chin'], 11, 100, Y['neck'] + 4, 13, 4))
    parts.append(path([
        (100 - f['shoulder'], Y['shoulder']), (100 + f['shoulder'], Y['shoulder']),
        (100 + f['chest'], Y['chestLow']), (100 + f['waist'], Y['waist']),
        (100 + f['hip'], Y['hip']), (100 + f['hip'] * 0.86, Y['crotch']),
        (100 - f['hip'] * 0.86, Y['crotch']), (100 - f['hip'], Y['hip']),
        (100 - f['waist'], Y['waist']), (100 - f['chest'], Y['chestLow'])]))
    for s in (-1, 1):
        (sx, sy), (ex, ey), (wx, wy) = arm_line(f, s)
        parts.append(segment(sx, sy, f['arm'] + 1, ex, ey, f['arm'] - 2, 7))
        parts.append(segment(ex, ey, f['arm'] - 2, wx, wy, f['arm'] - 4, 6))
        (hx, hy), (kx, ky), (ax, ay) = leg_line(f, s)
        parts.append(segment(hx, hy, f['thigh'] + 1, kx, ky, f['thigh'] - 6, 8))
        parts.append(segment(kx, ky, f['thigh'] - 6, ax, ay, f['thigh'] - 11, 7))
        parts.append(blob(ax - s * 2, Y['foot'], 12, 8, 0.6))
    return ' '.join(parts)


def front(f):
    out = []
    add = lambda m, d: out.append({'m': m, 'd': d})                 # noqa: E731
    for s in (-1, 1):
        # traps run from the neck out to the shoulder line
        add('traps', path([
            (100 + s * 8, Y['neck'] - 2), (100 + s * (f['shoulder'] - 12), Y['shoulder'] + 2),
            (100 + s * (f['shoulder'] - 20), Y['shoulder'] + 12), (100 + s * 6, Y['neck'] + 14)]))
        add('shoulders', blob(100 + s * (f['shoulder'] - 12), Y['shoulder'] + 12,
                              15, 14, 0.62, s * 0.25))
        add('chest', blob(100 + s * (f['chest'] * 0.47), Y['chestTop'] + 17,
                          f['chest'] * 0.42, 18, 0.6, s * -0.12))
        add('obliques', blob(100 + s * (f['waist'] * 0.80), Y['waist'] - 14,
                             8, 26, 0.6, s * 0.05))
        (sx, sy), (ex, ey), (wx, wy) = arm_line(f, s)
        add('biceps', segment(sx + s * 1, sy + 12, f['arm'] - 2,
                              ex, ey - 6, f['arm'] - 4, 6))
        add('forearms', segment(ex, ey + 2, f['arm'] - 3, wx, wy - 4, f['arm'] - 5, 5))
        (hx, hy), (kx, ky), (ax, ay) = leg_line(f, s)
        add('quads', segment(hx, hy + 8, f['thigh'] - 3, kx, ky - 18, f['thigh'] - 9, 8))
        add('calves', segment(kx, ky + 14, f['thigh'] - 9, ax, ay - 22, f['thigh'] - 14, 7))
    # abs: one column of four rows, so it reads as a stack rather than a slab
    for i in range(4):
        y = Y['chestLow'] + 4 + i * 13
        add('abs', blob(100, y, f['waist'] * 0.52, 6.5, 0.7))
    return out


def back(f):
    out = []
    add = lambda m, d: out.append({'m': m, 'd': d})                 # noqa: E731
    # the traps stop where the lats start, or the biggest muscle on the back
    # ends up drawn as a sliver underneath the smallest
    add('traps', path([
        (100, Y['neck'] - 4), (100 + f['shoulder'] - 16, Y['shoulder'] + 6),
        (100 + 9, Y['chestTop'] + 26), (100, Y['chestTop'] + 32),
        (100 - 9, Y['chestTop'] + 26), (100 - (f['shoulder'] - 16), Y['shoulder'] + 6)]))
    for s in (-1, 1):
        add('shoulders', blob(100 + s * (f['shoulder'] - 12), Y['shoulder'] + 12,
                              15, 14, 0.62, s * 0.25))
        add('lats', path([
            (100 + s * 10, Y['chestTop'] + 20), (100 + s * (f['chest'] + 1), Y['chestTop'] + 26),
            (100 + s * (f['waist'] + 1), Y['waist'] - 12), (100 + s * 6, Y['waist'] - 4),
            (100 + s * 6, Y['chestLow'] - 22)]))
        (sx, sy), (ex, ey), (wx, wy) = arm_line(f, s)
        add('triceps', segment(sx + s * 1, sy + 12, f['arm'] - 2,
                               ex, ey - 6, f['arm'] - 4, 6))
        add('forearms', segment(ex, ey + 2, f['arm'] - 3, wx, wy - 4, f['arm'] - 5, 5))
        add('glutes', blob(100 + s * (f['hip'] * 0.46), Y['hip'] + 6,
                           f['hip'] * 0.46, 18, 0.62, s * -0.1))
        (hx, hy), (kx, ky), (ax, ay) = leg_line(f, s)
        add('hamstrings', segment(hx, hy + 10, f['thigh'] - 3, kx, ky - 18, f['thigh'] - 9, 8))
        add('calves', segment(kx, ky + 12, f['thigh'] - 9, ax, ay - 22, f['thigh'] - 14, 7))
    # the erectors, either side of the spine
    for s in (-1, 1):
        add('lowerback', blob(100 + s * 7, Y['waist'] + 10, 7.5, 17, 0.62))
    return out


def main():
    body = {}
    for name, f in FORMS.items():
        body[name] = {'outline': silhouette(f),
                      'front': front(f), 'back': back(f)}

    # Every region has to be somewhere, on the side it says it is on, or a
    # number in the list would point at nothing on the figure.
    for name, v in body.items():
        for view in ('front', 'back'):
            drawn = {p['m'] for p in v[view]}
            want = {m for m in MUSCLE_ORDER
                    if MUSCLE_VIEW[m] in (view, 'both')}
            assert drawn == want, (name, view, sorted(want ^ drawn))

    js = ('  /* BODY BEGIN */\n'
          '  /* GENERATED by tools/build_body.py — do not edit by hand.\n'
          '     An artist\'s mannequin: one rounded plate per region, three\n'
          '     silhouettes that differ only in width. `m` is the muscle key,\n'
          '     `d` the path. */\n'
          '  var BODY_BOX = [%g, %g];\n' % (W, H)
          + '  var BODY = ' + json.dumps(body, separators=(',', ':')) + ';\n'
          + '  /* BODY END */')

    app = os.path.join(ROOT, 'app.js')
    text = open(app, encoding='utf-8').read()
    if '/* BODY BEGIN */' in text:
        a = text.index('  /* BODY BEGIN */')
        b = text.index('/* BODY END */', a) + len('/* BODY END */')
        out = text[:a] + js + text[b:]
    else:
        mark = '  /* BANK BEGIN */'
        out = text.replace(mark, js + '\n' + mark, 1)
    if out != text:
        open(app, 'w', encoding='utf-8').write(out)
        print('spliced app.js')
    else:
        print('app.js already up to date')
    print('%d forms, %d + %d plates each'
          % (len(FORMS), len(body['neutral']['front']), len(body['neutral']['back'])))


if __name__ == '__main__':
    main()
