#!/usr/bin/env python3
"""Regenerate the exercise table in app.js and the SQL seed from exercise_bank.py.

    python3 tools/build_exercises.py

Never hand-edit the generated blocks: the client table and calc_points() must
agree exactly, or the preview a user sees would differ from the points the
server actually awards.
"""
import json, re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from exercise_bank import *                                    # noqa: F403

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAT_ORDER = ['PUSH', 'PULL', 'LEGS', 'CORE', 'CARDIO', 'SPORT', 'GYM', 'RECOVERY']

VARIANTS = {
    'pushups':   'Any hand position. Wide, diamond and decline have their own entries.',
    'dips':      'Parallel bars, rings or between two chairs',
    'handstand': 'Against a wall, freestanding, or hanging from a bar',
    'pullups':   'Overhand grip. Kipping counts, but be honest.',
    'muscleup':  'Bar or rings. The human flag scores here too.',
    'stretch':   'At least 10 minutes of stretching, mobility or yoga',
    'sprints':   'One sprint = 15 sec flat out, 100 m minimum',
    'run':       'Outdoor or treadmill',
    'swim':      'Any stroke, active swim time',
    'walk':      'Hiking counts too',
    'bike':      'Road, trail or stationary',
}
ex = {}   # key -> record

def put(key, name, cat, mode, rate, aliases, variants=None, sort=100):
    r = ex.setdefault(key, {'key': key, 'name': name, 'cat': cat, 'aliases': aliases,
                            'variants': variants or VARIANTS.get(key, ''), 'sort': sort,
                            'modes': {}})
    r['modes'][mode] = {'rate': round(float(rate), 6)}
    return r

def calis(rows, k, cat):
    for i, (key, name, L, prem, al) in enumerate(rows):
        rate = ANCHOR[key] if key in ANCHOR else q(k * L * prem)
        if key in ANCHOR and L is not None:      # model must reproduce the anchor
            model = q(k * L * prem)
            assert abs(model - ANCHOR[key]) < 0.26, (key, model, ANCHOR[key])
        put(key, name, cat, 'reps', rate, al, sort=i)

calis(PUSH, K_PUSH, 'PUSH')
calis(PULL, K_PULL, 'PULL')
calis(LEGS, K_LEGS, 'LEGS')

for i, (key, name, rate, al) in enumerate(CORE_REPS):
    put(key, name, 'CORE', 'reps', ANCHOR.get(key, rate), al, sort=i)
for i, (key, name, cat, mode, rate, al) in enumerate(CORE_HOLD):
    put(key, name, cat, mode, rate, al, sort=50 + i)
for i, (key, name, mode, rate, al, var) in enumerate(CARDIO):
    put(key, name, 'CARDIO', mode, rate, al, var, sort=i)
for i, (key, name, rate, al) in enumerate(SPORTS):
    put(key, name, 'SPORT', 'minutes', rate, al, 'Actual playing time, not time at the venue', i)
for i, (key, name, rate, al) in enumerate(RECOVERY):
    put(key, name, 'RECOVERY', 'flat', rate, al, sort=i)

# Gym carries k + equipment instead of a flat rate; points need bodyweight.
for i, (key, name, pat, equip, al) in enumerate(GYM):
    r = ex.setdefault(key, {'key': key, 'name': name, 'cat': 'GYM', 'aliases': al,
                            'variants': 'Enter the weight on the bar, not counting your own',
                            'sort': i, 'modes': {}})
    r['modes']['reps'] = {'k': round(K_GYM[pat], 6), 'equip': equip,
                          'legs': pat == 'legs', 'pattern': 'legs' if pat.startswith('legs') else pat}

# handstand and muscle-up keep their second unit from the original table.
put('handstand', 'Handstand Push-up', 'PUSH', 'seconds', 1/5, 'hspu wall hold invert')
put('muscleup', 'Muscle-up / Flag', 'PULL', 'seconds', 2, 'muscleup flag humanflag hold')

# Every key+mode a bounty relies on must still exist, or quests break silently.
REQUIRED = [('pushups','reps'),('dips','reps'),('handstand','seconds'),('handstand','reps'),
            ('pullups','reps'),('rows','reps'),('airsquats','reps'),('pistols','reps'),
            ('plank','minutes'),('kneeraises','reps'),('lsit','seconds'),('twists','reps'),
            ('run','km'),('bike','km'),('sprints','reps'),('walk','km'),('swim','minutes'),
            ('stretch','flat'),('muscleup','reps'),('muscleup','seconds'),('calves','reps')]
for k, m in REQUIRED:
    assert k in ex and m in ex[k]['modes'], f'bounties reference {k}/{m} — missing'
for k, v in ANCHOR.items():
    got = ex[k]['modes'].get('reps', {}).get('rate')
    assert got == v, f'anchor {k} drifted: {got} != {v}'

rows = sorted(ex.values(), key=lambda r: (CAT_ORDER.index(r['cat']), r['sort'], r['name']))
print(f'{len(rows)} exercises', {c: sum(1 for r in rows if r["cat"] == c) for c in CAT_ORDER})
json.dump(rows, open(ROOT / 'tools' / 'exercises.json', 'w'), indent=1)

# ------------------------------------------------------------ emit client --
def jsstr(s):
    return "'" + str(s).replace('\\', '\\\\').replace("'", "\\'") + "'"

def jsmodes(m):
    out = []
    for mode, d in m.items():
        if 'rate' in d:
            r = d['rate']
            rs = repr(round(r, 6)) if abs(r - round(r, 4)) < 1e-9 else repr(r)
            out.append(f'{mode}:{rs}')
        else:
            out.append(f'{mode}:{{k:{d["k"]},equip:{d["equip"]},'
                       f'legs:{"true" if d["legs"] else "false"}}}')
    return '{' + ','.join(out) + '}'

lines = []
for r in rows:
    lines.append('  [%s,%s,%s,%s,%s,%s]' % (
        jsstr(r['key']), jsstr(r['name']), jsstr(r['cat']),
        jsstr(r['aliases']), jsstr(r['variants']), jsmodes(r['modes'])))
client = ('  /* GENERATED by tools/build_exercises.py — do not edit by hand.\n'
          '     [key, name, category, search aliases, note, modes]\n'
          '     A number is points per unit; an object is a gym lift priced from\n'
          '     bodyweight and load. Mirrors public.exercises in the database. */\n'
          '  var EX_BANK = [\n' + ',\n'.join(lines) + '\n  ];\n')
(ROOT / 'tools' / 'ex_bank.js.txt').write_text(client)

# --------------------------------------------------------------- emit SQL --
def sqlstr(s):
    return "'" + str(s).replace("'", "''") + "'"

vals = []
for i, r in enumerate(rows):
    vals.append('  (%s,%s,%s,%s,%s,%d,%s)' % (
        sqlstr(r['key']), sqlstr(r['name']), sqlstr(r['cat']),
        sqlstr(r['variants']), sqlstr(r['aliases']), i,
        sqlstr(json.dumps(r['modes'], separators=(',', ':'))) + '::jsonb'))
sql = ('insert into public.exercises (key, name, cat, variants, aliases, sort, modes) values\n'
       + ',\n'.join(vals) + '\non conflict (key) do update set\n'
       '  name = excluded.name, cat = excluded.cat, variants = excluded.variants,\n'
       '  aliases = excluded.aliases, sort = excluded.sort, modes = excluded.modes;\n')
(ROOT / 'tools' / 'exercises.sql').write_text(sql)
print('wrote tools/ex_bank.js.txt and tools/exercises.sql')
