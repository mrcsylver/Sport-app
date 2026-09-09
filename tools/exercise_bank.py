"""
Single source of truth for every exercise in Iron League.

Rates are DERIVED, not guessed. For calisthenics the load an exercise moves is
expressed as a fraction of bodyweight (L), and the rate is k_pattern x L, where
each k is fitted to the exercises the league already agreed on:

    push-up   L 0.64 -> 1.0  /rep   => k_push = 1.5625
    pull-up   L 1.00 -> 2.0  /rep   => k_pull = 2.0
    air squat L 0.85 -> 0.5  /rep   => k_legs = 0.588

That model reproduces dips (1.56 ~ 1.5), rows (1.10 ~ 1.0) and calf raises
(0.20) from the original hand-tuned table, so the bank inherits balance that
was already approved rather than inventing a new one.

A handful of lifts sit above the model on purpose - handstand push-ups,
muscle-ups, pistols. Those are "can you even do one" skills and carry an
explicit premium, which is exactly how they were priced originally.

Gym lifts use the same quantity: R = (load x equip) / bodyweight is the very
same "fraction of bodyweight moved" that L is, so a bench press at 64% of your
weight scores like a push-up. Legs add the lifter's own mass to the bar.

Run this to regenerate app.js's table and the SQL seed - never edit either by
hand:  python3 tools/build_exercises.py
"""

K_PUSH, K_PULL, K_LEGS = 1.5625, 2.0, 0.588

def q(x, step=0.25):
    """Round to a rate people can do arithmetic on, never to zero."""
    r = round(x / step) * step
    return round(max(r, step), 2)

# ---------------------------------------------------------------- anchors --
# The 19 the league already runs on. Keys and rates are frozen: changing one
# would silently rewrite history, since points are stamped at insert time.
ANCHOR = {
    'pushups': 1, 'dips': 1.5, 'handstand': 2.5, 'rows': 1, 'pullups': 2,
    'muscleup': 3.5, 'airsquats': 0.5, 'pistols': 2, 'calves': 0.2,
    'kneeraises': 1, 'twists': 0.25,
}

# key, name, L (bodyweight fraction), premium, aliases
PUSH = [
    ('wallpush',    'Wall Push-up',            0.20, 1, 'wall easy beginner'),
    ('kneepush',    'Knee Push-up',            0.49, 1, 'knees modified beginner'),
    ('inclinepush', 'Incline Push-up',         0.41, 1, 'bench elevated hands raised'),
    ('pushups',     'Push-ups',                0.64, 1, 'pushup press floor'),
    ('widepush',    'Wide Push-up',            0.64, 1, 'wide grip chest'),
    ('diamondpush', 'Diamond Push-up',         0.70, 1, 'triceps close narrow'),
    ('declinepush', 'Decline Push-up',         0.75, 1, 'feet elevated'),
    ('pikepush',    'Pike Push-up',            0.85, 1, 'shoulders delts'),
    ('clappush',    'Clap Push-up',            0.90, 1, 'explosive plyo power'),
    ('archerpush',  'Archer Push-up',          0.90, 1, 'one side unilateral'),
    ('planchepush', 'Pseudo Planche Push-up',  0.95, 1, 'lean planche straight arm'),
    ('benchdips',   'Bench Dips',              0.45, 1, 'tricep chair'),
    ('dips',        'Dips',                    1.00, 1, 'parallel bars triceps'),
    ('ringdips',    'Ring Dips',               1.10, 1, 'rings unstable'),
    ('onearmpush',  'One-arm Push-up',         1.20, 1, 'single arm'),
    ('handstand',   'Handstand Push-up',       0.95, 1.7, 'hspu wall overhead invert'),
]
PULL = [
    ('rows',         'Inverted Rows',      0.55, 1, 'australian bodyweight row horizontal'),
    ('scapulapull',  'Scapular Pull-up',   0.35, 1, 'scap shrug'),
    ('bandpullup',   'Assisted Pull-up',   0.60, 1, 'band assisted machine'),
    ('chinups',      'Chin-ups',           0.95, 1, 'supinated underhand biceps'),
    ('pullups',      'Pull-ups',           1.00, 1, 'pullup overhand lats'),
    ('widepullup',   'Wide-grip Pull-up',  1.10, 1, 'wide lats'),
    ('commandopull', 'Commando Pull-up',   1.10, 1, 'mixed grip'),
    ('lsitpullup',   'L-sit Pull-up',      1.25, 1, 'lsit legs out'),
    ('typewriter',   'Typewriter Pull-up', 1.25, 1, 'side to side'),
    ('archerpull',   'Archer Pull-up',     1.30, 1, 'one side unilateral'),
    ('muscleup',     'Muscle-up / Flag',   1.00, 1.75, 'muscleup bar ring humanflag'),
]
LEGS = [
    ('calves',      'Calf Raises',          None, 1, 'calf standing seated'),  # anchored 0.2
    ('airsquats',   'Air Squats',           0.85, 1, 'bodyweight squat'),
    ('jumpsquats',  'Jump Squats',          1.20, 1, 'plyo explosive'),
    ('lunges',      'Lunges',               0.85, 1, 'walking reverse forward'),
    ('splitsquat',  'Bulgarian Split Squat',1.40, 1, 'bulgarian rear foot elevated'),
    ('stepups',     'Step-ups',             1.00, 1, 'box bench'),
    ('gluteBridge', 'Glute Bridge',         0.50, 1, 'hip thrust glutes'),
    ('nordic',      'Nordic Curl',          1.60, 1, 'hamstring eccentric'),
    ('sissy',       'Sissy Squat',          1.10, 1, 'quads'),
    ('shrimp',      'Shrimp Squat',         1.50, 1, 'advanced single leg'),
    ('pistols',     'Pistol Squats',        1.70, 2, 'single leg one'),
]

