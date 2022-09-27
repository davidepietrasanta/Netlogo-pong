extensions [table csv]


globals [
  paddle-size   ;; size of the paddles [ default 5 ]
  score-1       ;; score player 1
  score-2       ;; score player 2
  round-over?   ;; check if the round is over
  step

  curr-state    ;; current state
  curr-episode  ;; current episode number
  curr-reward   ;; current reward

  ;; learning parameters

  epsilon
  min-epsilon   ;; min exploration rate
  max-epsilon   ;; max exploration rate
  decay-rate    ;; decay rate epsilon
  quality       ;; quality matrix

  ;; metrics

  steps-per-episode      ;; steps per episode

  reward-per-episode     ;; reward per episode
  reward-smooth          ;; needed for the smooth plot of reward per episode
  reward-smooth-list     ;; needed for the smooth plot of reward per episode
  avg-reward-per-episode ;; the sum of all the reward per episode

  bounces-per-round        ;; number of bounces on the paddles in a round
  bounces-per-episode      ;; average number of bounces on the paddles of all steps in a episode
  avg-bounces              ;; average bounces per point
  avg-bounces-smooth       ;; needed for the smooth plot of average bounces per point
  avg-bounces-smooth-list  ;; needed for the smooth plot of average bounces per point
  avg-bounces-per-episode  ;; the sum of all the paddle-bounces per episode

  score-smooth
  score-smooth-list

  test-avg-score
  test-std-score
]

breed [balls ball]
breed [paddles paddle]

paddles-own [
  id      ;; player 1 or 2
  ;xcor    ;; x coordinate of paddle
  ;ycor    ;; y coordinate of paddle
]

balls-own [
  id     ;; ball's id
  ;xcor    ;; x coordinate of ball
  ;ycor    ;; y coordinate of ball
  ;heading ;; direction of ball
]

;; SETUP -----------------------------------------------------------------

to setup
  clear-all

  set-default-shape balls "circle"
  set-default-shape paddles "paddle"

  set score-1 0
  set score-2 0
  set round-over? true
  set paddle-size 3
  set smoother 50

  ;; setup-episode
  set epsilon 1
  set random-move-prob 0.3
  set episodes 5000

  set min-epsilon 0.01
  set max-epsilon 1.0
  set decay-rate 0.0005

  set curr-episode 0
  set step 0
  set gamma 0.9
  set lr 0.1

  set avg-bounces []
  set avg-bounces-smooth []
  set avg-bounces-smooth-list []

  set reward-per-episode 0
  set reward-smooth []
  set reward-smooth-list []

  set score-smooth []
  set score-smooth-list []

  set curr-state (list 0 0 0)
  if state-type = "with-opponent-x" [
    set curr-state (list 0 0 0 0)
  ]

  set quality table:make
  init-quality

  setup-turtles
  setup-ball

  reset-ticks
end

;; init the paddles to their side of the field centered
to setup-turtles
  ask paddles [die]  ;; destroy previous paddles

  ;; player 1 - learning agent
  create-paddles 1 [
    setxy 0 (min-pycor + 1)
    set id 1
    set size paddle-size
    set color red
  ]

  ;; player 2 - random agent
  create-paddles 1 [
    setxy 0 (max-pycor - 1)
    set id 2
    set size paddle-size
    set color blue
  ]
end

;; init the ball to the center of the field
to setup-ball
  ask balls [die]  ;; destroy previous balls
  create-balls 1 [
    setxy 0 0
    ;; 0 is north, 90 is east, and so on
    ;; avoid east(90) and west(270) to not get stucked
    ;; we also want to avoid angle too close to 90 and 270
    ;; we chose in [-45, +45] and [+135, +225]
    set heading (-45 + random 91) + (random 2 * 180)
    set color white
    set id 0
  ]
end

to init-quality
  foreach (range min-pxcor (max-pxcor + 1)) [ ball-x ->
    foreach (range (min-pycor + 1) max-pycor) [ ball-y ->
      foreach (range (min-pxcor + 1) max-pxcor) [ paddle-x ->

        ifelse state-type = "with-opponent-x" [
          foreach (range (min-pxcor + 1) max-pxcor) [ opponent-x ->
            let key (list ball-x ball-y paddle-x opponent-x)
            table:put quality key [0 0]
          ]
        ][
          let key (list ball-x ball-y paddle-x)
          table:put quality key [0 0]
        ]
      ]
    ]
  ]
end

to load
  load-quality
end

;; check if the game is over
to-report game-over?
  report score-1 = 21 or score-2 = 21
end


;; PADDLES UPDATE ---------------------------------------------------------

