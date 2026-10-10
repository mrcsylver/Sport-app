#!/usr/bin/env python3
"""Regenerate the shop catalogue — the SQL seed and the browser mock's copy.

    python3 tools/build_shop.py

The catalogue is the list the server validates against. Every cosmetic the app
can draw has to be a row in it, because `set_banner`, `set_avatar`,
`set_name_color` and `set_league_badge` now refuse anything that is not — and a
key missing from the seed is somebody's banner refusing to save.

So it is read straight out of the arrays the client already uses, rather than
typed twice:

    app.js                PLAYER_SKINS, LEAGUE_SKINS, NAME_COLORS,
                          AV_COLORS, BADGE_SHAPES, BADGE_COLORS
    vendor/game-icons.js  GI_AVATARS (player emblems), GI_CRESTS (league marks)

Every row it writes is free. Price and uploaded artwork are per-row columns an
admin sets later from the control room; this file only guarantees that what
shipped stays wearable.

It writes the same list into tools/test/mock-supabase.js, because the app now
draws every shelf FROM the catalogue rather than from its own arrays: a mock
that is short of a row is a cosmetic the browser tests cannot pick.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = (ROOT / 'app.js').read_text(encoding='utf-8')
GI = (ROOT / 'vendor' / 'game-icons.js').read_text(encoding='utf-8')

BEGIN = '-- SHOP BEGIN'
END = '-- SHOP END'


def array_of(src, name):
    """The literal of `var NAME = [ ... ];`, brackets included."""
    m = re.search(r'var\s+' + name + r'\s*=\s*\[', src)
    if not m:
        raise SystemExit('cannot find ' + name)
    i = m.end() - 1
    depth = 0
    for j in range(i, len(src)):
        if src[j] == '[':
            depth += 1
        elif src[j] == ']':
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    raise SystemExit('unterminated ' + name)


def keyed(src, name):
    """[{key, name}] out of a JS array of object literals, in source order."""
    body = array_of(src, name)
    out = []
    for key, label in re.findall(
            r"key:\s*'([^']*)'\s*,\s*name:\s*'([^']*)'", body):
        out.append((key, label))
    if not out:
        raise SystemExit(name + ' parsed to nothing')
    return out


def strings(src, name):
    """A flat JS array of strings."""
    return json.loads(array_of(src, name).replace("'", '"'))


def titled(key):
    return key.replace('-', ' ').upper()


def rows():
    out = []

    # Player emblems and league crest marks are two separate sets on purpose:
    # a league is a place and a player is a person.
    for i, k in enumerate(strings(GI, 'GI_AVATARS')):
        out.append(('emblem', k, titled(k), i))
    for i, k in enumerate(strings(GI, 'GI_CRESTS')):
        out.append(('crest', k, titled(k), i))

    for i, (k, label) in enumerate(keyed(APP, 'PLAYER_SKINS')):
        out.append(('player_banner', k, label, i))
    for i, (k, label) in enumerate(keyed(APP, 'LEAGUE_SKINS')):
        out.append(('league_banner', k, label, i))

    # The empty key is "no colour chosen", which every setter allows without
    # asking the catalogue, so it is not an item.
    for i, (k, label) in enumerate(keyed(APP, 'NAME_COLORS')):
        if k:
            out.append(('name_color', k, label, i))
    for i, (k, label) in enumerate(keyed(APP, 'AV_COLORS')):
        out.append(('avatar_tint', k, label, i))

    for i, k in enumerate(strings(APP, 'BADGE_SHAPES')):
        out.append(('shape', k, k.upper(), i))
    # BADGE_COLORS carries a/b hexes rather than a name.
    metals = re.findall(r"key:\s*'([^']*)'\s*,\s*a:", array_of(APP, 'BADGE_COLORS'))
    for i, k in enumerate(metals):
        out.append(('metal', k, k.upper(), i))

    return out


def main():
    all_rows = rows()

    # One primary key across every kind, so a shape called `gold` and a metal
    # called `gold` cannot collide. The kind is the prefix.
    seen = set()
    seed = []
    for kind, key, name, sort in all_rows:
        pk = kind + ':' + key
        if pk in seen:
            raise SystemExit('duplicate ' + pk)
        seen.add(pk)
        seed.append([pk, kind, key, name, sort])

    sql = [
        BEGIN,
        'insert into public.shop_items (key,kind,item,name,sort)',
        'select r->>0, r->>1, r->>2, r->>3, (r->>4)::int',
        'from jsonb_array_elements($j$' +
        json.dumps(seed, separators=(',', ':'), ensure_ascii=False) + '$j$::jsonb) r',
        'on conflict (key) do update set',
        '  kind = excluded.kind, item = excluded.item,',
        '  name = excluded.name, sort = excluded.sort;',
        END,
    ]
    block = '\n'.join(sql)

    p = ROOT / 'supabase' / 'schema.sql'
    s = p.read_text(encoding='utf-8')
    if BEGIN not in s or END not in s:
        raise SystemExit('schema.sql has no SHOP BEGIN/END block')
    s = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END), lambda _: block,
               s, flags=re.S)
    p.write_text(s, encoding='utf-8')

    mock = ['  /* SHOP BEGIN */',
            '  DB.shop = DB.shop || ' + json.dumps(
                [{'key': k, 'kind': kind, 'item': item, 'name': name,
                  'price_cents': None, 'sort': sort}
                 for k, kind, item, name, sort in seed],
                separators=(',', ':'), ensure_ascii=False) + ';',
            '  /* SHOP END */']
    p = ROOT / 'tools' / 'test' / 'mock-supabase.js'
    s = p.read_text(encoding='utf-8')
    if '/* SHOP BEGIN */' not in s:
        raise SystemExit('the mock has no SHOP BEGIN/END block')
    s = re.sub(r'  /\* SHOP BEGIN \*/.*?  /\* SHOP END \*/',
               lambda _: '\n'.join(mock), s, flags=re.S)
    p.write_text(s, encoding='utf-8')

    by_kind = {}
    for _, kind, _, _, _ in seed:
        by_kind[kind] = by_kind.get(kind, 0) + 1
    print(str(len(seed)) + ' items · ' +
          ', '.join(k + ' ' + str(n) for k, n in sorted(by_kind.items())))


if __name__ == '__main__':
    main()
