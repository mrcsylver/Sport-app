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
    ('SHOULDER BURN', '30 pike push-ups', 40, {"reqs":[{"ex":"pikepush","mode":"reps","min":30}]}),
    ('CLOSE QUARTERS', '35 diamond push-ups', 35, {"reqs":[{"ex":"diamondpush","mode":"reps","min":35}]}),
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
    ('ANY BAR WILL DO', '20 pull-ups, 20 chin-ups, or 40 inverted rows', 50, {"kind":"any","any":[{"ex":"pullups","mode":"reps","min":20},{"ex":"chinups","mode":"reps","min":20},{"ex":"rows","mode":"reps","min":40}]}),
    ('EVENING LATS', '20 pull-ups after 18:00', 35, {"reqs":[{"ex":"pullups","mode":"reps","min":20,"from_h":18}]}),
    ('GREASE THE GROOVE', '1 pull-up in each of 8 different hours', 40, {"kind":"hourly","ex":"pullups","each":1,"hours":8}),
    ('PULL DOUBLE', '15 pull-ups before noon and 15 after', 45, {"kind":"split","ex":"pullups","min":15}),
    ('MORNING LEGS', '100 air squats before 10:00', 35, {"reqs":[{"ex":"airsquats","mode":"reps","min":100,"to_h":10}]}),
    ('SPLIT DUTY', '50 split squats', 40, {"reqs":[{"ex":"splitsquat","mode":"reps","min":50}]}),
    ('STEP MACHINE', '100 step-ups', 45, {"reqs":[{"ex":"stepups","mode":"reps","min":100}]}),
    ('CORE LOCK', '2 minutes of plank', 30, {"reqs":[{"ex":"plank","mode":"minutes","min":2}]}),
    ('KNEE RAISE SURGE', '60 knee raises', 35, {"reqs":[{"ex":"kneeraises","mode":"reps","min":60}]}),
    ('THE HOLLOW', 'Four minutes of hollow hold', 40, {"reqs":[{"ex":"hollowhold","mode":"seconds","min":240}]}),
    ('SQUAT CENTURY', '100 air squats', 30, {"reqs":[{"ex":"airsquats","mode":"reps","min":100}]}),
    ('AFTERNOON LEGS', '80 air squats between 13:00 and 17:00', 30, {"reqs":[{"ex":"airsquats","mode":"reps","min":80,"from_h":13,"to_h":17}]}),
    ('CORE AND SQUAT', '50 air squats and 30 knee raises', 35, {"reqs":[{"ex":"airsquats","mode":"reps","min":50},{"ex":"kneeraises","mode":"reps","min":30}]}),
    ('TWIST AND SQUAT', '60 Russian twists and 60 air squats', 45, {"reqs":[{"ex":"twists","mode":"reps","min":60},{"ex":"airsquats","mode":"reps","min":60}]}),
    ('EARLY RUN', '3 km before 09:00', 35, {"reqs":[{"ex":"run","mode":"km","min":3,"to_h":9}]}),
    ('WALK IT OFF', '6 km on foot', 35, {"reqs":[{"ex":"walk","mode":"km","min":6}]}),
    ('SPRINT FINISHER', '10 sprints', 35, {"reqs":[{"ex":"sprints","mode":"reps","min":10}]}),
    ('LUNCH WALK', '3 km walk between 11:00 and 14:00', 25, {"reqs":[{"ex":"walk","mode":"km","min":3,"from_h":11,"to_h":14}]}),
    ('THE LONG WALK', '10 km of walking', 45, {"reqs":[{"ex":"walk","mode":"km","min":10}]}),
    ('FIVE K', 'Run 5 km', 40, {"reqs":[{"ex":"run","mode":"km","min":5}]}),
    ('DOUBLE MOBILITY', 'Two separate stretching sessions', 25, {"reqs":[{"ex":"stretch","mode":"flat","min":2}]}),
    ('NIGHT WALK', '4 km walk after 19:00', 30, {"reqs":[{"ex":"walk","mode":"km","min":4,"from_h":19}]}),
    ('MOVE AND STRETCH', '3 km on foot and a stretching session', 35, {"reqs":[{"ex":"walk","mode":"km","min":3},{"ex":"stretch","mode":"flat","min":1}]}),
    ('ROAD WORK', '6 km run', 45, {"reqs":[{"ex":"run","mode":"km","min":6}]}),
    ('MORNING DISTANCE', '4 km run or 6 km walk before 11:00', 40, {"kind":"any","any":[{"ex":"run","mode":"km","min":4,"to_h":11},{"ex":"walk","mode":"km","min":6,"to_h":11}]}),
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
    ('MOUNTAIN MINUTE', '150 mountain climbers', 20, {"reqs":[{"ex":"mountainclimb","mode":"reps","min":150}]}),
    ('TEN SPRINTS', 'Ten sprints', 20, {"reqs":[{"ex":"sprints","mode":"reps","min":10}]}),
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
    ('LEGS AND CORE', '50 points of legs and 40 of core, nothing else counts', 50, {"kind":"cats","cats":[{"cat":"LEGS","min":50},{"cat":"CORE","min":40}]}),
    ('FULL BODY LOCK', '30 points each of push, pull and legs', 55, {"kind":"cats","cats":[{"cat":"PUSH","min":30},{"cat":"PULL","min":30},{"cat":"LEGS","min":30}]}),
    ('UPPER LOCK', '40 points of push and 40 of pull, same day', 55, {"kind":"cats","cats":[{"cat":"PUSH","min":40},{"cat":"PULL","min":40}]}),

    # ---- volume and skill ------------------------------------------------
    ('TWO HUNDRED', '200 push-ups across the day', 60, {"reqs":[{"ex":"pushups","mode":"reps","min":200}]}),
    ('WIDE LOAD', '60 wide push-ups', 45, {"reqs":[{"ex":"widepush","mode":"reps","min":60}]}),
    ('PIKE POWER', '40 pike push-ups', 40, {"reqs":[{"ex":"pikepush","mode":"reps","min":40}]}),
    ('DECLINE DAY', '50 decline push-ups', 45, {"reqs":[{"ex":"declinepush","mode":"reps","min":50}]}),
    ('CHAIR DIPS', '70 bench dips', 50, {"reqs":[{"ex":"benchdips","mode":"reps","min":70}]}),
    ('CHIN COLLECTOR', '40 chin-ups', 50, {"reqs":[{"ex":"chinups","mode":"reps","min":40}]}),
    ('HANGING RAISES', '30 hanging leg raises', 45, {"reqs":[{"ex":"hangingleg","mode":"reps","min":30}]}),
    ('THREE MINUTE HANG', 'Three minutes hanging from a bar', 50, {"reqs":[{"ex":"deadhang","mode":"seconds","min":180}]}),
    ('V FOR VOLUME', '80 V-ups', 50, {"reqs":[{"ex":"vups","mode":"reps","min":80}]}),
    ('JUMP AND HOLD', '60 jump squats and two minutes of wall sit', 45, {"reqs":[{"ex":"jumpsquats","mode":"reps","min":60},{"ex":"wallsit","mode":"seconds","min":120}]}),
    ('BRIDGE AND BIRD', '120 glute bridges and 60 bird dogs', 50, {"reqs":[{"ex":"gluteBridge","mode":"reps","min":120},{"ex":"birddog","mode":"reps","min":60}]}),
    ('JUMP DAY', '80 jump squats', 45, {"reqs":[{"ex":"jumpsquats","mode":"reps","min":80}]}),
    ('LUNGE MILE', '120 lunges', 45, {"reqs":[{"ex":"lunges","mode":"reps","min":120}]}),
    ('BRIDGE BUILDER', '100 glute bridges', 35, {"reqs":[{"ex":"gluteBridge","mode":"reps","min":100}]}),
    ('SIT UP STRAIGHT', '120 sit-ups', 40, {"reqs":[{"ex":"situps","mode":"reps","min":120}]}),
    ('SIDE ON', 'Three minutes of side plank, both sides', 35, {"reqs":[{"ex":"sideplank","mode":"minutes","min":3}]}),
    ('SUPERMAN', '80 supermans', 30, {"reqs":[{"ex":"supermans","mode":"reps","min":80}]}),
    ('BICYCLE RACE', '150 bicycle crunches', 35, {"reqs":[{"ex":"bicycle","mode":"reps","min":150}]}),
    ('CLIMBER', '200 mountain climbers', 35, {"reqs":[{"ex":"mountainclimb","mode":"reps","min":200}]}),
    ('TEN K', 'Ten kilometres on foot, running or walking', 55, {"kind":"any","any":[{"ex":"run","mode":"km","min":10},{"ex":"walk","mode":"km","min":12}]}),
    ('THE LONG ONE', '12 km running, or 15 km walking', 45, {"kind":"any","any":[{"ex":"run","mode":"km","min":12},{"ex":"walk","mode":"km","min":15}]}),
    ('FLUTTER', '200 flutter kicks', 45, {"reqs":[{"ex":"flutterkick","mode":"reps","min":200}]}),
    ('ROW YOUR OWN', '80 inverted rows', 40, {"reqs":[{"ex":"rows","mode":"reps","min":80}]}),
    ('AGAINST THE WALL', 'Five minutes of wall sit', 45, {"reqs":[{"ex":"wallsit","mode":"seconds","min":300}]}),
    ('SHADOW WORK', '300 mountain climbers', 40, {"reqs":[{"ex":"mountainclimb","mode":"reps","min":300}]}),
    ('PUSH ONE FIFTY', '150 push-ups across the day', 45, {"reqs":[{"ex":"pushups","mode":"reps","min":150}]}),
    ('TWO HUNDRED SQUATS', '200 air squats', 45, {"reqs":[{"ex":"airsquats","mode":"reps","min":200}]}),
    ('FIFTY PULLS', '50 pull-ups across the day', 55, {"reqs":[{"ex":"pullups","mode":"reps","min":50}]}),
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