to move-paddle-with-direction [speed direction]
  set heading (ifelse-value direction = "sx" [-90] [90])
  fd speed
end

to move-paddle-left [speed]
  move-paddle-with-direction speed "sx"
end

to move-paddle-right [speed]
  move-paddle-with-direction speed "dx"
end

to constrain-paddles
  ask paddles [
    if round(xcor) = max-pxcor [
      move-paddle-left 1
    ]

    if round(xcor) = min-pxcor [
      move-paddle-right 1
    ]
  ]
end

;; learning agent behavior
to move-learning-agent [action]
  ask paddles with [id = 1] [
    ifelse action = 0
      [ move-paddle-left 1 ]
      [ move-paddle-right 1 ]
  ]

  constrain-paddles
end

;; scripted AI agent behavior
to move-scripted-agent
  ;; Ask ball info
  let ball-x 0
  let ball-y 0
  let ball-dir 1 ; avoid 0 degree
  ask balls with [id = 0] [
    set ball-x (round xcor)
    set ball-y (round ycor)
    set ball-dir heading
  ]

  ask paddles with [id = 2] [
    ifelse random-float 1 > random-move-prob
    [
      ;; otherwise the scripted agent follow the ball.
      if xcor < ball-x [
        move-paddle-right 1
      ]

      if xcor > ball-x [
        move-paddle-left 1
      ]
    ]
    [
      ;; when the scripted agent fail select a random action.
      ifelse int(random 2) = 0
      [ move-paddle-left 1 ]
      [ move-paddle-right 1 ]
    ]

  ]

  ;; avoid collision with the wall
  constrain-paddles
end


;; BALL UPDATE ------------------------------------------------------------
to move-ball
  ask balls [
    ;; near a paddle patch
    if (paddle-ahead?) [
      set heading (180 - heading) ;; bounce to the paddle
      set bounces-per-round (bounces-per-round + 1)
    ]

    ;; left wall or right wall
    if (round(pxcor) = min-pxcor or round(pxcor) = max-pxcor) [
      set heading (- heading) ;; bounce to the wall
    ]

    fd 1  ;; forward in the heading direction
  ]
end

to-report paddle-ahead?
  let paddles-ahead paddles with [pxcor + 2 >= [pxcor] of myself and pxcor - 2 <= [pxcor] of myself]

  ifelse heading > 270 or heading < 90 [
    set paddles-ahead paddles-ahead with [pycor = [pycor] of myself + 1]
  ][
   set paddles-ahead paddles-ahead with [pycor = [pycor] of myself - 1]
  ]

  report any? paddles-ahead
end

;; STATE
to-report get-state
  ;; Ask ball info
  let ball-x 0
  let ball-y 0
  let ball-dir 1  ;; avoid 0 degree
  ask balls with [id = 0] [
    set ball-x xcor
    set ball-y ycor
    set ball-dir heading
  ]

  let paddle-x 0
  ask paddles with [id = 1] [
    set paddle-x xcor
  ]

  let state []

  ifelse state-type = "with-opponent-x" [
    let opponent-x 0
    ask paddles with [id = 2] [
      set opponent-x xcor
    ]

    ;; set state (lower-complexity ball-x ball-y ball-dir paddle-x opponent-x)
    set state (lower-complexity ball-x ball-y 0 paddle-x opponent-x)
  ][
    ;; set state (lower-complexity ball-x ball-y ball-dir paddle-x "none")
    set state (lower-complexity ball-x ball-y 0 paddle-x "none")
  ]

  report state
end

to-report lower-complexity [ball-x ball-y ball-dir paddle-x opponent-x]
  let xb round(ball-x)
  let yb round(ball-y)
  let xp paddle-x

  if opponent-x != "none" [
    let xo opponent-x
    report (list xb yb xp xo)
  ]

  report (list xb yb xp)
end


;; SARSA -----------------------------------------------------------------

to start-episodes-sarsa
  ifelse curr-episode < episodes [
    reset-episode
    run-episode "sarsa"
    tick

    ;; exploration/eploitation rate decay
    set epsilon (min-epsilon + ((max-epsilon - min-epsilon) * exp(- decay-rate * curr-episode)))

    set curr-episode (curr-episode + 1)
  ][
    stop
  ]
end


;; Q-LEARNING ------------------------------------------------------------

to start-episodes-q-learning
  ifelse curr-episode < episodes [
    reset-episode
    run-episode "q-learning"
    tick

    ;; exploration/eploitation rate decay
    set epsilon (min-epsilon + ((max-epsilon - min-epsilon) * exp(- decay-rate * curr-episode)))

    set curr-episode (curr-episode + 1)
  ][
    stop
  ]
