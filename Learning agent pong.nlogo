extensions [table]
__includes ["qlearning.nls"]

breed [balls ball]
breed [paddles paddle]

globals [
  score_1    ;; score player 1
  score_2    ;; score player 2
  game-over? ;; check if the game is over
  playing?   ;; check if we are playing
  games      ;; to store matches history
  last-winner ;; the last winner (player id)
  not-random-move ;; count the non random move made with markov
  l
  r
  total-move
]

paddles-own [
  id_p   ;; player 1 or 2
  match  ;; to store one match
  ;;[default]
  ;; y coordinate of paddle is useless
  ;xcor    ;; x coordinate of paddle
]

balls-own [
  id_b     ;; ball's id
  ;;[default]
  ;xcor    ;; x coordinate of ball
  ;ycor    ;; y coordinate of ball
  ;heading ;; direction of ball
]



;; ------------------------------------------------------------------------

to reset-score
  clear-all
  set-default-shape balls "circle"
  set-default-shape paddles "paddle"

  set game-over? true
  set playing? false

  set score_1 0
  set score_2 0
  set not-random-move 0
  set l 0
  set r 0
  set total-move 0

  create-paddles 1 [
    setxy 0 (min-pycor + 1)
    set id_p 1
    set size 5
    set color red
    set match table:make
  ]

  create-paddles 1 [
    setxy 0 (max-pycor - 1)
    set id_p 2
    set size 5
    set color blue
    set match table:make
  ]

  set games table:make

  reset-episode
  reset-ticks
end

to play
  set playing? true
  ifelse game-over? [
    setup
    update-data
  ]
  [
    move-ball
    move-paddle
  ]

  tick
end

to setup
  ask balls [ die ]
  set game-over? false
  set playing? false

  create-balls 1 [
    setxy 0 0
    ;; 0 is north, 90 is east, and so on
    ;; avoid east(90) and west(270) to not get stucked
    ;; we also want to avoid angle too close to 90 and 270
    ;; we chose in [-45, +45] and [+135, +225]
    set heading (-45 + random 91) + (random 2 * 180)
    set color white
    set id_b 0
  ]
end

to update-data

  ask paddles with [ id_p = 1 ] [
    let won? true
    if last-winner = 2 [
      set won? false
    ]

    foreach (table:keys match) [
      state ->
      let action_n ( table:get match state )
      ;print state

      ifelse(table:has-key? games state)[
        table:put games state (insert-item 0 (table:get games state) (list action_n won? ) )
      ][
        table:put games state (list (list first action_n won? ))
      ]

    ]

    ; reset match
    set match table:make
  ]

  ;print games
end



;; ------------------------------------------------------------------------

to start-episode
  show "start episode"
  run-episode [[x] -> update-graphics x] [[] -> end-episode]
  set playing? true
  set game-over? false
  setup
  update-data
end

to end-episode
  show "end episode"
  set playing? false
  set game-over? true
end

to update-graphics [action]
  move-ball
  move-paddle
  tick
end



;; ------------------------------------------------------------------------

;; direction { "sx" : left, "dx" : right}
to move-paddle-with-direction [speed  direction]
  if ( game-over? = false and playing? = true ) [

    ifelse direction = "sx"
      [set heading -90]
      [set heading 90]

    fd speed

    ; Save the state just if player 1 move
    if id_p = 1 [
      ;; Ask ball info
      let x_ball 0
      let y_ball 0
      let dir_ball 1 ;avoi 0 degree
      ask balls with [ id_b = 0 ] [
        set x_ball (int xcor)
        set y_ball (int ycor)
        set dir_ball heading
      ]

      ;lower complexity
      let state ( lower-complexity x_ball y_ball dir_ball xcor )
      ;; Save the move
      let temp ( table:get-or-default match state (list  ) )
      table:put match state (insert-item 0 temp direction )
    ]
  ]
end

to move-paddle-left [speed]
  move-paddle-with-direction speed "sx"
end

to move-paddle-right [speed]
  move-paddle-with-direction speed "dx"
end

to move-paddle

  ;; Just player 1 is the learning agent
  ask paddles with [ id_p = 1 ] [
    ;; print match
    markov
;    ifelse action = 0
;      [ move-paddle-left 1 ]
;      [ move-paddle-right 1 ]
    set total-move ( total-move + 1 )
  ]

   ;; Player 2 implement a simple algorithm, NO LEARNING
  ask paddles with [ id_p = 2 ] [
    ;print match
    simple-move
  ]

end

to move-ball
  ask balls [
    (ifelse

      ;; bottom wall
      ( pycor = min-pycor ) [
        set game-over? true
        set score_2 score_2 + 1
        set last-winner 2
      ]

      ;; top wall
      ( pycor = max-pycor ) [
        set game-over? true
        set score_1 score_1 + 1
        set last-winner 1
      ]

      ;; left wall or right wall
      ( pxcor = min-pxcor or pxcor = max-pxcor ) [
        set heading (- heading) ;; bounce to the wall
        fd 1
      ]

      ;; near a paddle patch
      ( paddle-ahead? = true ) [
        set heading (180 - heading) ;; bounce to the paddle
      ]

      ;; empty patch
      [fd 1]
    )
  ]
