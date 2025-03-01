globals [family-centers interaction-counter scalar-stress current-tick-interactions interaction-history scalar-stress-history mean-scalar-stress]
patches-own [inclination]
turtles-own [family-id interaction-fatigue agent-mood fatigue-buildup-rate fatigue-decay-rate]
breed [houses house]
breed [humans human]

;;-------------------------------------------------------------------------------------------------
;;                              Setup & go procedure + static plot values
;;-------------------------------------------------------------------------------------------------

to setup
  clear-all
  clear-output
  resize-world -50 50 -50 50
  set-patch-size 4
  setup-patches
  setup-agents
  setup-houses
  set current-tick-interactions 0
  set interaction-history []
  set scalar-stress-history []
  clear-all-plots
  reset-ticks
end

to go
  set current-tick-interactions 0  ;; Reset interaction count for this tick before starting the tick
  tick
  ask humans [ move-agent ]
  ask humans [ agent-interaction ]
  fatigue-decay
  update-scalar-stress
  update-agent-shape
  update-plots
end

;;-------------------------------------------------------------------------------------------------
;;                                          Graph settings
;;-------------------------------------------------------------------------------------------------

to SOM-plot-zero-line
  plotxy 0 0
  plotxy 0 plot-y-max
end

to SOM-plot-min-line
  plotxy -11 0
  plotxy -11 plot-y-max
end

to SOM-plot-max-line
  plotxy 11 0
  plotxy 11 plot-y-max
end

to Fatigue-plot-max-line
  plotxy 101 0
  plotxy 101 plot-y-max
end

to Scalar-Stress-threshold-line
  plotxy 0 scalar-stress-threshold
  plotxy plot-x-max scalar-stress-threshold
end

;;-------------------------------------------------------------------------------------------------
;;                                 Patches generation behavior
;;-------------------------------------------------------------------------------------------------

to setup-patches
  ask patches [
    set inclination 0
    set pcolor rgb 255 250 180
  ]

  set family-centers []
  repeat Family-count [
    let center-x random ((max-pxcor - Attraction-Radius) - (min-pxcor + Attraction-Radius) + 1) + (min-pxcor + Attraction-Radius)
    let center-y random ((max-pycor - Attraction-Radius) - (min-pycor + Attraction-Radius) + 1) + (min-pycor + Attraction-Radius)
    let center-patch patch center-x center-y
    set family-centers lput center-patch family-centers

    ask center-patch [
      set inclination 1
      set pcolor rgb 255 75 75
    ]
  ]

  ; Define gradient levels (higher values first)
  let levels [[0.9 [255 99 72]] [0.8 [255 120 71]] [0.7 [255 139 73]] [0.6 [255 156 77]]
              [0.5 [255 173 84]] [0.4 [255 190 93]] [0.3 [255 205 105]] [0.2 [255 220 120]] [0.1 [255 235 136]]]

  ; Expand outwards layer by layer
  foreach levels [ level ->
    let val item 0 level
    let rgb-values item 1 level

    let radius (1 - val) * Attraction-Radius
    ask patches with [inclination = 0 and any? (patch-set family-centers) in-radius radius and
                      pxcor >= min-pxcor and pxcor <= max-pxcor and
                      pycor >= min-pycor and pycor <= max-pycor] [
      set inclination val
    ]
  ]

  ; Assign colors after inclination is set
  foreach levels [ level ->
    let val item 0 level
    let rgb-values item 1 level
    ask patches with [inclination = val] [
      set pcolor rgb (item 0 rgb-values) (item 1 rgb-values) (item 2 rgb-values)
    ]
  ]
end

;;-------------------------------------------------------------------------------------------------
;;                                  Agents generation behavior
;;-------------------------------------------------------------------------------------------------
to setup-houses
  foreach family-centers [ well ->
    create-houses 1 [
      setxy [pxcor] of well [pycor] of well  ;; Place house on the well center
      set shape "house"
      set size 10
      set color gray
    ]
  ]
end

