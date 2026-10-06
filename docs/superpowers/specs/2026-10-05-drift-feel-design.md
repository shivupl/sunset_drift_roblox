# Drift feel: drivetrains, drift styles, the feather and the drift flutter

Branch `drift-feel`, 2026-10-05. Research: `2026-10-05-drift-feel-research.md` (beside this file).

## What the owner asked for

> "ok next I want you to work on overall polishing and enhancing the driving and drifting
> experience. I think it is in a good place right now control wise but could be better. there are a
> couple things (and there could be more) that I feel are missing. for instance the ability to kick
> off the exhaust during a drift where the flames would also flutter like in drifting videos is not
> in the game. the actual ease of hajwala tricks is actually pretty good as I have it though. also I
> want the drift style to differ slightly depending on the drivestyle of the vehicle (awd, rwd, fwd,
> etc). what I want you to do is research into this and perfect + implement a couple different
> styles (multiple for each) that i can test and try out in game"

Said: the drift feel differs slightly by drivetrain; several styles per drivetrain, tried in game;
a way to set the exhaust off mid-drift with fluttering flames; hajwala tricks stay as easy as they
are. Assumed (rulings below): the "kick" is done with the throttle, not a new button; the styles are
picked in game and remembered for the session; each car keeps its real drivetrain.

Success: on each drivetrain the owner can pick between at least two styles in game and feel the
difference; lifting briefly mid-drift sets off fluttering flames and the drift carries on; the
lever 360, the flick, the chain and the natl measure within a few percent of today on every
drivetrain's first (default) style.

## What is there today (measured, `main` at `2d3e066`, Kamri, harness, 59 fps)

| Test | Today |
|---|---|
| Launch 0-30 / 0-60 / 0-100 / 0-150 | 1.05 / 1.95 / 3.65 / 6.84 s |
| Handbrake to 20 degrees from 95 km/h | 0.25 s |
| Slide held on the gas, wheel centred, from 100 | 26-27 degrees, 100 to 97 km/h in 4 s |
| Flick from 95 on part throttle | peaks 69 degrees |
| Power-over at 50 km/h, full lock | 0.9 degrees |
| A 0.25 s lift mid-slide (a feather) | 30 degrees before, 19 during, **1 a second later: the drift dies** |
| Lever 360 from 110 | round at 2.45 s, 84 km/h, straight 0.43 s after |
| Hands-off catch from 29 degrees | under 5 at 0.53 s |
| Chain on the gas from 96 (0.4 s full-lock taps every 1.1 s) | 29-42 degrees, ends 105-106 km/h |

Every car drives on the rear wheels in the sim (`VehicleSim` sends all drive to wheels 3 and 4).
A lift mid-drift drops the gas permission at once (`throttleHoldOn = false` the step the throttle
falls under `throwThrottleHold`), so the car straightens; a lift at speed also fires the normal
lift burst, and the throttle coming back cuts it. So "kicking off the exhaust" mid-drift costs the
drift, and the flames it gets are the slow lift burst, not a flutter.

## Research in one paragraph

