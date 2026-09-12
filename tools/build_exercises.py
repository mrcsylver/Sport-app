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
for i, (key, name, cat, mode, per_hour, al) in enumerate(CORE_HOLD):
    # the table is written in points per hour of hold; the stored rate is per
    # whatever unit the hold is logged in
    put(key, name, cat, mode, per_hour / (60 if mode == 'minutes' else 3600),
        al, sort=50 + i)
for i, (key, name, mode, rate, al, var) in enumerate(CARDIO):
    put(key, name, 'CARDIO', mode, rate, al, var, sort=i)
for i, (key, name, rate, al) in enumerate(SPORTS):
    put(key, name, 'SPORT', 'minutes', rate, al, 'Actual playing time, not time at the venue', i)
for i, (key, name, rate, al) in enumerate(RECOVERY):
    put(key, name, 'RECOVERY', 'flat', rate, al, sort=i)

# Gym carries k + equipment instead of a flat rate; points need bodyweight.
for i, (key, name, pat, equip, al) in enumerate(GYM):
    note = ('One side at a time — type the weight of the single dumbbell'
            if key in ONE_ARM
            else 'Type the total on the bar, not counting your own weight')
    r = ex.setdefault(key, {'key': key, 'name': name, 'cat': 'GYM', 'aliases': al,
                            'variants': note, 'sort': i, 'modes': {}})
    r['modes']['reps'] = {'k': round(K_GYM[pat], 6), 'equip': equip,
                          'legs': pat == 'legs',
                          'pattern': 'legs' if pat.startswith('legs')
                                     else 'core' if pat == 'coreiso' else pat}

# handstand and muscle-up keep their second unit from the original table.
put('handstand', 'Handstand Push-up', 'PUSH', 'seconds', 1080/3600, 'hspu wall hold invert')
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

# ------------------------------------------------------------- muscles ----
# Every exercise must say what it trains, the regions must be real ones, and
# the shares must add up — a map that sums to 1.3 quietly inflates one body
# part on everybody's figure, and nothing about the drawing would look wrong.
missing = sorted(k for k in ex if k not in MUSCLES)
assert not missing, f'no muscle map for {missing}'
extra = sorted(k for k in MUSCLES if k not in ex)
assert not extra, f'muscle map names exercises that do not exist: {extra}'
for k, m in MUSCLES.items():
    bad = sorted(set(m) - set(MUSCLE_ORDER))
    assert not bad, f'{k}: {bad} is not a region'
    if not m:
        assert ex[k]['cat'] == 'RECOVERY', f'{k} trains nothing but is not recovery'
        continue
    tot = round(sum(m.values()), 6)
    assert abs(tot - 1) < 1e-6, f'{k}: shares add up to {tot}, not 1'
assert set(MUSCLE_ORDER) == set(MUSCLE_NAME) == set(MUSCLE_VIEW) == set(MUSCLE_TARGET)
# and no region may be one nobody trains, or it would sit grey on the figure
# for everybody, for ever
untrained = sorted(set(MUSCLE_ORDER) - {m for v in MUSCLES.values() for m in v})
assert not untrained, f'nothing in the bank trains {untrained}'
for r in ex.values():
    r['muscles'] = {m: MUSCLES[r['key']][m] for m in MUSCLE_ORDER
                    if m in MUSCLES[r['key']]}

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

def jsmuscles(m):
    return '{' + ','.join('%s:%s' % (k, repr(round(v, 4))) for k, v in m.items()) + '}'

lines = []
for r in rows:
    lines.append('  [%s,%s,%s,%s,%s,%s,%s]' % (
        jsstr(r['key']), jsstr(r['name']), jsstr(r['cat']),
        jsstr(r['aliases']), jsstr(r['variants']), jsmodes(r['modes']),
        jsmuscles(r['muscles'])))
client = ('  /* GENERATED by tools/build_exercises.py — do not edit by hand.\n'
          '     [key, name, category, search aliases, note, modes, muscles]\n'
          '     A number is points per unit; an object is a gym lift priced from\n'
          '     bodyweight and load. `muscles` is the share of the points each\n'
          '     region gets, adding to 1. Mirrors public.exercises. */\n'
          '  var EX_BANK = [\n' + ',\n'.join(lines) + '\n  ];\n'
          + '  var MUSCLE_META = ' + json.dumps(
                [{'key': m, 'name': MUSCLE_NAME[m], 'view': MUSCLE_VIEW[m],
                  'target': MUSCLE_TARGET[m]} for m in MUSCLE_ORDER],
                separators=(',', ':')) + ';\n')
(ROOT / 'tools' / 'ex_bank.js.txt').write_text(client)