to setup-agents
  let family-counter 0 ; Count the number of families spawned in

  foreach sort family-centers [ well ->
     create-humans Family-size [
        setxy [pxcor] of well [pycor] of well  ; Place agents exactly on the red patch of each well
        set family-id family-counter  ; Assign identity based on welll
        set size 3
        set interaction-fatigue 0  ; Initialize fatigue to 0
        ;pd ;DEBUG -> SHOW AGENT PATHS

        ; Assign state-of-mind with Gaussian distribution, rounded to nearest whole number
        let temp-som random-normal initial-mood 2  ; generate individual agents state-of-mind based on the slider, standard deviation of 2
        set agent-mood round (min (list 10 max (list -10 temp-som)))  ; Making sure state of mind never sinks below -10 or exceed 10

        ; Assign fatigue buildup rate with Gaussian distribution, rounded to nearest whole number
        let temp-buildup random-normal initial-fatigue-buildup-rate 2  ; generate individual agents fatigue buildup rate, standard deviation of 2
        set fatigue-buildup-rate min (list 2 max (list 0.1 temp-buildup))  ; Buildup rate between 0.1 and 2

        ; Assign fatigue decay rate with Gaussian distribution, rounded to nearest whole number
        let temp-decay random-normal initial-fatigue-decay-rate 2  ; generate individual agents fatigue decay rate, standard deviation of 2
        set fatigue-decay-rate min (list 10 max (list 0.1 temp-decay))  ; Decay rate between 0.1 and 2
      ]

      set family-counter family-counter + 1  ; Increment for the next well

    ]
  ; Assign initial shape & color based on state-of-mind
  update-agent-shape
end

;;-------------------------------------------------------------------------------------------------
;;                                    Agents movement behavior
;;-------------------------------------------------------------------------------------------------

; Movement logic based on well strength
to move-agent
  let current-inclination [inclination] of patch-here

  ; If inside a well (inclination higher than 0), decide movement based on variable well-strength
  let stronger-patches patches in-radius 1 with [inclination > current-inclination]
  let weaker-patches patches in-radius 1 with [inclination <= current-inclination]

  ifelse random 100 < family-cohesion [
    ; Move toward stronger patches with probability = well-strength
    if any? stronger-patches [ face one-of stronger-patches fd 1 ]
  ]
  [
    ; Otherwise, move to a weaker patch
    if any? weaker-patches [ face  one-of weaker-patches fd 1 ]
  ]
end

;;-------------------------------------------------------------------------------------------------
;;                                    Agents interaction behavior
;;-------------------------------------------------------------------------------------------------

to agent-interaction
  ;---------------------- CHECK FOR INTERACTION PARTNERS ----------------------
  if not any? other humans in-radius interaction-radius [ stop ]  ; Skip if no agents within slider determined 'interaction-radius' patches radius
  let potential-partners other humans in-radius interaction-radius with [family-id != [family-id] of myself] ; if potential agents within radius, let agent register the total number of other agents it can interact with

  ;---------------------- SELECT 1 INTERACTION PARTNER ----------------------
  if any? potential-partners [
    let partner one-of potential-partners

    ;---------------------- CALCULATE INTERACTION EAGERNESS ----------------------
    let fatigue-impact (interaction-fatigue / 100) * fatigue-weight ;divide the fatigue by 100 and multiply it by the fatigue weight percentage
    let state-impact ((agent-mood + 10) / 20) * mood-weight ;divide the state-of-mind by 100 and multiply it by the SOM percentage.
    let interaction-eagerness max list 20 min list 80 ((fatigue-impact + state-impact) / 2) ;calculate the interaction eagerness. Value between 20 (20% chance) and 80 (80% chance). Both state of mind and fatigue are equally weighted in this calculation, but their values are dependant on the slider settings.

    ;same procedure for the potential partner
    let partner-fatigue-impact ([interaction-fatigue] of partner / 100) * fatigue-weight
    let partner-state-impact (([agent-mood] of partner + 10) / 20) * mood-weight
    let partner-eagerness max list 20 min list 80 ((partner-fatigue-impact + partner-state-impact) / 2)

    ;---------------------- INTERACTION CHANCE ROLL ----------------------
    if random 100 < interaction-eagerness and (random 100 < partner-eagerness) [  ; chance to interact based on interaction-eagerness value

      ;---------------------- FATIGUE BUILDUP ----------------------
      set interaction-fatigue min (list 100 (interaction-fatigue + fatigue-buildup-rate))  ; Increase interaction fatigue for this agent based on the individual interaction-fatigue-buildup value. (MAX = 100)
      ask partner [ set interaction-fatigue min (list 100 (interaction-fatigue + fatigue-buildup-rate))]; Increase interaction fatigue for partner based on the individual interaction-fatigue-buildup value. (MAX = 100)


      ;---------------------- INTERACTION OUTCOME & EFFECT ----------------------
      let interaction-outcome random 3  ; Generates a value: 0 (negative), 1 (neutral), or 2 (positive)

        ; NEGATIVE OUTCOME (-1 for both)
        if interaction-outcome = 0 [
          set agent-mood max list -10 (agent-mood - 1)
          ask partner [ set agent-mood max list -10 (agent-mood - 1) ]
        ]

        ; POSITIVE OUTCOME (+0.1 for both)
        if interaction-outcome = 2 [
          set agent-mood min list 10 (agent-mood + 1)
          ask partner [ set agent-mood min list 10 (agent-mood + 1) ]
        ]

      ;---------------------- UPDATE INTERACTION COUNTERS ----------------------
      set interaction-counter interaction-counter + 1 ;The GLOBAl TOTAL counter
      set current-tick-interactions current-tick-interactions + 1 ;Counter for all interactions occuring THIS TICK (gets wiped after every tick)

      ; ---------------------- DEBUGGING ----------------------
         ;show (word "Agent " who " interacted with Agent " [who] of partner " - Outcome: " interaction-outcome)
         ;show (word "Agent " who " fatigue: " interaction-fatigue)
         ;show (word "Agent " [who] of partner " fatigue: " [interaction-fatigue] of partner)
         ;show (word "Agent " who " state-of-mind: " agent-state-of-mind)
         ;show (word "Agent " [who] of partner " state-of-mind: " [agent-state-of-mind] of partner)
         ;show (word "Agent " who " eagerness: " interaction-eagerness)
    ]
  ]