end

;; CORE Q-LEARNING AND SARSA ------------------------------------------------------------

to run-episode [mode]
  set step 0
  let step-per-round 0
  let new-quality 0
  let next_action 0
  let action 0

  ;; the state before the action is performed
  set curr-state get-state

  if mode = "sarsa" [set action choose-action curr-state]

  while [not game-over?] [

    ;; the state before the action is performed
    set curr-state get-state

    ;; exploitation/exploration action
    if mode = "q-learning"[set action choose-action curr-state]
    if mode = "sarsa" [set next_action choose-action curr-state]

    ;; perform the action
    update-graphics curr-state action

     ;; get the state after the ball moved
    let new-state get-state

    let winner check-win-conditions new-state

    ;; the immediate reward
    let reward winner ;; +1 if it score, -1 if it loose, 0 otherwise

    if reward-type = "distance" [
      let ball-x item 0 new-state ;??????
      let paddle-x item 2 new-state ;??????

      ; set reward reward * 100

      let dist (abs paddle-x - ball-x)
      ifelse dist = 0 [
        set reward reward + (1)
      ][
        set reward reward + (1 / dist)
      ]
    ]

    let next-actions (table:get quality new-state)

    let curr-quality (item action (table:get quality curr-state))  ;; Q(s, a)

    if mode = "sarsa"
    [
      ;; Q(s,a) := Q(s,a) + lr [R(s,a) + gamma * Q(s',a') - Q(s,a)]
      set new-quality curr-quality + lr * ((reward + gamma * item next_action next-actions) - curr-quality)
    ]
    if mode = "q-learning"
    [
      ;; Q(s,a) := Q(s,a) + lr [R(s,a) + gamma * max Q(s',a') - Q(s,a)]
      set new-quality curr-quality + lr * ((reward + gamma * max next-actions) - curr-quality)
    ]

    ;; set the new quality for the current state given the action
    let curr-actions (table:get quality curr-state)
    set curr-actions (replace-item action curr-actions new-quality)

    table:put quality curr-state curr-actions

    if mode = "sarsa" [set action next_action]

    ;; update metrics
    set curr-reward reward
    set reward-per-episode (reward-per-episode + reward)
    set steps-per-episode (steps-per-episode + 1)

    set step (step + 1)
    set step-per-round (step-per-round + 1)

    ;; when round ended
    if winner != 0 [
      set bounces-per-episode (bounces-per-episode + (bounces-per-round * step-per-round))
      set step-per-round 0
      set bounces-per-round 0
    ]
  ]

  set avg-bounces lput (bounces-per-episode / step) avg-bounces

  ;; For the smooth plot of reward-per-episode
  set reward-smooth-list lput reward-per-episode reward-smooth-list
  if (length reward-smooth-list = smoother)[
    set reward-smooth lput mean(reward-smooth-list) reward-smooth
    set reward-smooth-list []
  ]

  ;; Update the sum of the avg reward per episode
  set avg-reward-per-episode avg-reward-per-episode + reward-per-episode

  ;; For the smooth plot of avg-bounces
  set avg-bounces-smooth-list lput (bounces-per-episode / step) avg-bounces-smooth-list
  if (length avg-bounces-smooth-list = smoother)[
    set avg-bounces-smooth lput mean(avg-bounces-smooth-list) avg-bounces-smooth
    set avg-bounces-smooth-list []
  ]

  ;; Update the sum of the avg bounces per episode
  set avg-bounces-per-episode avg-bounces-per-episode + (bounces-per-episode / step)

  set score-smooth-list lput (score-1 - score-2) score-smooth-list
  if (length score-smooth-list = smoother)[
    set score-smooth lput mean(score-smooth-list) score-smooth
    set score-smooth-list []
  ]

  ;; Time optimization
  if (curr-episode mod 5000) = 0 [
    save-quality
    csv:to-file (word "./quality_" curr-episode ".csv") table:to-list quality
  ]

end


;; Q-LEARNING AND SARSA ------------------------------------------------------------

to reset-episode
  setup-turtles
  set reward-per-episode 0
  set steps-per-episode 0
  set bounces-per-episode 0
  set bounces-per-round 0

  set score-1 0
  set score-2 0

  reset-ticks
end

;; called every tick while the episode is not over
;; update the graphics and return the current state
to update-graphics [state action]
  ifelse round-over? [
    setup-ball
    set round-over? false
  ] [
    move-learning-agent action
    move-scripted-agent
    move-ball
  ]
  tick
end