Hajwala is mostly done in front-drive saloons (Camry, Accord, Sonata), thrown on the handbrake at
160-260 km/h and carried on momentum, alongside rear-drive saloons (Caprice) and 4x4s (Land
Cruiser, Patrol). Rear drive holds a slide on the throttle and adds angle with it (power-over,
clutch kick); lifting tightens it. Front drive is the opposite: the driven fronts pull the car
along the way they point, so the gas pulls a slide straight, and slides come from the handbrake
and from lifting at the limit (lift-off oversteer); they are shorter and fade. All-wheel drive
slides at lower angles, keeps pulling forward, is started with a Scandinavian flick, and factory
"drift modes" send 70-100% of the torque rearward to behave more like rear drive. The flames in
drift videos come from overrun: each lift (feathering the throttle mid-drift) gives a quick burst of
pops with a flickering flame, and a car bouncing off the limiter flutters at roughly 5-15 Hz.
Games that do this well expose few, legible knobs (NFS's "brake to drift / gas to drift",
Midnight Racing's one assist slider), not sim depth.

## Approaches considered

1. **Real drive layouts in the sim, plus style presets on a small set of new knobs (chosen).**
   The sim gains front and all-wheel drive (torque split, front diff), so launch, wheelspin,
   tyre smoke, the gas in a slide and engine braking all come out of the tyres. Each style is a
   named preset: the layout's torque split and a handful of new `drift` knobs that bend how the
   throw controller treats the pedals (feather, kick, hold decay, angle band, lift throw). The
   lever path is untouched by every style, which is what keeps the hajwala tricks as they are.
2. **Presets only, no physics.** Cheaper, but a "front-drive" Kamri would still launch, smoke and
   spin its rear wheels; the difference would be a label on the same car.
3. **A separate controller per drivetrain.** The most freedom and the most risk: the throw
   controller is what makes 360s, chains and catches repeatable, and three copies of it would
   each need the whole measurement table re-earned.

## Design

### 1. Drive layouts (`VehicleSim`, `Drivetrain`)

`CarConfig.drivetrain` gains:
- `layout`: `"RWD"` (default), `"FWD"` or `"AWD"`.
- `frontShare`: the share of drive torque sent to the front axle under AWD (a fixed-split
  centre diff); RWD is 0 and FWD 1 whatever it says.
- `frontDiffLock`: the front axle's diff blend, like `diffLock` for the rear.

`Drivetrain.axleShares(cfg) -> (front, rear)` is pure and spec'd. `VehicleSim.step` then:
- drives each wheel with `drivePerRearWheel x axleShare x diffShare` (the existing per-wheel
  number is half the total, so RWD comes out identical), on the axle's own diff blend;
- puts engine braking on the driven wheels by the same shares;
- reflects the engine's inertia onto each driven wheel by its axle's share;
- reads the engine's spin and road speed from the driven wheels, weighted by share;
- caps the launch over every driven wheel (`Drivetrain.launchCap`, pure, spec'd to equal today's
  formula on RWD);
- runs traction control on "a driven wheel is spinning".

Nothing changes on RWD: same code path, shares (0, 1). The handbrake stays on the rear.

### 2. Each car's drivetrain (`CarCatalog`, our lines only)

The real cars: Kamri (Camry) and Hatch FWD; Batrol (Patrol) and Kruzer 80 (Land Cruiser) AWD;
Pickup, Cruiser, Krown Vik, Krown Vik Fleet and Lekzas RWD, which is the default and needs no
line. Set as `tuning.drivetrain.layout` on the four non-RWD entries. The owner's uncommitted
CarCatalog changes stay unstaged (the hash-object routine in CLAUDE.md).

### 3. Pedal behaviour in a slide (`VehicleSim/DriftControl.luau`, pure, spec'd)

Today's gas-hold logic moves out of `VehicleSim.step` into a pure module and gains the new
behaviour. Its knobs live in a new `CarConfig.drift` section; the defaults are the first RWD
style's values.

- **The feather.** A lift shorter than `featherSeconds` (0.3 s) keeps the gas hold. During it the
  held angle moves at `featherDegPerSec`, + toward straight (rear drive regains grip), - away
  from it (front drive: lift-off oversteer). A longer lift drops the hold as today, so lifting
  and centring is still the catch. This is the polish the exhaust kick needs.
- **The kick.** The gas back on inside the feather adds `kickDeg` to the held angle over
  `kickSeconds`: rear drive kicks the tail out (the clutch-kick feel), front drive pulls it in
  (the fronts pull straight).
- **The hold.** While the gas holds a slide (not the lever), the held angle eases toward straight
  at `holdDecayDegPerSec` (front-drive slides fade) and is kept inside
  `holdMinDeg`..`holdMaxDeg`, moved at `holdEaseDegPerSec` (an all-wheel-drive slide stays
  shallow; a high-angle style settles deep).
- **The lift throw.** `liftThrow` above 0: lifting off fast (from at least 0.6 to under 0.1) at
  `liftThrowMinKmh` or more with the wheel past `liftThrowSteer`, before the car is sideways,
  throws it like a gentle flick: permission `liftThrow` and the rear's grip times
  `liftThrowRearGrip` for `liftThrowSeconds`. Lift-off oversteer.
- **Power-over.** With the wheel past `powerOverSteer`, launch and traction control step aside so
  the throttle can break the driven wheels loose, and the gas hold arms from
  `throwThrottleHoldFromDeg x gasHoldFromScale`.
- **Speed carry.** `slideReliefScale` multiplies the car's slide momentum relief.

The throw controller (`Throw.step`) takes one more input, `angleRateDeg` (+ toward straight),
which moves its latched hold angle, or adds to its rate target while the wheel is turned. Nothing
in `drift` acts while the lever is in: the lever 360, the lever hold and the lever catch stay
exactly as tuned on every style.

### 4. The styles (`src/shared/DriftStyles.luau`)

A style is a name, a layout, a blurb and a partial CarConfig deep-merged over the car's own
config. A style may only set keys no catalog car tunes (spec'd), so each car keeps its own
character; where a car does tune something (slide relief), styles scale it instead.

| Style | Layout | What the player does, and what the car does |
|---|---|---|
| **Classic** (RWD default) | rear | Today's car, plus the feather: a quick lift straightens it a little, the gas back on kicks it out a little. |
| **Power Over** | rear | Gas and full lock start a slide from 2nd or 3rd gear (traction control steps aside), a welded diff, a big clutch-kick on every stab. |
| **High Angle** | rear | Gas-held slides settle deep (40-60 degrees) and carry more speed sideways; showy and smoky. |
| **Handbrake** (FWD default) | front | The tafheet saloon: thrown on the lever, held on the gas but fading slowly, a stab pulls it straighter, a lift swings the tail. |
| **Lift-Off** | front | No lever needed: lift with the wheel turned at speed and the tail comes round; lifts add angle, the gas pulls out. |
| **Rally** (AWD default) | all, 45:55 | Four-wheel power slide: shallow (up to about 35 degrees), driving forward, a stronger Scandinavian flick. |
| **Drift Mode** | all, 15:85 | The factory drift mode: rear-biased, holds like rear drive but the front catches it sooner. |

Numbers are first guesses, tuned in Play and recorded in TUNING.md with what each knob does.
Each layout's first style is its default and has to keep the measured tricks within a few
percent of today; the others may move further.

### 5. Picking a style in game (client `DriftStyle.luau`, `SettingsPanel`)

- The choice is per layout, kept as LocalPlayer attributes (`DriftStyle_RWD` and so on), so
  swapping cars keeps it. Session only, not saved to the profile (ruling).
- The menu's Settings tab gets a **DRIFT STYLE** section under the time of day: the current car's
  drivetrain, one chip per style, and the chosen style's blurb. Works on phones (chips sized by
  the UI tokens).
- In Studio, **O** cycles the current car's styles and **Shift+O** cycles every style (any
  layout, for comparing), with a "DRIFT: POWER OVER (RWD)" label for a moment, like the flames'
  P.