# --------------------------------------------------------------- emit SQL --
# One array of rows, expanded by the seed, rather than a hundred and eighteen
# VALUES tuples: it keeps schema.sql readable and it is the shape already
# there, so a diff of this file is a diff of the data and nothing else.
def sqlstr(s):
    return "'" + str(s).replace("'", "''") + "'"


payload = json.dumps([[r['key'], r['name'], r['cat'], r['variants'], r['aliases'],
                       i, r['modes'], r['muscles']] for i, r in enumerate(rows)],
                     separators=(',', ':'))
sql = ('insert into public.exercises (key,name,cat,variants,aliases,sort,modes,muscles)\n'
       'select e->>0, e->>1, e->>2, e->>3, e->>4, (e->>5)::int, e->6, e->7\n'
       'from jsonb_array_elements($j$' + payload + '$j$::jsonb) as e\n'
       'on conflict (key) do update set\n'
       '  name = excluded.name, cat = excluded.cat, variants = excluded.variants,\n'
       '  aliases = excluded.aliases, sort = excluded.sort, modes = excluded.modes,\n'
       '  muscles = excluded.muscles;\n')

muscles_payload = json.dumps([[m, MUSCLE_NAME[m], MUSCLE_VIEW[m], MUSCLE_TARGET[m]]
                              for m in MUSCLE_ORDER], separators=(',', ':'))
sql += ('\ninsert into public.muscles (key,name,view,target)\n'
        'select m->>0, m->>1, m->>2, (m->>3)::int\n'
        'from jsonb_array_elements($j$' + muscles_payload + '$j$::jsonb) as m\n'
        'on conflict (key) do update set\n'
        '  name = excluded.name, view = excluded.view, target = excluded.target;\n')
(ROOT / 'tools' / 'exercises.sql').write_text(sql)


# ------------------------------------------------------------- splice in ---
# Both generated blocks used to be written to a file and pasted in by hand,
# which is a step that gets skipped: app.js and the database can then disagree
# about what a rep is worth, and the preview a person sees stops matching the
# points they are given. Running this script IS the update now.
def splice(path, begin, end, body):
    text = path.read_text()
    a = text.index(begin) + len(begin)
    b = text.index(end, a)
    out = text[:a] + body + text[b:]
    if out == text:
        return False
    path.write_text(out)
    return True


# The browser mock keeps its own little copy of the table so a test page can
# score without a server. It was hand-written and had already drifted — a
# plank was still two points a minute in it — which is the failure mode where
# a test passes on numbers nobody uses. It is generated now, from here.
def train_cat(r):
    if r['cat'] == 'GYM':
        return r['modes']['reps']['pattern'].upper()
    return 'CARDIO' if r['cat'] == 'SPORT' else r['cat']


mock = ('  /* BANK BEGIN */\n'
        '  /* GENERATED by tools/build_exercises.py — do not edit by hand.\n'
        '     The same rates, categories and muscle shares the server uses. A\n'
        '     mock that scores differently is a test that passes on a bug. */\n'
        '  var RATES = ' + json.dumps(
            {r['key']: {mo: d['rate'] for mo, d in r['modes'].items() if 'rate' in d}
             for r in rows if any('rate' in d for d in r['modes'].values())},
            separators=(',', ':')) + ';\n'
        '  var CATS = ' + json.dumps({r['key']: train_cat(r) for r in rows},
                                     separators=(',', ':')) + ';\n'
        '  var MUSCLE_OF = ' + json.dumps({r['key']: r['muscles'] for r in rows},
                                          separators=(',', ':')) + ';\n'
        '  var MUSCLE_META = ' + json.dumps(
            [{'key': m, 'name': MUSCLE_NAME[m], 'view': MUSCLE_VIEW[m],
              'target': MUSCLE_TARGET[m]} for m in MUSCLE_ORDER],
            separators=(',', ':')) + ';\n'
        '  /* BANK END */')

changed = [n for n, done in (
    ('app.js', splice(ROOT / 'app.js', '/* BANK BEGIN */\n', '  /* BANK END */',
                      client)),
    ('supabase/schema.sql', splice(ROOT / 'supabase' / 'schema.sql',
                                   '-- BANK BEGIN\n', '-- BANK END', sql)),
    ('tools/test/mock-supabase.js', splice(ROOT / 'tools' / 'test' / 'mock-supabase.js',
                                           '  /* BANK BEGIN */\n', '  /* BANK END */',
                                           mock[mock.index('\n') + 1:mock.rindex('  /* BANK END */')]))) if done]
print('%d exercises, %d regions%s' % (len(rows), len(MUSCLE_ORDER),
      ' · spliced ' + ', '.join(changed) if changed else ' · already up to date'))
