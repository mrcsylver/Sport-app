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

Gym lifts use the same quantity: R = own + (load x equip) / bodyweight is the
very same "fraction of bodyweight moved" that L is, so a bench press at 64% of
your weight scores like a push-up. `own` is the part of that fraction the lift
already carries before a plate goes on - 0.85 on a standing leg lift, 1.0 on a
dip or a pull-up you hang from, 0 on a bench or a seated machine.

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
    ('divebomber',  'Dive Bomber Push-up',     0.75, 1, 'dive bomber hindu dand'),
    ('pikeelev',    'Elevated Pike Push-up',   0.95, 1, 'feet raised pike deficit shoulder'),
    ('wallwalk',    'Wall Walk',               1.00, 1, 'wall walk handstand progression'),
    ('handstand',   'Handstand Push-up',       0.95, 1.7, 'hspu wall overhead invert'),
]
PULL = [
    ('rows',         'Inverted Rows',      0.55, 1, 'australian bodyweight row horizontal'),
    ('scapulapull',  'Scapular Pull-up',   0.35, 1, 'scap shrug'),
    ('bandpullup',   'Assisted Pull-up',   0.60, 1, 'band assisted machine'),
    ('jumppull',     'Jumping Pull-up',    0.50, 1, 'jump assisted beginner first pullup'),
    ('negativepull', 'Negative Pull-up',   0.70, 1, 'negative eccentric slow lower'),
    ('chinups',      'Chin-ups',           0.95, 1, 'supinated underhand biceps'),
    ('pullups',      'Pull-ups',           1.00, 1, 'pullup overhand lats'),
    ('widepullup',   'Wide-grip Pull-up',  1.10, 1, 'wide lats'),
    ('commandopull', 'Commando Pull-up',   1.10, 1, 'mixed grip'),
    ('lsitpullup',   'L-sit Pull-up',      1.25, 1, 'lsit legs out'),
    ('typewriter',   'Typewriter Pull-up', 1.25, 1, 'side to side'),
    ('archerpull',   'Archer Pull-up',     1.30, 1, 'one side unilateral'),
    ('muscleup',     'Muscle-up',          1.00, 1.75, 'muscleup bar ring transition'),
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
    ('cossack',     'Cossack Squat',        1.10, 1, 'cossack side lateral squat mobility'),
    ('boxpistol',   'Box Pistol',           1.30, 1, 'box pistol to a seat assisted single leg'),
    ('archersquat', 'Archer Squat',         1.45, 1.15, 'archer skater side single leg'),
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
    ('hollowrock',  'Hollow Rocks',        0.50, 'hollow rock body rocking'),
    ('windshield',  'Windshield Wipers',   1.50, 'windshield wiper oblique hanging'),
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

    # --- the skill ladders -------------------------------------------------
    # A calisthenics skill is a staircase, and the league was only paying for
    # the top step: you could log a front lever but not the tuck you spend
    # three months on. Every rung is here now, and each is priced so that a
    # HONEST SET AT YOUR OWN LEVEL is worth about the same — because the point
    # is to make people climb, not to pay whoever is already at the top.
    #
    #   20 s crow             (a beginner's first balance)   4.0 pts
    #   30 s wall handstand                                  7.5
    #   20 s tucked L-sit                                    5.0
    #   20 s tuck front lever                                6.7
    #   20 s freestanding handstand                         10.0
    #   10 s straddle front lever                            6.0
    #    5 s full planche     (a few people on earth)         5.0
    #
    # The rate climbs steeply with difficulty and the hold you can actually
    # finish shrinks just as fast, so the two cancel. Nobody is punished for
    # being at the bottom of a ladder and nobody is paid twice for being at
    # the top of one.
    ('crow',        'Crow / Frog Stand',      'PUSH', 'seconds',  720, 'crow bakasana frog stand balance'),
    ('headstand',   'Headstand',              'PUSH', 'minutes',  600, 'headstand tripod sirsasana'),
    ('wallhandstand','Wall Handstand',        'PUSH', 'seconds',  900, 'wall handstand chest back to wall hold'),
    ('forearmstand','Forearm Stand (Pincha)', 'PUSH', 'seconds', 1260, 'pincha forearm stand elbow handstand'),
    ('freehandstand','Freestanding Handstand','PUSH', 'seconds', 1800, 'freestanding handstand balance no wall'),
    ('tuckplanche', 'Tuck Planche',           'PUSH', 'seconds', 1620, 'tuck planche progression'),
    ('straddleplanche','Straddle Planche',    'PUSH', 'seconds', 2880, 'straddle planche'),
    ('fullplanche', 'Full Planche',           'PUSH', 'seconds', 3600, 'full planche straight body'),

    ('tucklsit',    'Tucked L-sit',           'CORE', 'seconds',  900, 'tuck lsit knees tucked support hold'),
    ('oneleglsit',  'One-leg L-sit',          'CORE', 'seconds', 1140, 'one leg lsit half lsit progression'),
    ('vsit',        'V-sit',                  'CORE', 'seconds', 2160, 'vsit legs high advanced lsit'),
    ('bridge',      'Full Bridge (Wheel)',    'CORE', 'seconds',  600, 'bridge wheel backbend urdhva'),

    ('tuckfl',      'Tuck Front Lever',       'PULL', 'seconds', 1200, 'tuck front lever progression'),
    ('advtuckfl',   'Adv. Tuck Front Lever',  'PULL', 'seconds', 1620, 'advanced tuck front lever open'),
    ('straddlefl',  'Straddle Front Lever',   'PULL', 'seconds', 2160, 'straddle front lever one leg'),
    ('tuckbl',      'Tuck Back Lever',        'PULL', 'seconds', 1080, 'tuck back lever progression'),
    ('backlever',   'Back Lever',             'PULL', 'seconds', 2160, 'back lever straight'),
    ('onearmhang',  'One-arm Hang',           'PULL', 'seconds', 1440, 'one arm hang single grip'),
    ('tuckflag',    'Tuck / Chamber Flag',    'PULL', 'seconds', 1440, 'chamber flag tuck human flag progression'),
    ('humanflag',   'Human Flag',             'PULL', 'seconds', 2880, 'human flag pole side lever'),
    ('carry',       'Loaded Carry',           'PULL', 'minutes',  720, 'farmer walk suitcase carry grip traps'),
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
    # Carrying weight costs roughly in proportion to what you carry, so these
    # sit above their unloaded twins by about what a 15-20% load adds.
    ('weightrun','Weighted Run',    'km',      6.5,    'weighted run vest ruck run ankle weights',
     'Vest, pack or ankle weights — log the distance, not the load'),
    ('ruck',    'Rucking',          'km',      3.5,    'ruck rucking loaded march backpack hike',
     'Walking with a loaded pack'),
    ('row',     'Rowing Machine',   'minutes', 30/60,  'erg ergometer concept2', 'Indoor erg'),
    ('jumprope','Jump Rope',        'minutes', 33/60,  'skipping rope', 'Skipping'),
    ('stairs',  'Stair Climbing',   'minutes', 30/60,  'stairmaster steps', 'Real stairs or machine'),
]
# Team and racket sports. Priced BELOW swimming on purpose: an hour of sport is
# the least verifiable entry in the app and includes a lot of standing around,
# so the honest ceiling is the constraint, not the effort.
# Still the cheapest hour in the app, and deliberately so, but ten points for
# ninety minutes of football read as an insult rather than a discount.
SPORT_HIGH = 15/60   # 15 pts / hour
SPORT_MOD  = 10/60   # 10 pts / hour
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

