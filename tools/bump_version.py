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

A VERSION NUMBER IS PUBLISHED ONCE AND NEVER REUSED, and this refuses to
reuse one. That is not tidiness. 2.37.0 went out twice with different code in
it -- a revert took the bump back down with everything else, and the next
commit bumped to the same number again -- and the second one could not reach
a single phone that had seen the first. Every mechanism that is supposed to
deliver an update keys on this string:

  * sw.js was byte-identical, so no browser ever saw a new worker to install
  * CACHE was still `ironleague-v2.37.0`, so activate deleted nothing
  * app.js?v=2.37.0 was already in that cache, and the fetch handler is
    cache-first, so it answered from it forever

Three independent safety nets, all keyed on the same string, all defeated at
once. The app had no way back: nothing short of clearing site data would have
fixed it. Hence the check below, which reads git rather than trusting anyone
to remember.

Usage:  python3 tools/bump_version.py 2.13.1
        python3 tools/bump_version.py 2.13.1 --reuse   (escape hatch)
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = ['styles.css', 'vendor/supabase.js', 'vendor/game-icons.js',
          'captcha.js', 'app.js']


def read(p):
    return open(os.path.join(ROOT, p), encoding='utf-8').read()


def write(p, s):
    open(os.path.join(ROOT, p), 'w', encoding='utf-8').write(s)


def already_published(v):
    """Has this exact version ever been committed before?

    Asks git rather than a changelog, because git is the thing that is
    actually true. Any commit whose sw.js carried this version counts: it was
    pushed, Pages served it, and somebody's phone may hold it.
    """
    try:
        out = subprocess.run(
            ['git', 'log', '--all', '--format=%H %s', '-S', "var VERSION = '%s';" % v,
             '--', 'sw.js'],
            cwd=ROOT, capture_output=True, text=True, timeout=30)
    except Exception:
        return []                      # no git here; not a reason to stop
    if out.returncode != 0:
        return []
    return [l for l in out.stdout.strip().splitlines() if l]


def main():
    args = [a for a in sys.argv[1:] if a != '--reuse']
    reuse = '--reuse' in sys.argv
    if len(args) != 1 or not re.match(r'^\d+\.\d+\.\d+$', args[0]):
        raise SystemExit('usage: python3 tools/bump_version.py 2.13.1')
    v = args[0]

    seen = already_published(v)
    if seen and not reuse:
        raise SystemExit(
            'REFUSING: %s has been committed before, by:\n  %s\n\n'
            'Publishing a version number twice with different code in it does not\n'
            'reach anybody who saw the first one -- sw.js is byte-identical so no\n'
            'new worker installs, CACHE matches so nothing is purged, and the\n'
            'cache-first handler keeps answering ?v=%s from the old bytes.\n'
            'Pick the next number instead. (--reuse overrides, for a version\n'
            'that was never pushed.)' % (v, '\n  '.join(seen[:4]), v))

    app = read('app.js')
    app = re.sub(r"var APP_VERSION = '[^']*';", "var APP_VERSION = '%s';" % v, app, 1)
    write('app.js', app)

    html = read('index.html')
    for a in ASSETS:
        html = re.sub(r'(["\'])\./%s(\?v=[^"\']*)?\1'
                      % re.escape(a), r'\g<1>./%s?v=%s\g<1>' % (a, v), html)
    write('index.html', html)

    # admin.html pulls captcha.js too, and the service worker caches every
    # same-origin GET it sees for ever. Without a ?v= the control room keeps
    # whatever copy it first managed to fetch -- including a 404 from a
    # half-finished deploy, which is exactly how the gate "did not load".
    adm = read('admin.html')
    adm = re.sub(r'(["\'])\./captcha\.js(\?v=[^"\']*)?\1',
                 r'\g<1>./captcha.js?v=%s\g<1>' % v, adm)
    write('admin.html', adm)

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

    print('%s · app.js, index.html (%d assets), admin.html, sw.js, ios build %d'
          % (v, len(ASSETS), n))


if __name__ == '__main__':
    main()