end

;;-------------------------------------------------------------------------------------------------
;;                                    VARIOUS PROCEDURES
;;-------------------------------------------------------------------------------------------------


; Fatigue decay process executed every 10 ticks
to fatigue-decay
  if ticks mod fatigue-decay-time = 0 [
    ask humans [
      set interaction-fatigue max (list 0 (interaction-fatigue - fatigue-decay-rate))  ; Ensure it doesn't go below 0
    ]
  ]
end

; Procedure to update agent shape & color based on interaction-fatigue
to update-agent-shape
  ask humans [
    if agent-mood > 2 [ set shape "face happy" set color green]
    if agent-mood <= 2 and agent-mood >= -2 [ set shape "face neutral" set color orange]
    if agent-mood < -2 [ set shape "face sad" set color red]
  ]
end

;Procedure for updating the scalar-stress list based on the total interactions within the current tick
to update-scalar-stress
  ;---------------------- PROCEDURE TO CALCULATE THE SCALAR-STRESS OVER THE SELECTED TIME WINDOW ----------------------
  set interaction-history lput current-tick-interactions interaction-history ; Add the total interactions of the current tick to history
  let history-length length interaction-history ;check the length of the history list
  let recent-interactions []  ;; Initialize an empty list that will calculate the last values

  ; Select the last X amount of stored interactions from the history (where X = scalar-stress-timeframe)
  if history-length >= scalar-stress-timeframe [
    set recent-interactions sublist interaction-history (history-length - scalar-stress-timeframe) history-length  ;; Use last X elements if possible
  ]
  if history-length < scalar-stress-timeframe [
    set recent-interactions interaction-history  ;; Otherwise, use the entire list
  ]

  set scalar-stress sum recent-interactions ;Calculate scalar stress as the sum of the last scalar-stress-timeframe values

  ;---------------------- CALCULATE THE MEAN SCALAR STRESS FOR VISUAL PURPOSE ----------------------
  set scalar-stress-history lput scalar-stress scalar-stress-history ; Add the total interactions of the current tick to history
  ifelse length scalar-stress-history > 0 [
    set mean-scalar-stress mean scalar-stress-history
  ] [
    set mean-scalar-stress 0  ;; Avoid division by zero errors
  ]

  ; ---------------------- CHECK FOR SCALAR STRESS THRESHOLD ----------------------
  if scalar-stress >= scalar-stress-threshold [
    user-message (word "Warning! Scalar stress has exceeded the threshold! Current community organization under severe social pressure.")

  ]
end



@#$#@#$#@
GRAPHICS-WINDOW
483
10
895
423
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
0
10
238
74
NIL
setup
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
240
10
478
74
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
178
184
211
Family-size
Family-size
1
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
0
214
184
247
Family-count
Family-count
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
0
284
184
317
Attraction-Radius
Attraction-Radius
5
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
0
249
184
282
family-cohesion
family-cohesion
1
100
49.0
1
1
NIL
HORIZONTAL