# Core is about leverage, not load, so these are priced against the knee-raise
# anchor (1.0/rep) by how much harder the position is, not by a BW fraction.
CORE_REPS = [
    ('crunches',    'Crunches',            0.25, 'crunch sit abs'),
    ('situps',      'Sit-ups',             0.50, 'situp full'),
    ('twists',      'Russian Twists',      0.25, 'oblique twist side'),
    ('legraises',   'Lying Leg Raises',    0.50, 'floor lying'),
    ('kneeraises',  'Hanging Knee Raises', 1.00, 'hanging knee tuck'),
    ('hangingleg',  'Hanging Leg Raises',  1.50, 'straight leg toes'),
    ('toestobar',   'Toes to Bar',         2.00, 'ttb crossfit'),
    ('dragonflag',  'Dragon Flag',         3.00, 'dragon advanced'),
    ('vups',        'V-ups',               0.75, 'v up jackknife'),
    ('supermans',   'Supermans',           0.25, 'lower back extension'),
]
CORE_HOLD = [   # key, name, cat, mode, rate, aliases
    ('plank',      'Plank',           'CORE', 'minutes', 2,     'front elbow forearm'),
    ('sideplank',  'Side Plank',      'CORE', 'minutes', 2.5,   'oblique side'),
    ('hollowhold', 'Hollow Hold',     'CORE', 'seconds', 3/60,  'hollow body'),
    ('lsit',       'L-sit',           'CORE', 'seconds', 1/3,   'lsit legs parallel'),
    ('wallsit',    'Wall Sit',        'LEGS', 'seconds', 1.5/60,'isometric quads'),
    ('deadhang',   'Dead Hang',       'PULL', 'seconds', 2/60,  'hang grip forearm'),
    ('frontlever', 'Front Lever',     'PULL', 'seconds', 0.5,   'lever static hold'),
]

CARDIO = [   # (key, name, mode, rate, aliases, variants)
    ('run',     'Run',              'km',      5,      'running jog jogging', 'Outdoor or treadmill'),
    ('sprints', 'Sprint Intervals', 'reps',    2,      'sprint interval hiit', 'One sprint = 15 sec flat out, 100 m minimum'),
    ('bike',    'Biking',           'km',      1.5,    'cycling bicycle spin', 'Road / Trail / Stationary'),
    ('swim',    'Swim',             'minutes', 12/60,  'swimming pool crawl', 'Any stroke, active swim time'),
    ('walk',    'Walking',          'km',      2.5,    'walk hike hiking steps', 'Hiking counts too'),
    ('row',     'Rowing Machine',   'minutes', 10/60,  'erg ergometer concept2', 'Indoor erg'),
    ('jumprope','Jump Rope',        'minutes', 8/60,   'skipping rope', 'Skipping'),
    ('stairs',  'Stair Climbing',   'minutes', 9/60,   'stairmaster steps', 'Real stairs or machine'),
]
# Team and racket sports. Priced BELOW swimming on purpose: an hour of sport is
# the least verifiable entry in the app and includes a lot of standing around,
# so the honest ceiling is the constraint, not the effort.
SPORT_HIGH = 10/60   # 10 pts / hour
SPORT_MOD  = 7/60    # 7 pts / hour
SPORTS = [
    ('football',   'Football / Soccer', SPORT_HIGH, 'soccer foot futbol match'),
    ('basketball', 'Basketball',        SPORT_HIGH, 'basket hoops ball'),
    ('rugby',      'Rugby',             SPORT_HIGH, 'rugby union league'),
    ('handball',   'Handball',          SPORT_HIGH, 'hand ball'),
    ('hockey',     'Hockey',            SPORT_HIGH, 'ice field puck'),
    ('squash',     'Squash',            SPORT_HIGH, 'squash racket court'),
    ('boxing',     'Boxing / Martial Arts', SPORT_HIGH, 'box mma judo bjj karate muay sparring'),
    ('climbing',   'Climbing',          SPORT_HIGH, 'bouldering rock wall'),
    ('tennis',     'Tennis',            SPORT_MOD,  'tennis racket court'),
    ('padel',      'Padel',             SPORT_MOD,  'padel paddle'),
    ('volleyball', 'Volleyball',        SPORT_MOD,  'volley beach net'),
    ('badminton',  'Badminton',         SPORT_MOD,  'badminton shuttle'),
    ('tabletennis','Table Tennis',      SPORT_MOD,  'ping pong'),
    ('othersport', 'Other Sport',       SPORT_MOD,  'other misc game match'),
]
RECOVERY = [
    ('stretch',  'Stretching Session', 5, 'stretch mobility yoga flexibility'),
    ('sauna',    'Sauna / Cold Plunge',3, 'sauna ice bath cold recovery'),
]

