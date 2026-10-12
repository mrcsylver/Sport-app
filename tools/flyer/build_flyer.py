#!/usr/bin/env python3
"""A printable flyer for one league, built from the app's own front end.

    /usr/bin/python3 tools/flyer/build_flyer.py 843651
    /usr/bin/python3 tools/flyer/build_flyer.py 843651 --paper a4
    /usr/bin/python3 tools/flyer/build_flyer.py 843651 --insta ironleague.campus

Writes PNGs at 300 dpi into tools/flyer/out/: a dark one, which is the app,
and a light one for a library printer.

PAPER. US Letter by default, because that is what the printer this gets sent
to holds. A4 is 8.27in x 11.69in and Letter is 8.5in x 11in — the sheet is
wider and two thirds of an inch shorter, so an A4 poster on a Letter printer
comes back with its head and its feet cut off, which is what happened. The
poster is laid out once and scaled to the sheet, so both come out as the
same design and neither is stretched.

WHY A BROWSER AND NOT PILLOW. The first version drew the page in Python with
DejaVu, which is nobody's brand. This one loads styles.css, the real Barlow
Condensed woff2 and the vendored game-icons, so a poster on a wall and the
screen somebody lands on afterwards are plainly the same thing. Nothing on
it is a lookalike.

WHAT IT IS FOR. A poster has about two seconds. Everything on it is the
hook, the QR code, or deleted: no feature list, no points system, no
app-store badge -- there is no app to store, and saying so is worth more
than any feature.

The QR goes STRAIGHT INTO THE LEAGUE rather than to the home page. Scanning
the bare link leaves a stranger having to ask somebody for a code, and they
will not.

WHY THERE IS A LIGHT VERSION. The dark one is the app and looks like it. It
is also a full sheet at 95% coverage, which on a shared campus printer is
slow, expensive and streaked. The light one costs almost nothing and scans
exactly as well -- a QR needs contrast, and black on white is the most
contrast there is.
"""
import argparse
import http.server
import json
import os
import socketserver
import subprocess
import threading

import segno

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")
SITE = "https://mrcsylver.github.io/Sport-app/"
PORT = 4537

# CSS pixels at 96 to the inch; the shot is taken at 3x, so each of these
# comes out at 300 dpi. The suffix is what the file is called, and Letter —
# the default — carries no suffix, because it is the one being printed.
PAPERS = {
    "letter": {"w": 850, "h": 1100, "cls": "letter", "suffix": ""},
    "a4": {"w": 827, "h": 1169, "cls": "", "suffix": "-a4"},
}

# game-icons.net, CC BY 3.0, the same four files the app draws avatars from.
# muscle-up is somebody at the top of a pull-up; the football is drawn below,
# because the set has no American one.
BG_ICONS = ["muscle-up", "soccer-ball", "__FOOTBALL__", "weight-lifting-up"]

# An American football, drawn rather than borrowed: a pointed ellipse with a
# seam and five laces, in the same 512 viewBox and the same currentColor fill
# as every other icon here, so it sits in the set rather than beside it.
FOOTBALL = (
    # An American football, drawn rather than borrowed: the set has no such
    # icon. A pointed oval — two arcs meeting at a point — with the seam, the
    # laces and the two end stripes punched out of it as holes, so the whole
    # thing is one currentColor path like every other icon here.
    '<path fill-rule="evenodd" d="'
    'M48 256C120 136 392 136 464 256 392 376 120 376 48 256Z '
    'M186 249h140v16H186z '
    'M202 228h13v58h-13z M232 224h13v66h-13z M262 224h13v66h-13z '
    'M292 228h13v58h-13z '
    'M112 206h15v100h-15z M385 206h15v100h-15z'
    '"/>'
)


