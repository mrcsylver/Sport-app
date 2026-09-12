#!/usr/bin/env python3
"""Set the app version everywhere it has to agree, in one go.

Four places have to move together or a phone will not pick up a release:

  app.js       APP_VERSION, which is what the footer shows
  index.html   the ?v= on every asset it pulls, which is the cache key
  sw.js        CACHE, and the same ?v= inside the shell list
  ios/         the build number

The ?v= is the part that actually matters. A service worker caches by URL, so
bumping only its CACHE name relies on the worker updating and re-fetching
cleanly — and it does not always, because its install fetches through the
browser's own HTTP cache and can refill the new bucket with the old bytes.
Changing the URL sidesteps all of that: index.html is served network-first, a
fresh index.html asks for app.js?v=2.13.1, and nothing has that cached.

Usage:  python3 tools/bump_version.py 2.13.1
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = ['styles.css', 'vendor/supabase.js', 'vendor/game-icons.js', 'app.js']


def read(p):
    return open(os.path.join(ROOT, p), encoding='utf-8').read()


def write(p, s):
    open(os.path.join(ROOT, p), 'w', encoding='utf-8').write(s)


def main():
    if len(sys.argv) != 2 or not re.match(r'^\d+\.\d+\.\d+$', sys.argv[1]):
        raise SystemExit('usage: python3 tools/bump_version.py 2.13.1')
    v = sys.argv[1]

    app = read('app.js')
    app = re.sub(r"var APP_VERSION = '[^']*';", "var APP_VERSION = '%s';" % v, app, 1)
    write('app.js', app)

    html = read('index.html')
    for a in ASSETS:
        html = re.sub(r'(["\'])\./%s(\?v=[^"\']*)?\1'
                      % re.escape(a), r'\g<1>./%s?v=%s\g<1>' % (a, v), html)
    write('index.html', html)

    sw = read('sw.js')
    sw = re.sub(r"var CACHE = '[^']*';", "var CACHE = 'ironleague-v%s';" % v, sw, 1)
    sw = re.sub(r"var VERSION = '[^']*';", "var VERSION = '%s';" % v, sw, 1)
    write('sw.js', sw)

    proj = read('ios/project.yml')
    proj = re.sub(r'MARKETING_VERSION: "[^"]*"',
                  'MARKETING_VERSION: "%s"' % '.'.join(v.split('.')[:2]), proj, 1)
    n = int(re.search(r'CURRENT_PROJECT_VERSION: "(\d+)"', proj).group(1)) + 1
    proj = re.sub(r'CURRENT_PROJECT_VERSION: "\d+"',
                  'CURRENT_PROJECT_VERSION: "%d"' % n, proj, 1)
    write('ios/project.yml', proj)

    print('%s · app.js, index.html (%d assets), sw.js, ios build %d'
          % (v, len(ASSETS), n))


if __name__ == '__main__':
    main()