# --------------------------------- the body you are already holding --
# A gym lift moves the bar. Some of them move YOU as well, and the model used
# to say so with a yes/no: a standing leg lift added 0.85 of bodyweight and
# everything else added nothing. That was wrong in a way only a gym-goer would
# ever hit — the weight typed into a weighted dip or a weighted pull-up is what
# hangs from the BELT, so strapping on 20 kg scored a THIRD of what the same
# rep pays with no belt at all. Adding weight made the movement worth less.
#
# `own` is that number written properly: the fraction of bodyweight a lift
# already carries before a single plate goes on, so
#
#     R = own + load x equip / bodyweight
#
# The three bodyweight-plus-load lifts take theirs FROM THE ANCHORS, so a
# weighted dip with an empty belt scores exactly what a dip scores and there is
# no cheaper way to log the same rep. A standing leg lift keeps its 0.85, which
# is what it always had. Everything else is zero.
GYM_OWN = {}          # key -> fraction; filled in below, once K_GYM exists
GYM_OWN_BY_PATTERN = {'legs': 0.85}    # and 0 for every other pattern


def _own_from_anchor(key, k):
    """Whatever bodyweight fraction reproduces the anchored rate exactly."""
    return round(ANCHOR[key] / k, 4)


# --------------------------------------------------------- weekly caps --
# Points are linear in reps; effort is not. The ceiling on a hard movement is
# what a body can do, the ceiling on an easy one is only boredom, so the
# cheapest thing you can repeat forever was always the best points per hour.
#
# The first CAP points of one exercise in one week pay in full, the next CAP
# pay half, everything after that pays a quarter. It never reaches zero: no
# total is capped and nobody is ever told to stop, repeating one movement just
# stops being the best way to score.
#
# DEFAULT_CAP is deliberately generous — 200 points is 200 push-ups, 100
# pull-ups, 400 squats, 800 Russian twists or twenty minutes of plank, and only
# push-ups have ever crossed it. Distance cardio gets its own numbers because a
# single long ride or run is one session, not a farm: a cyclist covers 130 km
# in one Sunday, so pricing that as repetition would be wrong.
DEFAULT_CAP = 200
WEEK_CAP = {          # key -> points of full-price work per week
    'run':       500,   # 100 km
    'weightrun': 650,   # 100 km, at the loaded rate
    'walk':      250,   # 100 km
    'ruck':      350,   # 100 km, at the loaded rate
    'bike':      300,   # 200 km
}