PLOT
484
427
896
586
Global Interactions Over Time
Time (ticks)
# Interactions
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot interaction-counter"

PLOT
899
172
1510
422
Scalar Stress evolution over time
Time (ticks)
ΔStress
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
" Δ Scalar stress " 1.0 0 -16777216 true "" "plot scalar-stress"
"Mean" 1.0 0 -14439633 true "" "plot mean-scalar-stress"
"Threshold" 1.0 0 -2674135 true "" "Scalar-Stress-threshold-line"

PLOT
899
11
1173
170
Agent mood distribution
State of Mind value
Aagents
-11.0
11.0
0.0
1.0
true
true
"" ""
PENS
"# agents" 1.0 1 -14070903 true "" "histogram [agent-mood] of turtles"
"neutral" 1.0 0 -3026479 true "" "SOM-plot-zero-line"
"very unhappy" 1.0 0 -5298144 true "" "SOM-plot-min-line"
"very happy" 1.0 0 -15040220 true "" "SOM-plot-max-line"

PLOT
1176
10
1511
169
Agent interaction fatigue distribution
Fatigue
Agents
0.0
110.0
0.0
1.0
true
true
"" ""
PENS
"# agents" 1.0 1 -14730904 true "" "histogram [interaction-fatigue] of turtles"
"Completely exhausted" 1.0 0 -8053223 true "" "Fatigue-plot-max-line"

SLIDER
0
402
184
435
initial-mood
initial-mood
-10
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
0
474
184
507
initial-fatigue-decay-rate
initial-fatigue-decay-rate
0.1
2
1.5
0.1
1
NIL
HORIZONTAL

SLIDER
0
438
184
471
initial-fatigue-buildup-rate
initial-fatigue-buildup-rate
0.1
2
1.5
0.1
1
NIL
HORIZONTAL

SLIDER
0
509
183
542
fatigue-decay-time
fatigue-decay-time
1
200
75.0
1
1
NIL
HORIZONTAL

SLIDER
0
546
184
579
interaction-radius
interaction-radius
0
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
900
429
1046
462
fatigue-weight
fatigue-weight
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
900
466
1046
499
mood-weight
mood-weight
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
900
502
1046
535
scalar-stress-timeframe
scalar-stress-timeframe
1
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
900
539
1046
572
scalar-stress-threshold
scalar-stress-threshold
100
1000
700.0
20
1
NIL
HORIZONTAL

TEXTBOX
12
79
472
150
First press 'setup' to initialize the model based on the slider settings.\nThen, press 'go' to run the model.\n\nThe model will automatically stop when the threshold for scalar stress is reached, signifying the social stress within the community has reached a critical level.
11
0.0
0

TEXTBOX
191
176
473
372
These parameters define how our people will be generated in the model. You can decide how many families our community will count, and how many family members live in each family.\n\nThese families are generated in a \"home\" which should not be interpreted as a physical house but rather a 'pool-of-attraction' where our people interact with eachother.\n\nInteractions can occur outside of these hubs, but depending on the 'family-cohesion' value, the likeliness of interactions happening within or outside these pools gets increased / decreased.\n\n'Attraction-radius' refers to the relative size of these pools.
10
0.0
0

TEXTBOX
189
401
478
584
These parameters influence how our people interact with eachother. Each person has a 'mood', ranging vfrom -10 (unhappy) to 10 (happy). The mood is influenced by the outcome of a successful interaction: either a positive, negative or neutral outcome.\n\nInteractions also cause our people to get fatigued. The buildup and decay of fatigue can be altered here to influence how fast our people get fatigued, and how quickly they recover over time.\n\nThe interaction radius defines from how far away our people can interact (0 means they have to be directly on top of each other).
10
0.0
1

TEXTBOX
1052
428
1359
591
These sliders determine how the scalar stress buildup is calculated. Both the mood of the agents and the fatigue play a critical role in this. The 'weight' sliders define how strongly both of these factors are accounted for in determining the stress level for each tick.\n\nThe timeframe defines the time window for comparing the stress level of current tick with the number of previous ticks.\n\nThe threshold defines at which stress level, the scalar stress becomes too high for the community, signifying the need for reorganisation.
10
0.0
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
NetLogo 6.4.0
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
