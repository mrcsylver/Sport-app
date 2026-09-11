#!/usr/bin/env python3
"""The bounty pool: 100 side quests, one drawn each week.

Kept here rather than typed into SQL twice, because the same rows have to
appear in supabase/schema.sql (the paste-and-run rebuild) and in the
migration that adds them to a database already running. Two hand-written
copies of a hundred rows drift; one generated source cannot.

Run tools/build_bounties.py to write both.

A spec is a small JSON language read by bounty_done() in SQL:

  {"reqs":[{"ex","mode","min","from_h","to_h"}, ...]}   all of these
  {"kind":"any","any":[ ...same shape... ]}             one of these
  {"kind":"distinct","what":"cat"|"ex","min":N}         N different things
  {"kind":"cat_points","cat":"PUSH","min":N}            N points from one group
  {"kind":"reps_across","exercises":N,"min":M}          M reps over N exercises
  {"kind":"split","ex":K,"min":N}                       N before noon and N after
  {"kind":"hourly","ex":K,"each":N,"hours":H}           N in each of H hours
  {"kind":"pr"}                                         beat your own best day
  {"kind":"team","members":N}                           N of you turn up
  {"kind":"duo"}                                        train within an hour of
                                                        somebody else
  {"kind":"underdog"}                                   log while last on points

MICRO bounties are the short ones: flat 20 points for something that takes
under three minutes. They exist so somebody with a fifteen-minute lunch
break can still score today, which is the whole point of a bounty.
"""