# --------------------------------------------------------------------- gym --
# points/rep = k_pattern x R,  R = (load x equip) / bodyweight
# Legs add the lifter's own mass above the bar: R = (load x equip + 0.85 BW) / BW
# Equipment is baked into the exercise, so nobody has to pick a factor:
# free weight 1.0, machine 0.75, cable 0.6, assisted 0.5.
# ONE_ARM lifts are done a side at a time, so the number typed in is the one
# dumbbell — not the pair. Everything else is the total on the bar. Saying so
# per exercise is the only way people enter it consistently.
ONE_ARM = {'gymdbrow', 'gymtricep', 'gymcurl', 'gymlatraise', 'gymwoodchop',
           'gymhammer', 'gymreardelt'}

GYM = [
    # key, name, pattern, equip, aliases
    ('gymbench',     'Bench Press',           'push', 1.00, 'bench barbell chest press flat smith'),
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
    ('gymsquat',     'Back Squat',            'legs', 1.00, 'squat barbell back high bar smith'),
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
    # Added after a gym-goer pointed out how much of a commercial gym the list
    # did not cover. Two of the fourteen regions had no lift that led with them
    # at all: forearms and lower back.
    ('gympecdeck',   'Chest Fly (Machine/Cable)','push', 0.60, 'pec deck fly crossover cable'),
    ('gymshoulderm', 'Shoulder Press (Machine)','push',  0.75, 'machine seated shoulder delt press'),
    ('gymskull',     'Skullcrusher / Overhead Ext.','push',1.00,'skullcrusher french press tricep extension'),
    ('gympreacher',  'Preacher Curl',         'pull',    1.00, 'preacher ez bar scott curl'),
    ('gymhammer',    'Hammer Curl',           'pull',    1.00, 'hammer neutral dumbbell curl'),
    ('gymreardelt',  'Rear Delt Fly',         'pull',    0.60, 'reverse pec deck rear delt fly'),
    ('gymtbar',      'T-Bar / Supported Row', 'pull',    1.00, 'tbar chest supported row machine'),
    ('gymtrapbar',   'Trap Bar Deadlift',     'pull',    1.00, 'trap hex bar deadlift'),
    ('gymupright',   'Upright Row',           'pull',    1.00, 'upright row traps delts'),
    ('gymwristcurl', 'Wrist Curl',            'pull',    1.00, 'wrist curl forearm reverse grip'),
    ('gymhack',      'Hack Squat',            'legs',    0.75, 'hack squat machine sled'),
    ('gymabduct',    'Hip Abduction / Adduction','legsiso',0.75,'abductor adductor machine hip glute'),
    ('gymbackext',   'Back Extension',        'legsiso', 1.00, 'hyperextension back extension roman chair good morning'),
]
K_GYM = {'push': K_PUSH, 'pull': K_PULL, 'legs': K_LEGS, 'legsiso': K_LEGS,
         'coreiso': 1.0}   # core work is priced against the knee-raise anchor

