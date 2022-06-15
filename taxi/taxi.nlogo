breed [drivers driver]
breed [riders rider]
breed [orders order]

drivers-own [
  occupied?
  with-rider?
  ; Counters
  time-on-trip
  time-to-rider
  time-idle
]

riders-own [
  has-order?
]

orders-own [
  assigned?
  lifetime
]

directed-link-breed [rider-order-links rider-order-link]
directed-link-breed [driver-order-links driver-order-link]
directed-link-breed [driver-rider-links driver-rider-link]

globals [
  ; Counters
  new-order-cnt
  expired-order-cnt
  total-time-on-trip
  total-time-to-rider
  total-time-idle
  ; Metrics
  burn-rate
]

to init-driver [a-driver]
  set xcor (random-float 2 - 1) * max-pxcor
  set ycor (random-float 2 - 1) * max-pycor
  set occupied? false
  set with-rider? false
  reset-driver-counters self
end

to reset-driver-counters [a-driver]
  set time-on-trip 0
  set time-to-rider 0
  set time-idle 0
end

to init-rider [a-rider]
  set xcor (random-float 2 - 1) * max-pxcor
  set ycor (random-float 2 - 1) * max-pycor
  set has-order? false
end

to setup
  ; Clear globals, ticks, turtles, patches, drawing, plots, output.
  clear-all
  ; Set shapes for agents.
  set-default-shape drivers "car"
  set-default-shape riders "person"
  set-default-shape orders "star"
  ; Generate agents.
  create-drivers #-drivers [
    init-driver self
  ]
  create-riders #-riders [
    init-rider self
  ]
  ; Reset ticks & initialize plots and drawing area.
  reset-counters
  reset-ticks
end

to go
  ; Riders ask for a ride (put orders).
  ask riders with [not has-order?] [
    ifelse random-float 1 < order-proba / 60 [
      ask-for-ride self
    ][
      if riders-stroll? [
        right random 30 - 15
        forward driver-speed / 20
      ]
    ]
  ]
  ; The system looks for drivers and assigns them to orders.
  ask orders with [not assigned?] [
    find-driver-or-expire self
  ]
  ; Drivers with orders who didn't take riders move to their riders.
  ask drivers with [occupied? and not with-rider?] [ move-towards-rider self ]
  ; Drivers with riders move to their destination points.
  ask drivers with [occupied? and with-rider?] [ move-to-destination self ]
  ; Drivers without orders randomly move (or stay).
  ask drivers with [not occupied?] [
    if drivers-stroll? [
      right random 30 - 15
      forward random-float driver-speed
    ]
    set time-idle time-idle + 1
  ]
  if ticks mod (60 * metrics-collect-period) = 0 [ collect-metrics ]
  tick
end

to move-towards-rider [a-driver]
  let link-to-rider one-of my-out-driver-rider-links
  ; If we reached the rider, let him in.
  ifelse [link-length] of link-to-rider < 0.1 [
    set with-rider? true
  ]
  ; Otherwise go towards the rider.
  [
    set heading [link-heading] of link-to-rider
    fd min (list driver-speed [link-length] of link-to-rider)
  ]
  set time-to-rider time-to-rider + 1
end

to move-to-destination [a-driver]
  let link-to-destination one-of my-out-driver-order-links
  ; If we reached the destination, let the rider out and finish the order.
  ifelse [link-length] of link-to-destination < 0.1 [
    set with-rider? false
    set occupied? false
    ask out-driver-order-link-neighbors [ die ]
    ask out-driver-rider-link-neighbors [ set has-order? false ]
    ask my-out-driver-rider-links [die]
  ]
  ; Otherwise, go towards the destination.
  [
    set heading [link-heading] of link-to-destination
    forward min (list driver-speed [link-length] of link-to-destination)
    let a-rider one-of out-driver-rider-link-neighbors
    ask a-rider [
      set xcor [xcor] of myself
      set ycor [ycor] of myself
    ]
  ]
  set time-on-trip time-on-trip + 1
end

to ask-for-ride [a-rider]
  hatch-orders 1 [
    create-rider-order-link-from a-rider
    ; Set the destination location.
    set xcor (random-float 2 - 1) * max-pxcor
    set ycor (random-float 2 - 1) * max-pycor
    ; Set the lifetime: how many ticks a rider will wait for a driver.
    set lifetime random 5
    set assigned? false
  ]
  set new-order-cnt new-order-cnt + 1
end