end

to-report paddle-ahead?
  let paddle-patches patches in-radius ([size] of one-of paddles / 2)

  ifelse (heading > 270 or heading < 90)
   [ set paddle-patches paddle-patches with [pycor = [pycor] of myself + 1] ]
   [ set paddle-patches paddle-patches with [pycor = [pycor] of myself - 1] ]

  report any? paddles-on paddle-patches
end



;; ------------------------------------------------------------------------

to simple-move

  ;; Ask ball info
  let x_ball 0
  let y_ball 0
  let dir_ball 1 ;avoi 0 degree
  ask balls with [ id_b = 0 ] [
    set x_ball (int xcor)
    set y_ball (int ycor)
    set dir_ball heading
  ]

  let has-move? false

  ;;So that the paddle does not penetrate the wall
  if ( xcor + 3 > max-pxcor ) and ( has-move? = false )[
    set has-move? true
    move-paddle-left 1
  ]

  ;;So that the paddle does not penetrate the wall
  if ( xcor - 3 < min-pxcor ) and ( has-move? = false )[
    set has-move? true
    move-paddle-right 1
  ]

  if ( xcor < x_ball )  and ( has-move? = false ) [
    set has-move? true
    move-paddle-right 1
  ]

  if ( xcor > x_ball )  and ( has-move? = false ) [
    set has-move? true
    move-paddle-left 1
  ]

end



;; ------------------------------------------------------------------------

to-report compute-prob-markov-dx [state]
  ;; Compute the probability to go dx
  ;; After seeing the actual state

  ifelse( table:has-key? games state )[
    let actions-results table:get games state
    let dx-won 0
    let dx-lost 0

    ;print actions-results
    foreach actions-results [
    x ->
    let action first x
    let result last x

      if action = "dx" [
        ifelse result = true [
          set dx-won (dx-won + 1)
        ][
          set dx-lost (dx-lost + 1)
        ]
      ]
  ]

    if( dx-won + dx-lost = 0 )[
      report 0
    ]

    report (dx-won) / (dx-won + dx-lost)
  ][
    ;; if we have no data we choose randomly
    report 0.5
  ]

end

to markov

  ;; Ask ball info
  let x_ball 0
  let y_ball 0
  let dir_ball 1 ;avoi 0 degree
  ask balls with [ id_b = 0 ] [
    set x_ball (int xcor)
    set y_ball (int ycor)
    set dir_ball heading
  ]
  ;lower complexity
  let state ( lower-complexity x_ball y_ball dir_ball xcor )
  ;; compute the probability to win if we go dx
  let prob_dx compute-prob-markov-dx state


  if prob_dx != 0.5 [
    set not-random-move ( not-random-move + 1 )

    ;print word "state " state
    ;print word "prob_dx " prob_dx
    ;print word "not-random-move " not-random-move
  ]


  ifelse (xcor + 3 > max-pxcor) or (xcor - 3 < min-pxcor) [
    ;;So that the paddle does not penetrate the wall
    if (xcor + 3 > max-pxcor) [
      move-paddle-left 1
      ;print word "Forced left " l
      ;print word "on " total-move
      set l (l + 1)
    ]
    if (xcor - 3 < min-pxcor) [
      move-paddle-right 1
      ;print word "Forced right " r
      ;print word "on " total-move
      set r (r + 1)
    ]
  ][
    ;random choose
    if prob_dx = 0.5 [
      ifelse random 2 = 0 [
        move-paddle-right 1
      ][
        move-paddle-left 1
      ]
    ]
    if prob_dx > 0.5 [
      move-paddle-right 1
    ]
    if prob_dx < 0.5[ ; and xcor - 2 > min-pycor
      move-paddle-left 1
    ]
  ]
end

to-report lower-complexity [x_ball y_ball dir_ball x_paddle]

  let xb int( x_ball  )
  let yb int( y_ball  )
  let db int( dir_ball / 90 )
  let xp int( x_paddle  )

  report (list xb yb db xp)
end











@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
28
28
123
66
reset-score
reset-score
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
216
469
288
530
score_1
score_1
0
1
15

MONITOR
569
469
641
530
score_2
score_2
0
1
15

PLOT
727
17
1046
190
Score1 and Score2 ratio
NIL
NIL
0.0
2.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ifelse score_2 = 0 \n[ plot 0 ]\n[ plot score_1 / score_2 ]"

MONITOR
750
246
862
291
not-random-move
not-random-move
0
1
11

BUTTON
27
97
125
141
NIL
start-episode
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
34
161
97
194
NIL
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

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