- `VehicleController` builds the sim's config from the car's config and the style
  (`DriftStyles.apply`, cached per car and style) and swaps it live when the choice changes; a
  config reload (L) rebuilds it too.

### 6. The drift flutter (`EngineAudio`, `ExhaustPops`, `ExhaustStyles`, `CarControls`)

- Every exhaust style gets a `flutter` pattern: a dense run of mostly small pops (30-60 ms apart,
  easing to about 120 ms), so their flames overlap into a flickering tongue rather than separate
  puffs, and their sound into a rattle.
- `EngineAudio` fires `onFlutter` instead of `onLift` when the lift happens in a slide
  (`|drift| >= driftFlutterFromDeg`, speed `>= driftFlutterMinKmh`, the same lift edge). The gas
  back on cuts it, as it cuts a burst. So feathering mid-drift flutters the flames in time with
  the driver's foot, and the drift carries on (§3).
- Relayed as a new kind (`KIND.flutter`, one message a flutter, rebuilt from its seed on every
  client). `relayPerSecond` rises from 8 to 12 so a fast feather (a flutter and a cut each time)
  is never dropped.
- Limiter pops stay off (the owner's 2026-09-22 ruling: pops only on letting off).

### 7. Error handling

- An unknown or stale style id (an attribute from an older build, a style removed) falls back to
  the layout's default.
- A style whose layout does not match the car is never offered in the panel; in Studio, Shift+O
  may apply it on purpose, which sets the sim's layout from the style.
- Config reload (L) clears the style cache with the per-car one.
- `DriftControl` resets its timers on a reset (the R key, a respawn), the way the wheels' spin is
  stopped today, so a feather in progress cannot leak into the next run.

### 8. Testing

- Specs (TDD): `Drivetrain.axleShares` and `launchCap` (RWD equals today's formula); a new
  `DriftControl.spec` (feather keeps the hold, a long lift drops it, the kick's sign and size,
  decay, the angle band, the lift throw's gates, nothing under the lever); `Throw.spec` for
  `angleRateDeg`; `DriftStyles.spec` (each layout has a default, styles touch no key a car tunes,
  every key exists in CarConfig, ranges); `ExhaustStyles.spec` and `ExhaustSputter.spec` for the
  flutter patterns and the new relay kind.
- Studio, harness only, per style: the table above plus the feather, a flutter's pops and flames
  on screen, and the natl tap on the FWD Kamri and AWD Batrol. Screenshots of a fluttering
  flame mid-drift and of the Settings section.

## Rulings (made under the owner's /goal; each says what it costs if wrong)

1. VehicleSim is in scope this time: the old "don't touch VehicleSim" came with the auto-flip
   goal; this goal is the drive itself. Cost if wrong: the drive-layout change is reverted.
2. The exhaust "kick" is the throttle (feather a lift, stab it back), not a new button: it is
   what the drift videos show and it respects the 2026-09-22 ruling that pops come only on
   letting off. Cost: if the owner meant a button, the flutter is one call away from a key.
3. Each car takes its real drivetrain, so the default Kamri becomes front drive. Its default
   style is held to today's trick numbers. Cost: if the owner wants the Kamri rear-drive, it is
   one catalog line.
4. The feather applies to every style, including Classic. A lift under 0.3 s used to end the
   drift; now it straightens it a little. Cost: the hands-off catch may start up to 0.3 s later
   (measured and reported).
5. Style knobs never act under the lever, so lever tricks are the same on every style (only the
   drive layout's physics can move them; measured).
6. Session-only choice; saving it to the profile waits for the owner to pick keepers.
7. Limiter flutter stays off (2026-09-22 ruling).
