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
    ('sphinxpush',  'Sphinx Push-up',          0.55, 1, 'sphinx forearm tricep'),
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
    ('sidecrunch',  'Lateral Crunches',    0.25, 'side oblique lateral crunch'),
    ('bicycle',     'Bicycle Crunches',    0.25, 'bicycle cycling abs'),
    ('deadbug',     'Dead Bug',            0.5,  'deadbug stability'),
    ('birddog',     'Bird Dog',            0.5,  'birddog stability back'),
    ('flutterkick', 'Flutter Kicks',       0.25, 'flutter scissor kicks'),
    ('mountainclimb','Mountain Climbers',  0.25, 'mountain climber cardio abs'),
    ('rollout',     'Ab Wheel Rollout',    2.0,  'ab wheel rollout barbell'),
]
# Holds are priced per MINUTE OF HOLD, not per minute of clock, because
# nobody holds one for an hour: the honest unit is the set you can actually
# finish. The endurance holds used to sit at 90-180 points an hour while a set
# of reps pays 20-30 points a minute, so thirty seconds of plank was worth one
# point and a dead hang was worth two — the exact "1 point per 30 seconds" that
# made people stop logging them. They now pay what a hard set pays: a two
# minute plank scores like twenty push-ups, a sixty second dead hang like
# twelve. The skill holds keep their premium above that, in the same spirit as
# the handstand and the muscle-up.
HOLD_MIN = 60.0                       # rates below are points per HOUR of hold
CORE_HOLD = [   # key, name, cat, mode, points/hour, aliases
    ('plank',      'Plank',           'CORE', 'minutes',  600, 'front elbow forearm'),
    ('sideplank',  'Side Plank',      'CORE', 'minutes',  720, 'oblique side'),
    ('hollowhold', 'Hollow Hold',     'CORE', 'seconds',  900, 'hollow body'),
    ('lsit',       'L-sit',           'CORE', 'seconds', 1440, 'lsit legs parallel'),
    ('wallsit',    'Wall Sit',        'LEGS', 'seconds',  540, 'isometric quads'),
    ('deadhang',   'Dead Hang',       'PULL', 'seconds',  720, 'hang grip forearm'),
    ('frontlever', 'Front Lever',     'PULL', 'seconds', 2700, 'lever static hold'),
]

# Distance entries are priced per kilometre; time entries per hour. The two
# have to agree, and for a long time they did not: running ten kilometres in an
# hour paid 50, while an hour of swimming paid 12, an hour of rowing 10 and an
# hour of skipping 8. Nothing about a length of front crawl is a fifth of a
# kilometre of jogging. The continuous ones now sit at 30-33 an hour — below
# running, because what is typed in is a duration nobody can check rather than
# a distance a watch recorded, but inside the same argument instead of outside
# it.
CARDIO = [   # (key, name, mode, rate, aliases, variants)
    ('run',     'Run',              'km',      5,      'running jog jogging', 'Outdoor or treadmill'),
    ('sprints', 'Sprint Intervals', 'reps',    2,      'sprint interval hiit', 'One sprint = 15 sec flat out, 100 m minimum'),
    ('bike',    'Biking',           'km',      1.5,    'cycling bicycle spin', 'Road / Trail / Stationary'),
    ('swim',    'Swim',             'minutes', 30/60,  'swimming pool crawl', 'Any stroke, active swim time'),
    ('walk',    'Walking',          'km',      2.5,    'walk hike hiking steps', 'Hiking counts too'),
    ('row',     'Rowing Machine',   'minutes', 30/60,  'erg ergometer concept2', 'Indoor erg'),
    ('jumprope','Jump Rope',        'minutes', 33/60,  'skipping rope', 'Skipping'),
    ('stairs',  'Stair Climbing',   'minutes', 30/60,  'stairmaster steps', 'Real stairs or machine'),
]
# Team and racket sports. Priced BELOW swimming on purpose: an hour of sport is
# the least verifiable entry in the app and includes a lot of standing around,
# so the honest ceiling is the constraint, not the effort.
# Still the cheapest hour in the app, and deliberately so, but ten points for
# ninety minutes of football read as an insult rather than a discount.
SPORT_HIGH = 18/60   # 18 pts / hour
SPORT_MOD  = 12/60   # 12 pts / hour
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
# ONE_ARM lifts are done a side at a time, so the number typed in is the one
# dumbbell — not the pair. Everything else is the total on the bar. Saying so
# per exercise is the only way people enter it consistently.
ONE_ARM = {'gymdbrow', 'gymtricep', 'gymcurl', 'gymlatraise', 'gymwoodchop'}

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
    ('gymcablecrunch','Cable Crunch',         'coreiso', 0.60, 'cable crunch kneeling abs'),
    ('gymwoodchop',  'Woodchoppers',          'coreiso', 0.60, 'woodchop cable oblique rotation'),
    ('gympullover',  'Dumbbell Pullover',     'pull',    1.00, 'pullover lats chest'),
    ('gymshrug',     'Shrug',                 'pull',    1.00, 'shrug traps barbell'),
    ('gymincline',   'Incline Bench Press',   'push',    1.00, 'incline bench upper chest'),
    ('gymgoblet',    'Goblet Squat',          'legs',    1.00, 'goblet kettlebell squat'),
    ('gymstepup',    'Weighted Step-up',      'legs',    1.00, 'step up box weighted'),
]
K_GYM = {'push': K_PUSH, 'pull': K_PULL, 'legs': K_LEGS, 'legsiso': K_LEGS,
         'coreiso': 1.0}   # core work is priced against the knee-raise anchor