# --------------------------------------------------------------------- gym --
# points/rep = k_pattern x R,  R = (load x equip) / bodyweight
# Legs add the lifter's own mass above the bar: R = (load x equip + 0.85 BW) / BW
# Equipment is baked into the exercise, so nobody has to pick a factor:
# free weight 1.0, machine 0.75, cable 0.6, assisted 0.5.
GYM = [
    # key, name, pattern, equip, aliases
    ('gymbench',     'Bench Press',           'push', 1.00, 'bench barbell chest press flat'),
    ('gymdbbench',   'Dumbbell Bench Press',  'push', 1.00, 'dumbbell db incline chest'),
    ('gymohp',       'Overhead Press',        'push', 1.00, 'ohp military shoulder press standing'),
    ('gymdip',       'Weighted Dips',         'push', 1.00, 'weighted dip belt'),
    ('gymchestmach', 'Chest Press (Machine)', 'push', 0.75, 'machine chest press pec'),
    ('gymtricep',    'Tricep Pushdown',       'push', 0.60, 'cable pushdown tricep rope'),
    ('gymlatraise',  'Lateral Raise',         'push', 1.00, 'side delt raise shoulder'),
    ('gymdeadlift',  'Deadlift',              'pull', 1.00, 'deadlift conventional sumo barbell'),
    ('gymbarbellrow','Barbell Row',           'pull', 1.00, 'bent over row pendlay'),
    ('gymdbrow',     'Dumbbell Row',          'pull', 1.00, 'one arm db row'),
    ('gymlatpull',   'Lat Pulldown',          'pull', 0.75, 'pulldown machine lats'),
    ('gymcablerow',  'Seated Cable Row',      'pull', 0.60, 'cable row seated'),
    ('gymweightpull','Weighted Pull-up',      'pull', 1.00, 'weighted pullup belt'),
    ('gymcurl',      'Bicep Curl',            'pull', 1.00, 'curl barbell dumbbell biceps'),
    ('gymfacepull',  'Face Pull',             'pull', 0.60, 'cable rear delt'),
    ('gymsquat',     'Back Squat',            'legs', 1.00, 'squat barbell back high bar'),
    ('gymfrontsquat','Front Squat',           'legs', 1.00, 'front squat clean grip'),
    ('gymlegpress',  'Leg Press',             'legs', 0.75, 'leg press machine'),
    ('gymrdl',       'Romanian Deadlift',     'legs', 1.00, 'rdl stiff leg hamstring'),
    ('gymhipthrust', 'Hip Thrust',            'legs', 1.00, 'glute bridge barbell'),
    ('gymlegcurl',   'Leg Curl',              'legsiso', 0.75, 'hamstring machine curl'),
    ('gymlegext',    'Leg Extension',         'legsiso', 0.75, 'quad machine extension'),
    ('gymlunge',     'Weighted Lunge',        'legs', 1.00, 'dumbbell lunge walking'),
    ('gymcalf',      'Weighted Calf Raise',   'legsiso', 0.75, 'calf machine standing'),
]
K_GYM = {'push': K_PUSH, 'pull': K_PULL, 'legs': K_LEGS, 'legsiso': K_LEGS}
