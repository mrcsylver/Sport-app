#!/usr/bin/env python3
"""A printable flyer for one league, in the app's own colours.

    /usr/bin/python3 tools/flyer/build_flyer.py 843651

Writes two A4 PNGs at 300 dpi into tools/flyer/out/: the dark one, which is
the app, and a light one for a library printer. Needs segno and Pillow,
which only the 3.13 interpreter in this container has -- hence the path.

WHAT IT IS FOR. A poster on a wall has about two seconds. Everything on it
is therefore the hook, the QR code, or deleted: no feature list, no points
system, no app-store badge -- there is no app to store, and saying so is
worth more than any feature. The one suspicion it has to beat is "another
thing to download".

The QR goes STRAIGHT INTO THE LEAGUE rather than to the home page. Scanning
the bare link leaves a stranger having to ask somebody for a code, and they
will not.

WHY THERE IS A LIGHT VERSION. The dark one is the app and looks like it. It
is also a sheet of A4 at 95% coverage, which on a shared campus printer is
slow, expensive, and comes out streaked. Twenty copies of the light one cost
almost nothing and scan exactly as well -- a QR only needs contrast, and
black on white is the most contrast there is.
"""
import os
import sys

import segno
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
SITE = "https://mrcsylver.github.io/Sport-app/"

DPI = 300
W, H = int(8.27 * DPI), int(11.69 * DPI)        # A4 portrait
FONTS = "/usr/share/fonts/truetype"

# the app's own palette, straight out of styles.css
DARK = dict(bg=(8, 9, 12), panel=(22, 25, 35), line=(42, 47, 55),
            txt=(238, 241, 246), muted=(139, 146, 158),
            red=(255, 46, 46), gold=(255, 201, 60), qr_bg=(255, 255, 255))
LIGHT = dict(bg=(255, 255, 255), panel=(244, 245, 247), line=(208, 212, 220),
             txt=(16, 18, 24), muted=(105, 112, 124),
             red=(214, 26, 26), gold=(140, 98, 0), qr_bg=(255, 255, 255))


def font(size, bold=True):
    for path in (f"{FONTS}/dejavu/DejaVuSans-Bold.ttf" if bold
                 else f"{FONTS}/dejavu/DejaVuSans.ttf",
                 f"{FONTS}/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def centre(d, y, text, f, fill):
    box = d.textbbox((0, 0), text, font=f)
    d.text(((W - box[2]) // 2, y), text, font=f, fill=fill)


def qr_image(url, target):
    """Drawn from the matrix, so a module is a whole number of pixels. A QR
    resampled to fit has soft edges, and a phone held at arm's length in a
    corridor is exactly the case where that stops scanning."""
    qr = segno.make(url, error="h")
    matrix = [[bool(c) for c in row] for row in qr.matrix]
    border = 2
    n = len(matrix) + border * 2
    module = max(1, target // n)
    px = module * n
    img = Image.new("RGB", (px, px), (255, 255, 255))
    d = ImageDraw.Draw(img)
    for r, row in enumerate(matrix):
        for c, on in enumerate(row):
            if on:
                x0, y0 = (c + border) * module, (r + border) * module
                d.rectangle([x0, y0, x0 + module - 1, y0 + module - 1], fill=(0, 0, 0))
    return img, px


def build(code, light=False):
    C = LIGHT if light else DARK
    url = SITE + "#/join/" + code
    img = Image.new("RGB", (W, H), C["bg"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 26], fill=C["red"])

    # --- the block is laid out from the middle out, so the sheet is not
    # --- top-heavy with a hand's width of nothing at the bottom
    y = 240
    centre(d, y, "IRON LEAGUE", font(54), C["red"])

    # "Highest pull-up score" was the first draft and it was wrong: it makes
    # a thing that scores 164 movements across gym, calisthenics, running and
    # sport look like a pull-up tracker, and the people it would put off are
    # exactly the ones already training something else. The question is about
    # the reader, it fits in two seconds, and it says nothing about what you
    # have to be good at.
    y = 470
    for line, colour in (("WHERE DO YOU RANK", C["txt"]),
                         ("ON CAMPUS?", C["red"])):
        centre(d, y, line, font(124), colour)
        y += 158

    y += 60
    centre(d, y, "Gym.  Calisthenics.  Running.  Sport.", font(58, False), C["txt"])
    y += 84
    centre(d, y, "Log it, score it, see where you land.", font(52, False), C["muted"])

    qr_img, qr_px = qr_image(url, 1420)
    pad = 64
    box_x = (W - qr_px - pad * 2) // 2
    box_y = y + 150
    d.rounded_rectangle([box_x, box_y, box_x + qr_px + pad * 2, box_y + qr_px + pad * 2],
                        radius=26, fill=C["qr_bg"],
                        outline=C["line"] if light else None, width=3)
    img.paste(qr_img, (box_x + pad, box_y + pad))

    y = box_y + qr_px + pad * 2 + 80
    centre(d, y, "SCAN TO JOIN", font(76), C["txt"])
    y += 106
    centre(d, y, "Nothing to download.  Free.  Twenty seconds.", font(46, False), C["muted"])

    # the way in for a phone that will not scan, which there is always one of
    y += 130
    d.rounded_rectangle([W // 2 - 780, y, W // 2 + 780, y + 172],
                        radius=16, outline=C["line"], width=4, fill=C["panel"])
    centre(d, y + 30, "or open  mrcsylver.github.io/Sport-app", font(44, False), C["muted"])
    centre(d, y + 90, "and enter code  " + code, font(54), C["gold"])

    # "Nothing to download" is the line that gets somebody to scan, and it is
    # also the line that makes them think it is a worse thing than an app.
    # Both are answered at once: there is nothing to install AND it still
    # ends up as an icon on the home screen.
    y += 236
    centre(d, y, "ADD TO HOME SCREEN AND IT IS AN APP, ICON AND ALL",
           font(40), C["txt"])
    y += 62
    centre(d, y, "NEW LEADERBOARD EVERY MONDAY", font(38), C["muted"])

    os.makedirs(OUT, exist_ok=True)
    name = "flyer-%s%s.png" % (code, "-light" if light else "")
    path = os.path.join(OUT, name)
    img.save(path, dpi=(DPI, DPI))
    print("wrote %s" % os.path.relpath(path, ROOT))
    return path


if __name__ == "__main__":
    code = sys.argv[1] if len(sys.argv) > 1 else "843651"
    build(code, light=False)
    build(code, light=True)
    print("  -> " + SITE + "#/join/" + code)