# ------------------------------------------------------------------ muscles --
# What each exercise actually trains, as a share of the points it scores. The
# shares sum to 1, so a hundred points of bench press put fifty into the chest
# and thirty into the triceps: nothing is invented and nothing is double
# counted. Fourteen regions is "medium detail" on purpose — enough that
# somebody can see their triceps lagging their biceps, few enough that every
# one of them is a shape you can point at on a figure.
#
# Recovery trains nothing here. Stretching is worth points and worth doing; it
# is not volume on a muscle, and pretending otherwise would let a week of
# stretching read as a balanced week of training.
MUSCLE_ORDER = ['chest', 'shoulders', 'biceps', 'triceps', 'forearms', 'traps',
                'lats', 'lowerback', 'abs', 'obliques', 'glutes', 'quads',
                'hamstrings', 'calves']

MUSCLE_NAME = {
    'chest': 'Chest',        'shoulders': 'Shoulders', 'biceps': 'Biceps',
    'triceps': 'Triceps',    'forearms': 'Forearms',   'traps': 'Traps',
    'lats': 'Lats',          'lowerback': 'Lower back','abs': 'Abs',
    'obliques': 'Obliques',  'glutes': 'Glutes',       'quads': 'Quads',
    'hamstrings': 'Hamstrings', 'calves': 'Calves',
}

# Which view a region is drawn on. Four of them show on both.
MUSCLE_VIEW = {
    'chest': 'front', 'shoulders': 'both', 'biceps': 'front', 'triceps': 'back',
    'forearms': 'both', 'traps': 'both', 'lats': 'back', 'lowerback': 'back',
    'abs': 'front', 'obliques': 'front', 'glutes': 'back', 'quads': 'front',
    'hamstrings': 'back', 'calves': 'both',
}

# A week's worth of work on each region, in points. These are the K in the
# charge curve, and they are what makes a hundred points of calf raises read
# differently from a hundred points of squats.
#
# The ratios between them are anatomical — a quadriceps takes more weekly work
# than a calf — and are deliberately NOT fitted to what any league happens to
# do. Fitting them to real usage was tried and it is a trap: this league does
# almost no pulling, so a fit dropped the lats target by two thirds and the
# figure started congratulating people for the exact gap it exists to show.
#
# The SCALE was fitted, once, against a real league of 28 over a real week —
# weeks from 270 to 1091 points. At the old scale the three heaviest members
# pegged five regions each at 98% and the top of the figure stopped saying
# anything. One and a half times that puts the best region of the best week at
# about 95%, a median week around 40%, and leaves headroom above everybody.
MUSCLE_TARGET = {
    'chest': 105, 'shoulders': 80, 'biceps': 45, 'triceps': 60, 'forearms': 40,
    'traps': 45, 'lats': 105, 'lowerback': 45, 'abs': 70, 'obliques': 45,
    'glutes': 80, 'quads': 130, 'hamstrings': 80, 'calves': 40,
}