to-report get-best-action [state]
  ;; get quality values for each action given the current state
  let row table:get quality state

  report ifelse-value (item 0 row = 0 and item 1 row = 0)
    [random 2] ;; If the value is the same we choose randomly
  [ ifelse-value (item 0 row > item 1 row)
    [0]
    [1]
  ]
end

to-report choose-action [state]
  ifelse random-float 1 > epsilon [
    report get-best-action state
  ][
    report int(random 2)
  ]
end

to-report check-win-conditions [state]
  let winner 0

  let ball-y item 1 state

  ;; bottom wall
  if (ball-y = (min-pycor + 1)) [
    set score-2 score-2 + 1
    set round-over? true
    set winner -1
  ]

  ;; top wall
  if (ball-y = (max-pycor - 1)) [
    set score-1 score-1 + 1
    set round-over? true
    set winner 1
  ]

  report winner
end

to save-quality
  csv:to-file "./quality.csv" table:to-list quality
end

to load-quality
  let l csv:from-file "./quality.csv"

  ;; parse lists
  set l map [x -> (list read-from-string (item 0 x) read-from-string (item 1 x))] l

  ;; reconstruct the matrix
  set quality table:from-list l
end

;; PLAY -----------------------------------------------------------------

;; Just play one match, without learning
to play
  while [not game-over?] [
    ;; the state before the action is performed
    set curr-state get-state

    ;; exploitation/exploration action
    let action get-best-action curr-state

    update-graphics curr-state action

    ;; get the state after the ball moved
    let new-state get-state

    let winner check-win-conditions new-state
  ]
  stop
end

;; TEST -----------------------------------------------------------------

;; Just play 1000 matches, without learning
to test
  set test-avg-score 0
  set test-std-score 0
  let list-scores []
  let test-episodes 100

  while [curr-episode < test-episodes] [
    while [not game-over?] [
      ;; the state before the action is performed
      set curr-state get-state

      ;; exploitation/exploration action
      let action get-best-action curr-state

      update-graphics curr-state action

      ;; get the state after the ball moved
      let new-state get-state

      let winner check-win-conditions new-state
    ]
    set curr-episode curr-episode + 1
    set list-scores lput (score-1 - score-2) list-scores
    reset-episode
  ]
  set test-avg-score mean list-scores
  set test-std-score standard-deviation list-scores

  stop
end
@#$#@#$#@
GRAPHICS-WINDOW
360
95
752
352
-1
-1
22.6
1
10
1
1
1
0
1
1
1
-8
8
-5
5
1
1
1
ticks
30.0

MONITOR
680
362
752
423
Score 1
score-1
0
1
15

MONITOR
676
15
751
76
Score 2
score-2
0
1
15

BUTTON
16
16
116
60
Setup
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
324
178
357
random-move-prob
random-move-prob
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
16
285
178
318
episodes
episodes
0
200000
5000.0
10000
1
NIL
HORIZONTAL

SLIDER
187
450
339
483
smoother
smoother
1
1000
50.0
50
1
NIL
HORIZONTAL

PLOT
790
14
1191
180
Reward per episode (smooth)
episodes
avg reward
0.0
10.0
-21.0
21.0
true
false
"" ""
PENS
"pen-0" 1.0 0 -7500403 true "" "if enable-plots [\n clear-plot\n let indexes (n-values length reward-smooth [i -> i])\n (foreach indexes reward-smooth[[x y] -> plotxy x y])\n]"

TEXTBOX
480
384
694
414
Player1 (learning agent)
12
0.0
1

TEXTBOX
473
37
636
67
Player2 (scripted agent)
12
0.0
1

PLOT
789
192
1191
345
Average paddle bounces per point (smooth)
episodes
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if enable-plots [\n  clear-plot\n  let indexes (n-values length avg-bounces-smooth [i -> i])\n  (foreach indexes avg-bounces-smooth [[x y] -> plotxy x y])\n]"

BUTTON
16
66
116
110
Load
load
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
240
16
340
61
Episode
curr-episode + 1
0
1
11

BUTTON
128
66
228
110
Play
play
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1197
14
1289
59
avg reward
avg-reward-per-episode / curr-episode
5
1
11

MONITOR
1199
192
1288
237
avg bounces
avg-bounces-per-episode / curr-episode
5
1
11

PLOT
788
353
1192
486
Score 1 - Score 2
NIL
NIL
0.0
0.0
-21.0
21.0
true
false
"" ""
PENS
"pen-1" 1.0 0 -2674135 true "" "if enable-plots [\n  clear-plot\n  let indexes (n-values length score-smooth [i -> i])\n  (foreach indexes score-smooth [[x y] -> plotxy x y])\n]"