def icons():
    """The icon bodies, straight out of the vendored file."""
    out = subprocess.run(
        ["node", "-e", """
        global.window = {};
        var fs = require('fs');
        eval(fs.readFileSync(process.argv[1], 'utf8'));
        var all = {};
        [typeof GI_ICONS !== 'undefined' && GI_ICONS,
         typeof GI_CRESTS !== 'undefined' && GI_CRESTS,
         typeof GI_BADGE_ART !== 'undefined' && GI_BADGE_ART,
         typeof GI_CAT !== 'undefined' && GI_CAT].forEach(function (set) {
          if (set) Object.keys(set).forEach(function (k) { all[k] = set[k]; });
        });
        process.stdout.write(JSON.stringify(all));
        """, os.path.join(ROOT, "vendor", "game-icons.js")],
        capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def qr_svg(url, px=380):
    """An SVG QR, so the printer rasterises it at its own resolution rather
    than scaling somebody else's pixels. A QR with soft edges is a QR a phone
    gives up on, and a corridor at arm's length is exactly that case."""
    qr = segno.make(url, error="h")
    m = [[bool(c) for c in row] for row in qr.matrix]
    n = len(m) + 4
    unit = px / n
    rects = []
    for r, row in enumerate(m):
        for c, on in enumerate(row):
            if on:
                rects.append('<rect x="%.4f" y="%.4f" width="%.4f" height="%.4f"/>'
                             % ((c + 2) * unit, (r + 2) * unit, unit, unit))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" '
            'shape-rendering="crispEdges"><rect width="%d" height="%d" fill="#fff"/>'
            '<g fill="#000">%s</g></svg>' % (px, px, px, px, "".join(rects)))


def page(code, light, insta, paper):
    art = icons()
    tmpl = open(os.path.join(HERE, "flyer.html"), encoding="utf-8").read()
    svgs = []
    for i, key in enumerate(BG_ICONS, start=1):
        body = FOOTBALL if key == "__FOOTBALL__" else art[key]
        svgs.append('<svg class="i%d" viewBox="0 0 512 512">%s</svg>' % (i, body))
    social = ('<div class="c">@%s</div>' % insta) if insta else ""
    classes = " ".join(c for c in ["light" if light else "", paper["cls"]] if c)
    return (tmpl
            .replace("__THEME__", classes)
            .replace("__BGICONS__", "".join(svgs))
            .replace("__QR__", qr_svg(SITE + "#/join/" + code))
            .replace("__CODE__", code)
            .replace("__SOCIAL__", social))


def serve():
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def translate_path(self, path):
            return os.path.join(ROOT, path.lstrip("/").split("?")[0])

    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("127.0.0.1", PORT), Quiet)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def shoot(code, light, insta, paper):
    tail = "%s%s" % (paper["suffix"], "-light" if light else "")
    path = os.path.join(OUT, "flyer-%s%s.png" % (code, tail))
    tmp = os.path.join(HERE, "_page%s.html" % tail)
    open(tmp, "w", encoding="utf-8").write(page(code, light, insta, paper))
    subprocess.run(["node", os.path.join(HERE, "shoot.js"),
                    "http://127.0.0.1:%d/tools/flyer/%s" % (PORT, os.path.basename(tmp)),
                    path, str(paper["w"]), str(paper["h"])], check=True)
    os.remove(tmp)
    print("wrote %s  (%d x %d)" % (os.path.relpath(path, ROOT),
                                   paper["w"] * 3, paper["h"] * 3))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("code", nargs="?", default="843651")
    ap.add_argument("--insta", default="", help="instagram handle, without the @")
    ap.add_argument("--paper", default="letter",
                    choices=["letter", "a4", "both"],
                    help="sheet to lay it out on (default: letter)")
    args = ap.parse_args()

    want = ["letter", "a4"] if args.paper == "both" else [args.paper]

    os.makedirs(OUT, exist_ok=True)
    httpd = serve()
    try:
        for name in want:
            shoot(args.code, False, args.insta, PAPERS[name])
            shoot(args.code, True, args.insta, PAPERS[name])
    finally:
        httpd.shutdown()
        httpd.server_close()
    print("  -> " + SITE + "#/join/" + args.code)


if __name__ == "__main__":
    main()