to find-driver-or-expire [an-order]
  let a-rider one-of in-rider-order-link-neighbors
  ask a-rider [
    let driver-candidates drivers with [not occupied?] in-radius driver-search-radius
    if count driver-candidates > 0 [
      ; If we found the driver, assign him to the order.
      ask one-of driver-candidates [
        create-driver-order-link-to an-order
        create-driver-rider-link-to a-rider
        set occupied? true
      ]
      ask an-order [
        set assigned? true
      ]
    ]
  ]
  if not assigned? [
    ; If we didn't find the driver, see if the rider is ready to wait.
    set lifetime lifetime - 1
    if lifetime <= 0 [
      set expired-order-cnt expired-order-cnt + 1
      die
    ]
  ]
end

to collect-metrics
  ; Save raw metrics to global vars.
  ifelse new-order-cnt = 0 [
    set burn-rate 0
  ][
    set burn-rate expired-order-cnt / new-order-cnt
  ]
  set total-time-on-trip sum [time-on-trip] of drivers
  set total-time-to-rider sum [time-to-rider] of drivers
  set total-time-idle sum [time-idle] of drivers

  reset-counters
end

to reset-counters
  set expired-order-cnt 0
  set new-order-cnt 0
  ask drivers [
    reset-driver-counters self
  ]
end

to add-10-drivers
  create-drivers 10 [
    init-driver self
  ]
end

to remove-10-drivers
  ask n-of 10 drivers [ die ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
15
647
453
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
15
15
187
48
#-drivers
#-drivers
0
100
11.0
1
1
NIL
HORIZONTAL

SLIDER
15
55
187
88
#-riders
#-riders
0
1000
250.0
1
1
NIL
HORIZONTAL

BUTTON
210
465
273
498
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
210
505
273
538
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
15
95
187
128
driver-search-radius
driver-search-radius
0
100
7.0
1
1
NIL
HORIZONTAL

SLIDER
15
140
187
173
driver-speed
driver-speed
0
5
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
15
185
185
218
order-proba
order-proba
0.01
1
0.07
0.01
1
NIL
HORIZONTAL

MONITOR
360
465
417
510
hours
(ticks mod (60 * 24)) / 60
0
1
11

MONITOR
295
465
352
510
days
ticks / 60 / 24
0
1
11

MONITOR
425
465
482
510
minutes
ticks mod 60
0
1
11

PLOT
655
15
855
165
Occupied drivers %
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count drivers with [occupied?] / count drivers"

SWITCH
15
230
185
263
drivers-stroll?
drivers-stroll?
0
1
-1000

SWITCH
15
275
185
308
riders-stroll?
riders-stroll?
1
1
-1000

PLOT
655
175
855
325
Burn rate
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot burn-rate"

SLIDER
15
320
185
353
metrics-collect-period
metrics-collect-period
1
24
24.0
1
1
hrs
HORIZONTAL

PLOT
655
335
855
485
Driver time utilization
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"trip + path to rider" 1.0 0 -16777216 true "" "plot (total-time-on-trip + total-time-to-rider)\n/ (total-time-on-trip + total-time-to-rider + total-time-idle)"
"trip only" 1.0 0 -7500403 true "" "plot total-time-on-trip\n/ (total-time-on-trip + total-time-to-rider + total-time-idle)"

BUTTON
495
465
605
498
NIL
add-10-drivers
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
495
505
605
538
NIL
remove-10-drivers
NIL
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

A (very simple) model of ride-hailing businesses like Uber, Lyft, Yandex.Taxi.

## HOW IT WORKS

A rider orders a trip. If any driver happens to be near the rider, it is assigned to
the order, goes to the rider, picks her up and travels to the destination. If no driver
is found, the order expires ("burns").

## HOW TO USE IT

Set up numbers of riders and drivers, run, watch the metrics.

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

Surprisingly, enabling strolling drivers drops utilization and rises burn rate!

## EXTENDING THE MODEL

* add monetization, check various formulas for trip price
* add price elasticity, allow riders to reject the trip if it's too expensive
* add riders and drivers aquisition and retention
* calculate drivers' income
* implement surge pricing mechanics
* emulate traffic jams by patch properties and investigate how it changes the model behaviour
* add competitors, configure their features and find out which features matter
* implement "AB-testing engine" and check out if network effects distort your results

## NETLOGO FEATURES

Seems that NetLogo doesn't allow measurement aggregations, so I implemented simple metrics collection engine.

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(c) krvkir. Many thanks to my Yandex.Taxi experience.
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
1
@#$#@#$#@
