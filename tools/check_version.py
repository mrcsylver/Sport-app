#!/usr/bin/env python3
"""Assert the version agrees everywhere it has to.

Four places carry it and they are not near each other. When they disagree the
symptom is not an error, it is a phone quietly running last week's release —
which is exactly what happened once, and cost an evening finding out that the
database was fine all along.

    python3 tools/check_version.py

Run tools/bump_version.py to change it; this only checks.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = ['styles.css', 'vendor/supabase.js', 'vendor/game-icons.js', 'app.js']


def read(p):
    return open(os.path.join(ROOT, p), encoding='utf-8').read()


def main():
    found, bad = {}, []
    found['app.js APP_VERSION'] = re.search(
        r"var APP_VERSION = '([^']*)'", read('app.js')).group(1)
    sw = read('sw.js')
    found['sw.js VERSION'] = re.search(r"var VERSION = '([^']*)'", sw).group(1)
    found['sw.js CACHE'] = re.search(
        r"var CACHE = 'ironleague-v([^']*)'", sw).group(1)

    html = read('index.html')
    for a in ASSETS:
        m = re.search(r'\./%s\?v=([0-9.]+)' % re.escape(a), html)
        if not m:
            bad.append('index.html pulls ./%s with no ?v= — it will be served '
                       'from the old cache' % a)
        else:
            found['index.html %s' % a] = m.group(1)

    proj = read('ios/project.yml')
    ios = re.search(r'MARKETING_VERSION: "([^"]*)"', proj).group(1)

    versions = set(found.values())
    if len(versions) > 1:
        for k, v in sorted(found.items()):
            bad.append('%-28s %s' % (k, v))
        bad.insert(0, 'these do not agree:')
    v = sorted(versions)[-1]
    if not v.startswith(ios + '.'):
        bad.append('ios MARKETING_VERSION is %s, the app is %s' % (ios, v))

    if bad:
        print('version check FAILED')
        for line in bad:
            print('  ' + line)
        sys.exit(1)
    print('version %s · app.js, sw.js, %d assets in index.html, ios %s'
          % (v, len(ASSETS), ios))


if __name__ == '__main__':
    main()