BUTTON
240
66
340
110
Test
test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
451
440
598
485
NIL
test-avg-score
17
1
11

CHOOSER
16
206
178
251
algorithm
algorithm
"Q-Learning" "SARSA"
0

BUTTON
128
16
228
60
Learn
ifelse algorithm = \"Q-Learning\" [\n  start-episodes-q-learning\n][\n  start-episodes-sarsa\n]\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
16
156
178
201
state-type
state-type
"with-opponent-x" "without-opponent-x"
1

SWITCH
16
450
177
483
enable-plots
enable-plots
1
1
-1000

CHOOSER
184
156
346
201
reward-type
reward-type
"basic" "distance"
0

MONITOR
16
374
178
419
NIL
epsilon
17
1
11

SLIDER
184
285
338
318
gamma
gamma
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
184
324
338
357
lr
lr
0
1
0.1
0.1
1
NIL
HORIZONTAL

TEXTBOX
16
430
175
448
plots
12
0.0
1

TEXTBOX
16
262
175
280
parameters
12
0.0
1

TEXTBOX
16
132
176
150
configuration
12
0.0
1

MONITOR
605
440
751
485
NIL
test-std-score
17
1
11

@#$#@#$#@
## WHAT IS IT?

Simple netlogo implementation of a learning agent playing pong.
The Q-learning and SARSA algorithms have been implemented.

## HOW IT WORKS

The agent can use Q-learning and SARSA to build a policy.

## HOW TO USE IT

### PLAY

If you want to see how an agent plays pong against a Scripted AI just do `SETUP`, `LOAD` (optional) and then `PLAY`.
This way the agent is not learning but simply playing the best action based on the quality matrix (quality.csv).
If you don't press `LOAD` the agent operates with an empty quality matrix (zeros only).
In the `pong_exp` folder you can find quality matrices (quality_20k_episodes_rnd-prob-0.1.csv, etc.). By renaming them to `quality.csv` and putting them in the directory where the netlogo code is (pong.nlogo) you can see how the agent plays.

### LEARN

You can generate your own quality matrix by doing `SETUP`, `LOAD` (optional), select the `algorithm` between SARSA and Q-Learning and then press `LEARN`.
This way the agent is learning and generating a quality matrix (quality.csv).
If you don't press `LOAD` the learning starts with an empty quality matrix (zeros only).

### CONFIGURATION

#### Algorithm

You can choose whether the learning algorithm will be `Q-Learning` or `SARSA`.

#### State-type

You can choose whether, during learning, the opponent's state, that is the coordinate x, is known to the agent or not.

#### Reward-type

You can choose between two types of rewards.
The `basic` reward is a reward that gives +1 in case of victory and -1 in case of defeat.
The reward `distance` is based the basic reward but it also takes into accout the distance of the ball bounce from the center of the paddle.

## EXTENDING THE MODEL

Replaced the scripted AI with a learning agent.
Replaced the scripted AI with a human player.

## CREDITS AND REFERENCES

GitHub: https://github.com/davidepietrasanta/Netlogo-pong

Created by:
* Davide Pietrasanta
* Giuseppe Magazzù
* Gaetano Magazzù
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dollar bill
false
0
Rectangle -7500403 true true 15 90 285 210
Rectangle -1 true false 30 105 270 195
Circle -7500403 true true 120 120 60
Circle -7500403 true true 120 135 60
Circle -7500403 true true 254 178 26
Circle -7500403 true true 248 98 26
Circle -7500403 true true 18 97 36
Circle -7500403 true true 21 178 26
Circle -7500403 true true 66 135 28
Circle -1 true false 72 141 16
Circle -7500403 true true 201 138 32
Circle -1 true false 209 146 16
Rectangle -16777216 true false 64 112 86 118
Rectangle -16777216 true false 90 112 124 118
Rectangle -16777216 true false 128 112 188 118
Rectangle -16777216 true false 191 112 237 118
Rectangle -1 true false 106 199 128 205
Rectangle -1 true false 90 96 209 98
Rectangle -7500403 true true 60 168 103 176
Rectangle -7500403 true true 199 127 230 133
Line -7500403 true 59 184 104 184
Line -7500403 true 241 189 196 189
Line -7500403 true 59 189 104 189
Line -16777216 false 116 124 71 124
Polygon -1 true false 127 179 142 167 142 160 130 150 126 148 142 132 158 132 173 152 167 156 164 167 174 176 161 193 135 192
Rectangle -1 true false 134 199 184 205

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

paddle
false
0
Rectangle -1 true false 0 120 300 180

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