GYM_OWN.update({
    # you hang from these, so your body is the load before the belt is
    'gymdip':        _own_from_anchor('dips', K_PUSH),     # a dip with 0 kg IS a dip
    'gymweightpull': _own_from_anchor('pullups', K_PULL),  # and likewise a pull-up
    'gymcalf':       _own_from_anchor('calves', K_LEGS),   # you stand on the machine
    # a 45 degree hyperextension raises the upper body and nothing else, which
    # puts it beside supermans when no plate is held
    'gymbackext':    0.45,
})


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
    'chest': 'front', 'shoulders': 'both', 'biceps': 'front', 'triceps': 'both',
    'forearms': 'both', 'traps': 'both', 'lats': 'back', 'lowerback': 'back',
    'abs': 'front', 'obliques': 'front', 'glutes': 'back', 'quads': 'front',
    'hamstrings': 'back', 'calves': 'both',
}

# A full week's work on each region, in points. This is the whole meaning of
# the number the app shows: your points on a region divided by this, as a
# percentage. 100% is a week's dose of that muscle done. There are fourteen of
# them, so filling all fourteen is the thing to chase and almost nobody will.
#
# It used to be the K in an exponential that approached 100 without reaching
# it. That was mathematically tidy and nobody could tell you what 63% meant.
# A percentage of a week is a sentence anyone can finish.
#
# The ratios are anatomical — a quadriceps takes more weekly work than a calf —
# and are deliberately NOT fitted to what any league happens to do. Fitting
# them to real usage was tried and it is a trap: this league does almost no
# pulling, so a fit dropped the lats target by two thirds and the figure
# started congratulating people for the exact gap it exists to show.
#
# Checked against a real league of 28 over a real week, individual weeks from
# 270 to 1091 points: the heaviest fills ten of fourteen, the lightest two, and
# everybody has a weakest region they can name.
MUSCLE_TARGET = {
    'chest': 70, 'shoulders': 55, 'biceps': 30, 'triceps': 40, 'forearms': 25,
    'traps': 30, 'lats': 70, 'lowerback': 30, 'abs': 45, 'obliques': 30,
    'glutes': 55, 'quads': 85, 'hamstrings': 55, 'calves': 25,
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
    # --- the new calisthenics rungs ---
    'divebomber':    {'chest': .35, 'shoulders': .35, 'triceps': .25, 'abs': .05},
    'pikeelev':      {'shoulders': .55, 'triceps': .30, 'traps': .10, 'abs': .05},
    'wallwalk':      {'shoulders': .45, 'triceps': .25, 'abs': .20, 'chest': .10},
    'jumppull':      {'lats': .40, 'biceps': .25, 'forearms': .15, 'traps': .10, 'quads': .10},
    'negativepull':  {'lats': .45, 'biceps': .25, 'forearms': .15, 'traps': .15},
    'cossack':       {'quads': .40, 'glutes': .30, 'hamstrings': .25, 'calves': .05},
    'boxpistol':     {'quads': .45, 'glutes': .30, 'hamstrings': .15, 'calves': .10},
    'archersquat':   {'quads': .45, 'glutes': .30, 'hamstrings': .20, 'calves': .05},
    'hollowrock':    {'abs': .80, 'quads': .20},
    'windshield':    {'obliques': .55, 'abs': .30, 'lats': .15},
    'crow':          {'shoulders': .30, 'triceps': .20, 'forearms': .20, 'abs': .30},
    'headstand':     {'shoulders': .30, 'traps': .25, 'abs': .35, 'forearms': .10},
    'wallhandstand': {'shoulders': .50, 'triceps': .20, 'traps': .15, 'abs': .15},
    'forearmstand':  {'shoulders': .45, 'triceps': .10, 'traps': .20, 'abs': .25},
    'freehandstand': {'shoulders': .45, 'triceps': .15, 'traps': .15, 'abs': .15,
                      'forearms': .10},
    'tuckplanche':   {'shoulders': .35, 'triceps': .15, 'abs': .30, 'lats': .10,
                      'forearms': .10},
    'straddleplanche':{'shoulders': .35, 'triceps': .15, 'abs': .25, 'lats': .15,
                      'forearms': .10},
    'fullplanche':   {'shoulders': .35, 'triceps': .15, 'abs': .25, 'lats': .15,
                      'forearms': .10},
    'tucklsit':      {'abs': .60, 'triceps': .20, 'shoulders': .10, 'quads': .10},
    'oneleglsit':    {'abs': .55, 'triceps': .18, 'shoulders': .10, 'quads': .17},
    'vsit':          {'abs': .55, 'triceps': .15, 'quads': .20, 'shoulders': .10},
    'bridge':        {'lowerback': .30, 'shoulders': .25, 'glutes': .25, 'quads': .10,
                      'chest': .10},
    'tuckfl':        {'lats': .35, 'abs': .30, 'lowerback': .15, 'forearms': .10,
                      'biceps': .10},
    'advtuckfl':     {'lats': .35, 'abs': .30, 'lowerback': .15, 'forearms': .10,
                      'biceps': .10},
    'straddlefl':    {'lats': .35, 'abs': .30, 'lowerback': .15, 'forearms': .10,
                      'biceps': .10},
    'tuckbl':        {'lats': .30, 'chest': .20, 'biceps': .20, 'shoulders': .15,
                      'lowerback': .15},
    'backlever':     {'lats': .30, 'chest': .20, 'biceps': .20, 'shoulders': .15,
                      'lowerback': .15},
    'onearmhang':    {'forearms': .60, 'lats': .20, 'traps': .20},
    'tuckflag':      {'obliques': .40, 'lats': .25, 'shoulders': .20, 'abs': .15},
    'humanflag':     {'obliques': .40, 'lats': .25, 'shoulders': .20, 'abs': .15},
    'carry':         {'forearms': .40, 'traps': .30, 'abs': .15, 'quads': .15},
    'weightrun':     {'quads': .30, 'hamstrings': .25, 'calves': .25, 'glutes': .15,
                      'traps': .05},
    'ruck':          {'quads': .28, 'hamstrings': .20, 'calves': .25, 'glutes': .17,
                      'traps': .10},

    'gympecdeck':    {'chest': .80, 'shoulders': .15, 'triceps': .05},
    'gymshoulderm':  {'shoulders': .60, 'triceps': .30, 'traps': .10},
    'gymskull':      {'triceps': .90, 'shoulders': .10},
    'gympreacher':   {'biceps': .75, 'forearms': .25},
    'gymhammer':     {'biceps': .55, 'forearms': .45},
    'gymreardelt':   {'shoulders': .60, 'traps': .30, 'lats': .10},
    'gymtbar':       {'lats': .45, 'traps': .25, 'biceps': .20, 'forearms': .10},
    'gymtrapbar':    {'traps': .15, 'forearms': .10, 'lowerback': .20, 'glutes': .25,
                      'quads': .20, 'hamstrings': .10},
    'gymupright':    {'shoulders': .45, 'traps': .40, 'biceps': .15},
    'gymwristcurl':  {'forearms': 1.0},
    'gymhack':       {'quads': .60, 'glutes': .25, 'hamstrings': .15},
    'gymabduct':     {'glutes': .80, 'quads': .10, 'hamstrings': .10},
    'gymbackext':    {'lowerback': .55, 'glutes': .30, 'hamstrings': .15},
    # ---- recovery trains nothing; see the note above ----
    'stretch': {},
    'sauna':   {},
}
