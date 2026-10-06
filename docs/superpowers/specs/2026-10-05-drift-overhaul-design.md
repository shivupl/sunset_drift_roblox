# Drift overhaul: design

Branch `drift-overhaul`, on top of `drift-feel`. Research:
`2026-10-05-drift-overhaul-research.md` (cited below as [R §x]); the earlier
round is `2026-10-05-drift-feel-research.md`.

## What the owner asked for

> "ok understood, now in a sepperate branch on top of this one, i want a full
> overhaul and perfection of the drifting system, different modes I can try
> different styles for each drivetype. all research based and perfect. im
> talking from throlle bursts to stable trifting and the standdard hajwala
> 360s. overhaul perfection."

> "make sure its easy to control the sideway drifting within the highway
> boundries also if you know what im talking about"

Before that, on drift-feel: "you just tweaked it a little it looks like
right?" The drift-feel defaults were deliberately close to the old car, so
this round's modes have to feel different, and the defaults change.

The owner runs a /goal, so there is no approval step: the rulings are mine
and are listed at the end with their cost if wrong.

## The baseline (Kamri, Classic, keyboard harness, 54-59 fps)

Measured with the keyboard's steer ramp emulated (4/s out, 8/s back), so
the numbers are what a keyboard player gets.

| Test | Classic |
|---|---|
| held on the gas from 100, wheel centred, 1-5 s | 41° (sd 0.2), 95→89 km/h, **path turned 74°, 79 m sideways** |
| six-swing Tanteel chain | peaks 38-42°, **wandered 49 m across**, path 25° off, gains speed 96→108 |
| lever held 3 s, centred | 34°, path 42°, 24 m sideways, 100→70 km/h |
| lever 360 from 110 | 2.53 s, exits 83, **path 19° off** |
| gas 360 (lever tap, full lock on the gas) | 2.69 s at 80 |
| the dial: tap into / tap counter / long counter | 42→54→43→1 |
| bursts: 0.2 s lift, gas back, ×3 | 42>35>40, 40>34>38, 38>32>36 (each nets -2°) |
| hands-off catch from 41 | 0.72 s |
| power-over, full lock + gas at 50 / 80 | 1° / 3° (the gas never breaks it loose) |
| lift-off at 100, brake tap at 100 | 4° / 4° |
| lane change with a lift at 100 | 20° (the flick) |
| corner: lever tap at 70, then gas with the wheel held into it | spins to 180°, path 22° |

A carriageway is 38 m: six 5.3 m lanes plus the shoulder (WorldConfig). A
held slide leaves it in about two seconds.

## What the research says (the parts that decide the design)

1. **The throttle sets the angle, the wheel sets the path** [R A2]. A
   saturated rear tyre trades side force for drive force, so more gas means
   more angle, and the effect grows with angle. Stanford and TU Wien split
   the controls the same way.