POOL = [

    # ---- the original 52 -------------------------------------------------
    ('DAWN PRESS', '40 push-ups before 09:00', 30, {"reqs":[{"ex":"pushups","mode":"reps","min":40,"to_h":9}]}),
    ('CENTURY PUSH', '100 push-ups across the day', 40, {"reqs":[{"ex":"pushups","mode":"reps","min":100}]}),
    ('DIP MASTER', '30 dips', 40, {"reqs":[{"ex":"dips","mode":"reps","min":30}]}),
    ('DIP CENTURY', '50 dips', 50, {"reqs":[{"ex":"dips","mode":"reps","min":50}]}),
    ('INVERTED WORLD', '60 seconds of handstand hold', 40, {"reqs":[{"ex":"handstand","mode":"seconds","min":60}]}),
    ('CEILING PRESS', '5 handstand push-ups', 35, {"reqs":[{"ex":"handstand","mode":"reps","min":5}]}),
    ('LUNCH PRESS', '30 push-ups between 12:00 and 14:00', 25, {"reqs":[{"ex":"pushups","mode":"reps","min":30,"from_h":12,"to_h":14}]}),
    ('NIGHTCAP PUSH', '40 push-ups after 20:00', 30, {"reqs":[{"ex":"pushups","mode":"reps","min":40,"from_h":20}]}),
    ('CLOCK PUNCHER', '10 push-ups in each of 5 different hours', 40, {"kind":"hourly","ex":"pushups","each":10,"hours":5}),
    ('SPLIT CENTURY', '50 push-ups before noon and 50 after', 40, {"kind":"split","ex":"pushups","min":50}),
    ('FIRST PULL', '10 pull-ups before 10:00', 30, {"reqs":[{"ex":"pullups","mode":"reps","min":10,"to_h":10}]}),
    ('ROW COLLECTOR', '50 inverted rows', 40, {"reqs":[{"ex":"rows","mode":"reps","min":50}]}),
    ('PULL CENTURY', '30 pull-ups across the day', 50, {"reqs":[{"ex":"pullups","mode":"reps","min":30}]}),
    ('BAR SURGE', '20 pull-ups', 35, {"reqs":[{"ex":"pullups","mode":"reps","min":20}]}),
    ('PULL AND ROW', '15 pull-ups and 30 rows', 45, {"reqs":[{"ex":"pullups","mode":"reps","min":15},{"ex":"rows","mode":"reps","min":30}]}),
    ('MIDDAY PULL', '15 pull-ups between 12:00 and 15:00', 30, {"reqs":[{"ex":"pullups","mode":"reps","min":15,"from_h":12,"to_h":15}]}),
    ('SKILL WORK', '3 muscle-ups, or a 10 second flag hold', 50, {"kind":"any","any":[{"ex":"muscleup","mode":"reps","min":3},{"ex":"muscleup","mode":"seconds","min":10}]}),
    ('EVENING LATS', '20 pull-ups after 18:00', 35, {"reqs":[{"ex":"pullups","mode":"reps","min":20,"from_h":18}]}),
    ('GREASE THE GROOVE', '1 pull-up in each of 8 different hours', 40, {"kind":"hourly","ex":"pullups","each":1,"hours":8}),
    ('PULL DOUBLE', '15 pull-ups before noon and 15 after', 45, {"kind":"split","ex":"pullups","min":15}),
    ('MORNING LEGS', '100 air squats before 10:00', 35, {"reqs":[{"ex":"airsquats","mode":"reps","min":100,"to_h":10}]}),
    ('PISTOL PURSUIT', '10 pistol squats', 40, {"reqs":[{"ex":"pistols","mode":"reps","min":10}]}),
    ('PISTOL BURNER', '16 pistol squats', 45, {"reqs":[{"ex":"pistols","mode":"reps","min":16}]}),
    ('CORE LOCK', '2 minutes of plank', 30, {"reqs":[{"ex":"plank","mode":"minutes","min":2}]}),
    ('KNEE RAISE SURGE', '60 knee raises', 35, {"reqs":[{"ex":"kneeraises","mode":"reps","min":60}]}),
    ('THE L', '30 seconds of L-sit', 35, {"reqs":[{"ex":"lsit","mode":"seconds","min":30}]}),
    ('SQUAT CENTURY', '100 air squats', 30, {"reqs":[{"ex":"airsquats","mode":"reps","min":100}]}),
    ('AFTERNOON LEGS', '80 air squats between 13:00 and 17:00', 30, {"reqs":[{"ex":"airsquats","mode":"reps","min":80,"from_h":13,"to_h":17}]}),
    ('CORE AND SQUAT', '50 air squats and 30 knee raises', 35, {"reqs":[{"ex":"airsquats","mode":"reps","min":50},{"ex":"kneeraises","mode":"reps","min":30}]}),
    ('TWIST AND PISTOL', '60 Russian twists and 6 pistol squats', 40, {"reqs":[{"ex":"twists","mode":"reps","min":60},{"ex":"pistols","mode":"reps","min":6}]}),
    ('EARLY RUN', '3 km before 09:00', 35, {"reqs":[{"ex":"run","mode":"km","min":3,"to_h":9}]}),
    ('BIKE TOUR', '10 km on the bike', 35, {"reqs":[{"ex":"bike","mode":"km","min":10}]}),
    ('SPRINT FINISHER', '10 sprints', 35, {"reqs":[{"ex":"sprints","mode":"reps","min":10}]}),
    ('LUNCH WALK', '3 km walk between 11:00 and 14:00', 25, {"reqs":[{"ex":"walk","mode":"km","min":3,"from_h":11,"to_h":14}]}),
    ('POOL SESSION', '30 minutes of swimming', 40, {"reqs":[{"ex":"swim","mode":"minutes","min":30}]}),
    ('FIVE K', 'Run 5 km', 40, {"reqs":[{"ex":"run","mode":"km","min":5}]}),
    ('DOUBLE MOBILITY', 'Two separate stretching sessions', 25, {"reqs":[{"ex":"stretch","mode":"flat","min":2}]}),
    ('NIGHT WALK', '4 km walk after 19:00', 30, {"reqs":[{"ex":"walk","mode":"km","min":4,"from_h":19}]}),
    ('SWIM AND STRETCH', '20 minutes swimming and a stretching session', 35, {"reqs":[{"ex":"swim","mode":"minutes","min":20},{"ex":"stretch","mode":"flat","min":1}]}),
    ('CYCLE CENTURY', '15 km on the bike', 40, {"reqs":[{"ex":"bike","mode":"km","min":15}]}),
    ('MORNING DISTANCE', '4 km run or 12 km bike before 11:00', 40, {"kind":"any","any":[{"ex":"run","mode":"km","min":4,"to_h":11},{"ex":"bike","mode":"km","min":12,"to_h":11}]}),
    ('FULL BODY TRIAD', '30 push-ups, 15 pull-ups and 30 air squats', 45, {"reqs":[{"ex":"pushups","mode":"reps","min":30},{"ex":"pullups","mode":"reps","min":15},{"ex":"airsquats","mode":"reps","min":30}]}),
    ('DUO SYNC', 'Train within an hour of somebody else in the league', 30, {"kind":"duo"}),
    ('IRON TRIFECTA', '20 dips, 10 pull-ups and 50 air squats', 45, {"reqs":[{"ex":"dips","mode":"reps","min":20},{"ex":"pullups","mode":"reps","min":10},{"ex":"airsquats","mode":"reps","min":50}]}),
    ('UNDERDOG BOOST', 'Last in the league this week? Log anything today', 50, {"kind":"underdog"}),
    ('MINI MURPH', '1.5 km run, 30 push-ups, 15 pull-ups, 45 air squats', 60, {"reqs":[{"ex":"run","mode":"km","min":1.5},{"ex":"pushups","mode":"reps","min":30},{"ex":"pullups","mode":"reps","min":15},{"ex":"airsquats","mode":"reps","min":45}]}),
    ('MIDDAY MADNESS', 'Two different exercises between 12:00 and 13:00', 30, {"kind":"distinct","what":"ex","min":2,"from_h":12,"to_h":13}),
    ('CENTURY CLUB', '100 reps spread across 3 different exercises', 40, {"kind":"reps_across","exercises":3,"min":100}),
    ('PERSONAL RECORD', 'Beat your own best single day of points', 50, {"kind":"pr"}),
    ('TEAM SURGE', 'If 4 of you log today, everybody scores', 30, {"kind":"team","members":4}),
    ('TRIPLE THREAT', 'Train three different muscle groups today', 40, {"kind":"distinct","what":"cat","min":3}),
    ('NIGHT OWL', 'Two different exercises after 21:00', 25, {"kind":"distinct","what":"ex","min":2,"from_h":21}),

    # ---- micro bounties: under three minutes, flat 20 --------------------
    ('MINUTE OF PUSH', 'As many push-ups as you can in one minute — 30 or more', 20, {"reqs":[{"ex":"pushups","mode":"reps","min":30}]}),
    ('THREE-MINUTE PLANK', 'Three minutes of plank, in as many goes as you like', 20, {"reqs":[{"ex":"plank","mode":"minutes","min":3}]}),
    ('SIXTY SQUATS', 'Sixty air squats — under two minutes if you keep moving', 20, {"reqs":[{"ex":"airsquats","mode":"reps","min":60}]}),
    ('DEAD HANG', 'Ninety seconds hanging from a bar', 20, {"reqs":[{"ex":"deadhang","mode":"seconds","min":90}]}),
    ('TEN PULL', 'Ten pull-ups. That is the whole bounty', 20, {"reqs":[{"ex":"pullups","mode":"reps","min":10}]}),
    ('WALL SIT', 'Two minutes in a wall sit', 20, {"reqs":[{"ex":"wallsit","mode":"seconds","min":120}]}),
    ('ROPE MINUTE', 'Five minutes of skipping', 20, {"reqs":[{"ex":"jumprope","mode":"minutes","min":5}]}),
    ('STAIR SPRINT', 'Five minutes of stairs', 20, {"reqs":[{"ex":"stairs","mode":"minutes","min":5}]}),
    ('HOLLOW HOLD', 'Ninety seconds of hollow hold', 20, {"reqs":[{"ex":"hollowhold","mode":"seconds","min":90}]}),
    ('BURST OF DIPS', 'Twenty dips, any bar or bench', 20, {"kind":"any","any":[{"ex":"dips","mode":"reps","min":20},{"ex":"benchdips","mode":"reps","min":30}]}),
    ('FORTY CRUNCH', 'Forty crunches', 20, {"reqs":[{"ex":"crunches","mode":"reps","min":40}]}),
    ('TWO MINUTES OF ANYTHING', 'Any two minutes of held work — plank, hang, wall sit or L-sit', 20, {"kind":"any","any":[{"ex":"plank","mode":"minutes","min":2},{"ex":"deadhang","mode":"seconds","min":120},{"ex":"wallsit","mode":"seconds","min":120},{"ex":"lsit","mode":"seconds","min":120}]}),

    # ---- one muscle group only, nothing else counts ----------------------
    ('PUSH DAY', '60 points of pushing and nothing else counts', 45, {"kind":"cat_points","cat":"PUSH","min":60}),
    ('PULL DAY', '50 points of pulling and nothing else counts', 45, {"kind":"cat_points","cat":"PULL","min":50}),
    ('LEG DAY', '60 points of legs and nothing else counts', 45, {"kind":"cat_points","cat":"LEGS","min":60}),
    ('CORE DAY', '45 points of core and nothing else counts', 40, {"kind":"cat_points","cat":"CORE","min":45}),
    ('ENDURANCE ONLY', '50 points of cardio and nothing else counts', 45, {"kind":"cat_points","cat":"CARDIO","min":50}),
    ('IRON ONLY', '60 points under a bar — gym lifts only', 50, {"kind":"cat_points","cat":"GYM","min":60}),
    ('PLAY DAY', '40 points from a sport', 40, {"kind":"cat_points","cat":"SPORT","min":40}),
    ('UPPER LOCK', '40 points of push and 40 of pull, same day', 55, {"kind":"cats","cats":[{"cat":"PUSH","min":40},{"cat":"PULL","min":40}]}),

    # ---- volume and skill ------------------------------------------------
    ('TWO HUNDRED', '200 push-ups across the day', 60, {"reqs":[{"ex":"pushups","mode":"reps","min":200}]}),
    ("ARCHER'S DAY", '30 archer push-ups', 45, {"reqs":[{"ex":"archerpush","mode":"reps","min":30}]}),
    ('PIKE POWER', '40 pike push-ups', 40, {"reqs":[{"ex":"pikepush","mode":"reps","min":40}]}),
    ('CLAP IT OUT', '25 clapping push-ups', 45, {"reqs":[{"ex":"clappush","mode":"reps","min":25}]}),
    ('RING WORK', '25 ring dips', 50, {"reqs":[{"ex":"ringdips","mode":"reps","min":25}]}),
    ('CHIN COLLECTOR', '40 chin-ups', 50, {"reqs":[{"ex":"chinups","mode":"reps","min":40}]}),
    ('TOES TO BAR', '30 toes to bar', 45, {"reqs":[{"ex":"toestobar","mode":"reps","min":30}]}),
    ('FRONT LEVER HOLD', '20 seconds of front lever, any tuck', 50, {"reqs":[{"ex":"frontlever","mode":"seconds","min":20}]}),
    ('DRAGON', '15 dragon flags', 50, {"reqs":[{"ex":"dragonflag","mode":"reps","min":15}]}),
    ('PISTOL DUEL', '20 pistol squats', 45, {"reqs":[{"ex":"pistols","mode":"reps","min":20}]}),
    ('NORDIC NIGHT', '12 nordic curls', 50, {"reqs":[{"ex":"nordic","mode":"reps","min":12}]}),
    ('JUMP DAY', '80 jump squats', 45, {"reqs":[{"ex":"jumpsquats","mode":"reps","min":80}]}),
    ('LUNGE MILE', '120 lunges', 45, {"reqs":[{"ex":"lunges","mode":"reps","min":120}]}),
    ('BRIDGE BUILDER', '100 glute bridges', 35, {"reqs":[{"ex":"gluteBridge","mode":"reps","min":100}]}),
    ('ROLLOUT', '30 ab rollouts', 40, {"reqs":[{"ex":"rollout","mode":"reps","min":30}]}),
    ('SIDE ON', 'Three minutes of side plank, both sides', 35, {"reqs":[{"ex":"sideplank","mode":"minutes","min":3}]}),
    ('SUPERMAN', '80 supermans', 30, {"reqs":[{"ex":"supermans","mode":"reps","min":80}]}),
    ('BICYCLE RACE', '150 bicycle crunches', 35, {"reqs":[{"ex":"bicycle","mode":"reps","min":150}]}),
    ('CLIMBER', '200 mountain climbers', 35, {"reqs":[{"ex":"mountainclimb","mode":"reps","min":200}]}),
    ('TEN K', 'Ten kilometres on foot, running or walking', 55, {"kind":"any","any":[{"ex":"run","mode":"km","min":10},{"ex":"walk","mode":"km","min":12}]}),
    ('LONG RIDE', '25 km on a bike', 45, {"reqs":[{"ex":"bike","mode":"km","min":25}]}),
    ('POOL LENGTHS', '45 minutes in the water', 45, {"reqs":[{"ex":"swim","mode":"minutes","min":45}]}),
    ('ROW HARD', '20 minutes on the rower', 40, {"reqs":[{"ex":"row","mode":"minutes","min":20}]}),
    ('ON THE WALL', '40 minutes of climbing', 45, {"reqs":[{"ex":"climbing","mode":"minutes","min":40}]}),
    ('GLOVES ON', '30 minutes of boxing', 40, {"reqs":[{"ex":"boxing","mode":"minutes","min":30}]}),
    ('BENCH DAY', '30 reps of barbell bench press', 45, {"reqs":[{"ex":"gymbench","mode":"reps","min":30}]}),
    ('SQUAT RACK', '40 barbell squats', 45, {"reqs":[{"ex":"gymsquat","mode":"reps","min":40}]}),
    ('PULL THE FLOOR', '20 deadlifts', 50, {"reqs":[{"ex":"gymdeadlift","mode":"reps","min":20}]}),
    ('SEVEN HOURS', 'One set in each of 7 different hours', 50, {"kind":"hourly","ex":"pushups","each":5,"hours":7}),
    ('SUNRISE AND SUNSET', '30 pull-ups before noon and 30 after', 50, {"kind":"split","ex":"pullups","min":30}),
    ('FIVE WAYS', 'Train five different muscle groups', 50, {"kind":"distinct","what":"cat","min":5}),
    ('TEN EXERCISES', 'Ten different exercises in one day', 45, {"kind":"distinct","what":"ex","min":10}),
    ('SPREAD THE LOAD', '300 reps across at least 6 exercises', 55, {"kind":"reps_across","exercises":6,"min":300}),
    ('BEAT YESTERDAY', 'Score more points today than on any day before it', 45, {"kind":"pr"}),
    ('SIX OF YOU', 'Six people in the league log something today', 45, {"kind":"team","members":6}),
    ('FULL HOUSE', 'Ten people in the league log something today', 60, {"kind":"team","members":10}),
    ('TRAINING PARTNER', 'Log within an hour of somebody else in the league', 35, {"kind":"duo"}),
    ('BACK FROM THE DEAD', 'Bottom of the table and still turned up', 40, {"kind":"underdog"}),
]
