#!/usr/bin/env python3
"""A 25-second silent clip explaining the app, built from the app itself.

    /usr/bin/python3 tools/promo/build_video.py

Writes tools/promo/out/iron-league-25s.mp4 — 1080x1920, H.264, no audio.

WHY NOT A SCREEN RECORDING. A recording of the real app would need a real
account, real data and a steady hand, and it would have to be redone every
time the UI moves. This draws the app's own screens from its own stylesheet,
font and icons, so it is the same product people land on and it rebuilds with
one command.

WHY NOT A CSS ANIMATION, RECORDED. Because then the clip is a function of how
long each screenshot took. promo.html exposes draw(t) and nothing else: the
capture script sets a time, takes a picture, steps. 750 frames, identical
every run.

WHY SILENT, WITH THE WORDS BURNT IN. It autoplays muted on a phone, and it
will be watched in a gym. Anything said out loud would be said to nobody.

WHY 9:16. It is for a phone and for Instagram, not for a laptop.
"""
import argparse
import http.server
import json
import os
import shutil
import socketserver
import subprocess
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")
FRAMES = os.path.join(HERE, "_frames")
PORT = 4541
FPS = 30
W, H = 540, 960          # CSS px; shot at 2x -> 1080x1920

# The same vendored game-icons the app draws avatars from, so a face in the
# clip is a face in the app.
WANT = {
    "__I_PULL__": "muscle-up",
    "__I_PUSH__": "chest",
    "__I_RUN__": "run",
    "__I_MUSCLE__": "muscle-up",
}


def icons():
    """Icon bodies straight out of the vendored file."""
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


def page():
    art = icons()
    tmpl = open(os.path.join(HERE, "promo.html"), encoding="utf-8").read()
    for token, key in WANT.items():
        body = art.get(key) or next(iter(art.values()))
        tmpl = tmpl.replace(
            token, '<svg viewBox="0 0 512 512">%s</svg>' % body)
    return tmpl


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=int, default=FPS)
    ap.add_argument("--keep-frames", action="store_true")
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    shutil.rmtree(FRAMES, ignore_errors=True)
    os.makedirs(FRAMES)

    tmp = os.path.join(HERE, "_page.html")
    open(tmp, "w", encoding="utf-8").write(page())
    httpd = serve()
    try:
        subprocess.run(
            ["node", os.path.join(HERE, "shoot_frames.js"),
             "http://127.0.0.1:%d/tools/promo/_page.html" % PORT,
             FRAMES, str(args.fps), str(W), str(H)], check=True)
    finally:
        httpd.shutdown()
        httpd.server_close()
        os.remove(tmp)

    mp4 = os.path.join(OUT, "iron-league-25s.mp4")
    # yuv420p and the even-dimension filter are what make this play on phones
    # at all; without them Safari and half of Android show a black rectangle.
    # faststart puts the index at the front so it begins before it has fully
    # downloaded, which on a landing page is the whole difference.
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-framerate", str(args.fps), "-i", os.path.join(FRAMES, "f%05d.png"),
        "-c:v", "libx264", "-preset", "slow", "-crf", "23",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
        "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
        "-an", mp4], check=True)

    if not args.keep_frames:
        shutil.rmtree(FRAMES, ignore_errors=True)

    size = os.path.getsize(mp4)
    print("wrote %s  (%.1f MB)" % (os.path.relpath(mp4, ROOT), size / 1e6))


if __name__ == "__main__":
    main()