2. **A drift is open-loop unstable**, e-folding in about 0.36 s [R A3].
   Experts correct at about 1 Hz. Every keyboard or touch drift game that
   works has a hands-off countersteer that holds an angle (CarX, Midnight
   Racing: Tokyo's aggro, art of rally) [R D]. Ours is the throw
   controller's hold, and it stays.
3. **Slow angle build-up wins.** In a 34-driver study the slowest build-up
   failed 2.9 % of the time against 25 % for the fastest; an assist ramps at
   10°/s [R Rules]. Throttle-driven growth: 10-20°/s. A lift can shrink the
   angle faster, 30-60°/s.
4. **Countersteer faster than steer-in**, about 1.5-2× (art of rally)
   [R Rules].
5. **Front drive holds a slide only with the rear braked**, i.e. the lever
   held [R A5]. On release the gas pulls it straight with no countersteer.
6. **All-wheel drive flips strategy at about 25:75** [R A5]. Under that
   rear share, gas *reduces* the angle and adds speed (the rally slide).
   Above it, gas adds angle as in rear drive (factory drift modes).
7. **The hajwala 360 (ʿugda, the knot)** [R C2, C3]:
   - Entry 80-137 km/h: a light feint, hard steer with a light lever, held
     until the car faces backwards.
   - Then release and steer opposite, "let the car go"; the second knot
     needs no lever.
   - 1.8-2.6 s and 20-35 km/h lost (estimate). Ours already measures 2.53 s
     and 27 km/h.
8. **Clutch kick**: revs about +3000 rpm, then the dump, used when the slide
   starts to regain grip [R B]. About a 2× drive pulse for 0.15-0.3 s, worth
   +8-15°. FR Legends' button version is a double tap of the gas.
9. **Real drifts sit at 20-35°, peaking at 45-55°** [R A1]. On a straight,
   38° of lock cannot hold much past 45° on its own, so the high-angle mode
   is assisted.

## The design

### 1. The line (`VehicleSim/Line.luau`), for "within the highway boundaries"
While a slide is held (the gas hold, a throw, or the lever), a sideways
acceleration at the centre of mass:
- takes `hold` of the tyres' own curve out, so centred runs straight on;
- adds `steerG` toward the steered side at full steer;
- is let go by `intoRelease` when the wheel is held into the slide, so a
  drift steered into a corner takes the corner (the city).

Under the lever it has its own `leverHold`, from straight up, faded in over
`leverMinKmh`..`leverFullKmh`: a highway 360 goes straight on, and a
handbrake turn at city speed stays a turn. Because it acts at the centre of
mass it has no yaw moment (the angle, the 360 and the catch are the throw
controller's), and because it acts square to the velocity it does no work
(the speed is the tyres'). Capped at `maxG`.

### 2. The gas hold's ceiling and the two dial rates
- `drift.dialMaxDeg`: steering into a gas-held slide (lever out, no flick)
  adds no angle past it (`Throw intoMaxDeg`). The wheel held into a slide
  takes it wider, and the line carries it that way, where it used to spin.
  180 is no ceiling: the gas 360, which Classic and Power keep.
- `drift.dialIntoScale`: steering into a gas-held slide turns the angle at
  this share of the throw rate; counter-steer keeps the whole rate, so a
  transition swings through at full speed [R 4]. 1 is the old dial.

### 3. The throttle sets the angle
Already in DriftControl, now used as the research says:
- `holdDecayDegPerSec` < 0 grows a gas-held slide toward the band's top
  (10-20°/s) and > 0 pulls it straight (front drive, rally);
- `featherDegPerSec` is the lift's rate (30-60°/s); the lift also flutters
  the exhaust;
- `kickDeg` is the stab.

New:
- **Part throttle** (`keepThrottle`, `partialDegPerSec`): a trigger over
  keepThrottle keeps a hold, tightening it toward straight the further it
  is off full gas. This is the gamepad's analog throttle angle.
- **The surge** (`kickDriveScale`): the stab pushes the driven wheels harder
  for kickSeconds, so the clutch dump shows as wheelspin, revs and smoke.
- **The clutch-kick entry** (`kickThrow`): on the gas with the wheel turned,
  a lift and the gas back inside featherSeconds throws the car (FR Legends'
  double tap).
- **The brake entry** (`brakeThrow`): the brake pressed with the wheel
  turned at speed throws it once per press (the braking drift; front
  drive's left-foot brake).
- **The pivot** (`brakeGrowDegPerSec`): brake and gas together in a held
  slide grow the angle (left-foot braking, [R FWD 3]).

### 4. The 360
The lever's 360 is the shared standard on every mode: lever plus full lock,
held, comes round in about 2.5 s. Modes change only its rate
(`steering.throwYawRateDegPerSec`: heavy trucks slower, power cars faster)
and whether the gas keeps it spinning (`dialMaxDeg` 180). The line's lever
hold sends it straight on down the road.

### 5. Modes
Every drivetrain gets three new modes plus **Classic**, the drift-feel
default for that drivetrain kept exactly for A/B comparison. The first is
each drivetrain's default. Old ids stay where the mode is their successor,
so a pick carries over.

| Drivetrain | Mode (id) | In one line | Research |
|---|---|---|---|
| RWD | **Hajwala** (`hajwala`) | Gas widens the slide to 40°, a lift tightens it, the wheel aims it down the road. Lever 360s. | Power Hold [R RWD 1] |
| RWD | **Kick** (`power`) | The gas breaks it loose; double-tap the gas to kick it out; every stab kicks wider. Gas 360s. | Kick [R RWD 2] |
| RWD | **High Angle** (`angle`) | Holds 45-55°, assisted, carries its speed; long swings. | Long Angle [R RWD 3] |
| RWD | Classic (`classic`) | The drift-feel car. | — |
| FWD | **Tafheet** (`tafheet`) | The lever holds the slide; let go and the gas pulls it straight. A lift swings the tail. | Lever Throw [R FWD 1] |
| FWD | **Lift-Off** (`liftoff`) | Lift with the wheel turned and the tail comes round; slides are short; gas pulls it out. | [R FWD 2] |
| FWD | **Pivot** (`pivot`) | Tap the brake into a turn to throw it; brake and gas together swing it wider. | Pivot [R FWD 3] |
| FWD | Classic (`classicFwd`) | The drift-feel Handbrake style. | — |
| AWD | **Rally** (`rally`) | Shallow four-wheel slides; gas straightens and pulls you forward; a lift rotates it; brake or flick it in. | Rally [R AWD 1] |
| AWD | **Drift Mode** (`driftmode`) | Rear-biased like a factory drift mode: gas widens it like rear drive, the fronts catch it sooner. | [R AWD 2] |
| AWD | **Tatweef** (`tatweef`) | The heavy 4x4 sideways pass: long shallow slides you steer across the lanes; slow, heavy 360s. | [R AWD 3, 4] |
| AWD | Classic (`classicAwd`) | The drift-feel Rally style. | — |

Targets per mode, measured with the harness:

| | angle band | gas | lift | stab | 360 | line |
|---|---|---|---|---|---|---|
| Hajwala | 20-40 | grows 12°/s | -40°/s | +8 | 2.4-2.6 s | straight |
| Kick | 25-45 | grows 15°/s | -45°/s | +14, surge ×2 | gas spins | slight curve |
| High Angle | 45-55 | grows 10°/s | -35°/s | +10 | 2.4-2.6 s | straight |
| Tafheet | lever 25-50 | pulls 15°/s | swings -10°/s | -8 | 2.4-2.6 s | straight |
| Lift-Off | 20-35 | pulls 12°/s | swings | -8 | lever | straight |
| Pivot | 20-45 | pulls 10°/s | — | -6 | lever | straight |
| Rally | 15-30 | pulls 8°/s, gains speed | +5 | -4 | 2.5-2.8 s | straight |
| Drift Mode | 25-40 | grows 10°/s | -40°/s | +7 | 2.4-2.6 s | straight |
| Tatweef | 10-25 | holds | -20°/s | — | 2.8-3.2 s | steered |

Every mode must also keep:
- the hands-off catch under about 0.9 s;
- a lane change at 100 km/h without stepping out past about 20° (the
  flick's own number);
- the launch within 5 % of the car's own.

### 6. Feedback
- **The exhaust flutter** fires on the feather already, and the
  throttle-angle model makes feathering the way to tighten a slide, so it
  now flutters every time.
- **The surge** spins the driven wheels up, so the smoke and the engine
  note follow without new effects code.
- Pops stay lift-only (the 2026-09-22 ruling).

## Rulings (mine; the owner can overrule any)

1. **The line is an assist, not physics.** A held RWD slide on full drive
   physically circles (the drive's sideways component); a real driver
   straightens it with countersteer and by swinging the other way. The
   owner asked for the slide kept inside the highway, so it is a sideways
   push at the centre of mass.
   - *Cost if wrong:* slides feel "on rails". The knobs are per mode, and
     Classic has none.
2. **New defaults per drivetrain; Classic kept for A/B.** The owner found
   drift-feel's near-original defaults too subtle.
   - *Cost if wrong:* the default changes the car everyone drives. Classic
     is one tap away in the Settings tab.
3. **Wheel = dial stays; only its "into" half slows in the new modes.**
   Counter-steer and the lever keep the full rate, so tanteel transitions
   and lever 360s (which the owner rates easy) are unchanged.
   - *Cost if wrong:* growing the angle with the wheel feels slower. Gas
     and the lever do it instead.
4. **Front drive's default (Tafheet) holds on the lever, not the gas.**
   This is research-faithful [R A5], and it is how the Camry is driven.
   - *Cost if wrong:* gas-holding players find front drive short. Pivot
     and Classic hold on the gas.
5. **No clutch-kick key.** The kick is the double tap of the gas, as in FR
   Legends. A key would need a phone button, and the owner says the
   controls are good.