MUSCLES = {
    # ---- push ----
    'wallpush':    {'chest': .50, 'triceps': .30, 'shoulders': .20},
    'kneepush':    {'chest': .50, 'triceps': .30, 'shoulders': .20},
    'inclinepush': {'chest': .50, 'triceps': .30, 'shoulders': .20},
    'pushups':     {'chest': .45, 'triceps': .30, 'shoulders': .15, 'abs': .10},
    'widepush':    {'chest': .60, 'shoulders': .20, 'triceps': .20},
    'diamondpush': {'triceps': .50, 'chest': .35, 'shoulders': .15},
    'declinepush': {'chest': .40, 'shoulders': .30, 'triceps': .25, 'abs': .05},
    'pikepush':    {'shoulders': .55, 'triceps': .30, 'chest': .15},
    'clappush':    {'chest': .40, 'triceps': .30, 'shoulders': .20, 'abs': .10},
    'archerpush':  {'chest': .45, 'triceps': .25, 'shoulders': .20, 'abs': .10},
    'planchepush': {'shoulders': .35, 'chest': .30, 'abs': .20, 'triceps': .15},
    'benchdips':   {'triceps': .60, 'chest': .20, 'shoulders': .20},
    'dips':        {'triceps': .40, 'chest': .40, 'shoulders': .20},
    'ringdips':    {'triceps': .35, 'chest': .35, 'shoulders': .20, 'abs': .10},
    'onearmpush':  {'chest': .40, 'triceps': .25, 'abs': .20, 'shoulders': .15},
    'sphinxpush':  {'triceps': .70, 'chest': .15, 'abs': .15},
    'handstand':   {'shoulders': .55, 'triceps': .30, 'traps': .10, 'abs': .05},
    # ---- pull ----
    'rows':         {'lats': .40, 'biceps': .25, 'traps': .20, 'forearms': .15},
    'scapulapull':  {'traps': .50, 'lats': .30, 'forearms': .20},
    'bandpullup':   {'lats': .45, 'biceps': .30, 'forearms': .15, 'traps': .10},
    'chinups':      {'biceps': .40, 'lats': .35, 'forearms': .15, 'traps': .10},
    'pullups':      {'lats': .45, 'biceps': .25, 'forearms': .15, 'traps': .15},
    'widepullup':   {'lats': .55, 'biceps': .15, 'traps': .15, 'forearms': .15},
    'commandopull': {'lats': .40, 'biceps': .30, 'forearms': .15, 'obliques': .15},
    'lsitpullup':   {'lats': .35, 'abs': .25, 'biceps': .20, 'forearms': .20},
    'typewriter':   {'lats': .40, 'biceps': .20, 'forearms': .20, 'obliques': .20},
    'archerpull':   {'lats': .40, 'biceps': .25, 'forearms': .20, 'obliques': .15},
    'muscleup':     {'lats': .30, 'triceps': .20, 'biceps': .20, 'shoulders': .15,
                     'forearms': .15},
    'deadhang':     {'forearms': .60, 'lats': .20, 'traps': .20},
    'frontlever':   {'lats': .35, 'abs': .30, 'forearms': .20, 'lowerback': .15},
    # ---- legs ----
    'calves':      {'calves': 1.0},
    'airsquats':   {'quads': .50, 'glutes': .30, 'hamstrings': .20},
    'jumpsquats':  {'quads': .45, 'glutes': .25, 'calves': .20, 'hamstrings': .10},
    'lunges':      {'quads': .40, 'glutes': .35, 'hamstrings': .25},
    'splitsquat':  {'quads': .40, 'glutes': .35, 'hamstrings': .25},
    'stepups':     {'quads': .40, 'glutes': .35, 'hamstrings': .15, 'calves': .10},
    'gluteBridge': {'glutes': .60, 'hamstrings': .30, 'lowerback': .10},
    'nordic':      {'hamstrings': .75, 'glutes': .15, 'calves': .10},
    'sissy':       {'quads': .80, 'calves': .10, 'abs': .10},
    'shrimp':      {'quads': .45, 'glutes': .30, 'hamstrings': .15, 'calves': .10},
    'pistols':     {'quads': .45, 'glutes': .30, 'hamstrings': .15, 'calves': .10},
    'wallsit':     {'quads': .70, 'glutes': .20, 'calves': .10},
    # ---- core ----
    'crunches':     {'abs': 1.0},
    'situps':       {'abs': .80, 'obliques': .10, 'quads': .10},
    'twists':       {'obliques': .70, 'abs': .30},
    'legraises':    {'abs': .80, 'quads': .20},
    'kneeraises':   {'abs': .70, 'forearms': .15, 'obliques': .15},
    'hangingleg':   {'abs': .65, 'forearms': .15, 'obliques': .10, 'quads': .10},
    'toestobar':    {'abs': .60, 'lats': .15, 'forearms': .15, 'obliques': .10},
    'dragonflag':   {'abs': .55, 'lowerback': .20, 'lats': .15, 'obliques': .10},
    'vups':         {'abs': .75, 'quads': .15, 'obliques': .10},
    'supermans':    {'lowerback': .60, 'glutes': .25, 'traps': .15},
    'sidecrunch':   {'obliques': .80, 'abs': .20},
    'bicycle':      {'abs': .50, 'obliques': .50},
    'deadbug':      {'abs': .80, 'lowerback': .20},
    'birddog':      {'lowerback': .50, 'glutes': .25, 'abs': .25},
    'flutterkick':  {'abs': .70, 'quads': .30},
    'mountainclimb':{'abs': .50, 'shoulders': .20, 'quads': .20, 'obliques': .10},
    'rollout':      {'abs': .60, 'lats': .20, 'lowerback': .10, 'shoulders': .10},
    'plank':        {'abs': .60, 'shoulders': .20, 'lowerback': .20},
    'sideplank':    {'obliques': .70, 'shoulders': .20, 'abs': .10},
    'hollowhold':   {'abs': .80, 'quads': .20},
    'lsit':         {'abs': .60, 'quads': .20, 'triceps': .20},
    # ---- cardio ----
    'run':      {'quads': .30, 'calves': .30, 'hamstrings': .25, 'glutes': .15},
    'sprints':  {'quads': .30, 'hamstrings': .30, 'calves': .20, 'glutes': .20},
    'bike':     {'quads': .50, 'calves': .20, 'glutes': .20, 'hamstrings': .10},
    'swim':     {'lats': .30, 'shoulders': .30, 'chest': .15, 'abs': .15, 'triceps': .10},
    'walk':     {'calves': .35, 'quads': .30, 'hamstrings': .20, 'glutes': .15},
    'row':      {'lats': .30, 'quads': .25, 'biceps': .15, 'lowerback': .15, 'traps': .15},
    'jumprope': {'calves': .55, 'quads': .20, 'shoulders': .15, 'hamstrings': .10},
    'stairs':   {'quads': .40, 'glutes': .30, 'calves': .20, 'hamstrings': .10},
    # ---- sport ----
    'football':   {'quads': .25, 'hamstrings': .20, 'calves': .20, 'glutes': .15,
                   'abs': .10, 'shoulders': .10},
    'basketball': {'quads': .25, 'calves': .25, 'hamstrings': .15, 'glutes': .15,
                   'shoulders': .10, 'abs': .10},
    'rugby':      {'quads': .25, 'hamstrings': .20, 'shoulders': .15, 'glutes': .15,
                   'calves': .15, 'abs': .10},
    'handball':   {'quads': .25, 'shoulders': .20, 'calves': .20, 'abs': .15,
                   'hamstrings': .10, 'obliques': .10},
    'hockey':     {'quads': .30, 'glutes': .20, 'hamstrings': .15, 'obliques': .15,
                   'forearms': .10, 'calves': .10},
    'squash':     {'quads': .30, 'calves': .20, 'shoulders': .15, 'obliques': .15,
                   'forearms': .10, 'hamstrings': .10},
    'boxing':     {'shoulders': .25, 'abs': .20, 'triceps': .15, 'obliques': .15,
                   'calves': .15, 'chest': .10},
    'climbing':   {'forearms': .30, 'lats': .30, 'biceps': .15, 'abs': .15,
                   'shoulders': .10},
    'tennis':     {'quads': .25, 'shoulders': .20, 'calves': .20, 'obliques': .15,
                   'forearms': .10, 'hamstrings': .10},
    'padel':      {'quads': .25, 'shoulders': .20, 'calves': .20, 'obliques': .15,
                   'forearms': .10, 'hamstrings': .10},
    'volleyball': {'quads': .30, 'calves': .25, 'shoulders': .25, 'abs': .10,
                   'hamstrings': .10},
    'badminton':  {'quads': .25, 'shoulders': .20, 'calves': .25, 'obliques': .15,
                   'forearms': .15},
    'tabletennis':{'shoulders': .25, 'forearms': .20, 'obliques': .20, 'quads': .20,
                   'calves': .15},
    'othersport': {'quads': .20, 'shoulders': .15, 'abs': .15, 'calves': .15,
                   'hamstrings': .10, 'glutes': .10, 'chest': .075, 'lats': .075},
    # ---- gym ----
    'gymbench':      {'chest': .50, 'triceps': .30, 'shoulders': .20},
    'gymdbbench':    {'chest': .50, 'triceps': .25, 'shoulders': .25},
    'gymohp':        {'shoulders': .55, 'triceps': .30, 'traps': .15},
    'gymdip':        {'triceps': .40, 'chest': .40, 'shoulders': .20},
    'gymchestmach':  {'chest': .60, 'triceps': .25, 'shoulders': .15},
    'gymtricep':     {'triceps': 1.0},
    'gymlatraise':   {'shoulders': .85, 'traps': .15},
    'gymdeadlift':   {'lowerback': .25, 'glutes': .25, 'hamstrings': .25,
                      'traps': .15, 'forearms': .10},
    'gymbarbellrow': {'lats': .40, 'traps': .20, 'biceps': .20, 'lowerback': .10,
                      'forearms': .10},
    'gymdbrow':      {'lats': .45, 'biceps': .20, 'traps': .20, 'forearms': .15},
    'gymlatpull':    {'lats': .55, 'biceps': .30, 'forearms': .15},
    'gymcablerow':   {'lats': .45, 'traps': .25, 'biceps': .20, 'forearms': .10},
    'gymweightpull': {'lats': .45, 'biceps': .25, 'forearms': .15, 'traps': .15},
    'gymcurl':       {'biceps': .80, 'forearms': .20},
    'gymfacepull':   {'shoulders': .50, 'traps': .35, 'biceps': .15},
    'gymsquat':      {'quads': .45, 'glutes': .30, 'hamstrings': .15, 'lowerback': .10},
    'gymfrontsquat': {'quads': .55, 'glutes': .20, 'abs': .15, 'lowerback': .10},
    'gymlegpress':   {'quads': .55, 'glutes': .30, 'hamstrings': .15},
    'gymrdl':        {'hamstrings': .45, 'glutes': .30, 'lowerback': .25},
    'gymhipthrust':  {'glutes': .70, 'hamstrings': .25, 'lowerback': .05},
    'gymlegcurl':    {'hamstrings': .90, 'calves': .10},
    'gymlegext':     {'quads': 1.0},
    'gymlunge':      {'quads': .40, 'glutes': .35, 'hamstrings': .25},
    'gymcalf':       {'calves': 1.0},
    'gymcablecrunch':{'abs': .90, 'obliques': .10},
    'gymwoodchop':   {'obliques': .70, 'abs': .20, 'shoulders': .10},
    'gympullover':   {'lats': .55, 'chest': .25, 'triceps': .20},
    'gymshrug':      {'traps': .85, 'forearms': .15},
    'gymincline':    {'chest': .45, 'shoulders': .30, 'triceps': .25},
    'gymgoblet':     {'quads': .45, 'glutes': .30, 'abs': .15, 'hamstrings': .10},
    'gymstepup':     {'quads': .40, 'glutes': .35, 'hamstrings': .15, 'calves': .10},
    # ---- recovery trains nothing; see the note above ----
    'stretch': {},
    'sauna':   {},
}
