# TUNING — every CarConfig field

Legend for the goal columns: ↑ raise the value, ↓ lower it, — no direct effect.
Goals: OS = more oversteer (rear steps out easier, holds bigger angle);
INIT = easier drift initiation; 2W = more two-wheel stability.
For the opposite effect move the other way. Press L in play to reload.

## units
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| metersPerStud | World scale. Leave at 0.28. | — | — | — |
| gravity | Effective gravity on the car. Lower = lighter car, less load, less grip everywhere, slower weight transfer. 54.9 disables the correction. | — | — | ↑ |

## body
Per-car geometry and mass are not in CarConfig any more: they are each car's `rig` in `CarCatalog.luau` (see RIG_SPEC.md), and `VehicleRig.configFor` writes them into `body` for that car. The direction columns still hold for those fields.
| Field (catalog rig field) | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| massKg (`rig.massKg`) | Total mass. More mass = more momentum in a slide, slower transitions. | — | ↓ | — |
| bodySize (`rig.collisionSizeM`, width/height/length) | Box dimensions. Height changes roll inertia and ground clearance. | — | — | — |
| centerOfMassOffset (`rig.centerOfMassM`, car space, forward is −Z) | Lower CoM = less roll, higher tip angle. Forward CoM = more front load = more rear slide, and more natural yaw toward the grounded side on two wheels. | forward ↑ | forward ↑ | lower (more negative Y) ↑ |
| wheelbase (`rig.wheelbaseM`) | Longer = more stable, slower rotation. | ↓ | ↓ | — |
| trackWidth (`rig.trackWidthM`) | Wider = higher two-wheel tip angle, less roll. | — | — | ↑ |
| wheelRadius (`rig.wheelRadiusM`) | Bigger = taller gearing, less drive force. The tyre mesh must be this radius. | — | ↓ | — |
| shellMassFraction (`rig.shellMassFraction`) | Share of mass in the shell vs ballast. Only affects where the ballast sits. | — | — | — |
| dragCoefficient / frontalArea / airDensity | Shared in CarConfig. Top speed and how fast a slide bleeds speed. | — | — | — |
| rollingResistance | Shared in CarConfig. Coast-down drag. | — | — | — |

## CarCatalog
| Field | What it does |
|---|---|
| defaultCarId | The car anyone gets who has not chosen one: the Kamri, which took the Phase 0 sedan's place and handling (measured against it below). |
| cars.&lt;id&gt;.scale | Uniform size, default 1 (every car in the catalog is 1.2). Multiplies every length of rig and body and rescales the size-only handling terms so the car drives the same (RIG_SPEC.md §8b). Up = bigger car. |
| cars.&lt;id&gt;.rig | Physics geometry and mass (table above). |
| cars.&lt;id&gt;.body | Paint colour, body pieces (car space) and wheel pieces (wheel space). RIG_SPEC.md §7. A piece's `look` (ReplicatedStorage.CarLooks) carries its colour, metalness and roughness maps; with `paint` the look's Color is the paint. |
| cars.&lt;id&gt;.tuning | Any part of CarConfig this car tunes differently, deep-merged (arrays replace). The Batrol stiffens its springs to 45000/4200 for its 2.2 t. |
| cars.&lt;id&gt;.displayName / blurb / order | The spawn menu card: name, one line under it, and position (low first, then by name). The card's last item is the car's drivetrain, read from `tuning.drivetrain.layout`. |
| cars.&lt;id&gt;.tuning.drivetrain.layout | Which wheels drive, as the real car: the Kamri (a Camry) `"FWD"`, the Batrol (a Patrol) and the Kruzer 80 (a Land Cruiser) `"AWD"`, every other car rear drive (no line). It picks which drift styles the car offers (`DriftStyles`); the style sets the split. |
| spawn.autoSpawnOnJoin (CarConfig) | false: players start on foot with the spawn menu open. true: a car is parked for them at join, the Phase 0 way. |
| spawn.spawnCooldownSeconds (CarConfig) | Shortest gap the server allows between two spawn requests from one player (1.5 s). |
| spawn.carId (CarConfig) | Overrides the default for everyone without a `CarId` attribute. |
| spawn.showRig (CarConfig) | Draws the collision box, hubs and seat translucent over the body, for fitting a new car. |

### Car personalities

The Pickup and the Cruiser, the first cars added with catalog entries alone (a rig, one body mesh and a `tuning` block), were removed on 2026-11-08 with the Hatch: none had a cabin for the first-person view. The Batrol and the Kruzer 80 still use the Pickup's measured springs and natl torques at the same 2.2 t. Their feel notes and measurements are in this file's history (before the removal commit).

**Kamri (Phase 3) against the sedan it replaced.** The Kamri keeps the sedan's mass, centre-of-mass height and shared tuning on its own real geometry: wheelbase 2.775 m (was 2.8), track 1.575 m (was 1.55), tyre radius 0.326 m (was 0.33), and a 1.2 m box (was 1.3) with the centre of mass 0.3 m below its centre (was 0.35), so the height above the road is the same. Measured with the same protocol:

| | Sedan | Kamri |
|---|---|---|
| Box centre above road at rest | 1.063 m | 0.998 m (predicted 0.999; smaller box, same centre of mass height) |
| 0–50 / 0–100 km/h | 1.59 / 3.67 s | 1.57 / 3.67 s |
| 100–0 km/h | 44.3 m | 44.7 m |
| Turn-in yaw at 0.1 s / 0.2 s, held at 3 s | 22.9 / 29.6 / 15.4 °/s | 23.9 / 29.6 / 15.2 °/s |
| Peak roll | 3.5° | 3.4° |
| Natl tap at 105 km/h | 41°, down at 2.6 s | 41°, down at 2.6 s |
| Lever 360 from 110 km/h | 2.59 s, 52 km/h | 2.58 s, 51 km/h |
| Slide held at gas 0.5 / 0.75 / 1.0 | 0.6 / 0.6 / 5.0 s | 0.5 / 1.1 / 5.0 s |

Every difference is within run-to-run spread, so the numbers above still describe the default car.

## suspension
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| restLength | Ride height at full droop. | — | — | — |
| travel | Usable compression before the bump stop. | — | — | ↑ |
| rayMarginM | Extra ray length past full droop. Leave alone. | — | — | — |
| stiffness | Softer = more visible weight transfer, slower response. | — | — | ↑ |
| damping | Low = bouncy, high = dead. Aim for a bounce and a half. | — | — | ↑ |
| bumpStopStiffness | Keeps the body off the wheels when bottomed. | — | — | ↑ |
| antiRollFront | Stiffer front bar = front loses grip first = understeer. | ↓ | ↓ | — |
| antiRollRear | Stiffer rear bar = rear loses grip first = oversteer. | ↑ | ↑ | — |

## arcade (the drive; `VehicleSim/Arcade.luau`)

The drive since 2026-11-06 (the owner: "it needs to feel really good for like the 10 year olds that are going to play this"). While `arcade.enabled` is on it replaces the tyres and every drift assist below it (steering's throw and flick, handbrake grip, drift, line, the slip model); suspension, the engine and gearbox, brakes, effects and scoring are unchanged, and two-wheel driving (any `twoWheel` mode but idle) still runs on the tyres. Studio comparison: DriftLab `{"arcade":{"enabled":false}}` drives the old model.

How it drives: the car goes where its nose points as fast as the tyres let it (`alignRate`, capped at `gripG`); the wheel turns the nose. Up to `slideFromSteer` of the wheel the car only asks for the turn the tyres can follow; past it the ask climbs to `steerAsk` times that, so holding the key down steps the tail out with no button. Sliding, the tyres hold `driftG`, the wheel sets the angle (`driftAngleDeg` at full lock and full gas, `liftAngleScale` of it off the gas), the other way swings it across, centred straightens. The handbrake spins it (`handbrakeSpinDegPerSec`); let go far round and it finishes the turn (`finishTurnFromDeg`).

Measured on the Kamri (front drive), Play, fixed inputs from 100 km/h (2026-11-06):

| Input | Nose angle | Notes |
|---|---|---|
| steer 0.3 / 0.5, gas 0.6 | 1° / 1-2° | clean turn |
| steer 0.75, gas 0.7 | 36° after 1.5 s | slide |
| full lock, gas 0.7 | 21° at 0.5 s, 47-48° held | speed 100 → 115-117 km/h held |
| full lock then centred | 46° → 1° in 0.7 s | no overshoot |
| full lock, then full the other way | +50° → -53° in 1.0 s, yaw peak 145°/s | the swing |
| lever 0.3 s + full lock, then 0.6 steer | 35°, held 28-34° | |
| lever + full lock held from 80 km/h | 360 in 1.8 s; let go at 443°, it finished at 720° | 80 → 56 km/h by the first 360 |
| full lock 2.5 s from 50 / 75 / 120 km/h, gas 0.5 | path turned 59° / 41° / 21° | sliding grip by speed (`driftGSlow` in town, `driftG` on the highway) |
| reverse, full lock, 3 s | nose within 8° of straight back | reverse never asks past what the tyres follow |
| launch, full gas | 0-60 2.0 s, 0-100 3.3 s | |
| every car, full lock 2 s then full the other way 2 s | held +49 to +50°, swung -49 to -53°, straight after letting go | body roll 3° (Hatch) to 7° (Kruzer 80); half steer slips 1-2° on all; Lekzas (rear), Kruzer 80 and Batrol (all-wheel), Pickup, Hatch, Kamri |

Earlier passes: a single `driftG` 0.3 bent a full-lock slide at 50 km/h only 12°/s, into a town wall sideways (now `driftGSlow` 0.75 under `slowKmh`); `driftG` 0.55 bent a held slide 34 m across the road in 2.5 s (now 0.3: 23 m); `driftDragG` 0.08 let a held slide gain 14 km/h (now 0.3: holds); a flat `steerAsk` 1.7 slid every lane change at 0.3 steer when it was the raw wheel geometry, and crept at 0.7.

Side variants to compare by driving (`src/shared/ArcadeFeels.luau`; Studio's I cycles them, on a phone the top row's DRIFT tab while driving, in any server while `ArcadeFeels.phoneButton` is true (false takes the tab away once a feel is picked), or set the LocalPlayer attribute `ArcadeFeel`), same inputs (full lock 2 s, full the other way 2 s, centred) from 100 km/h:

| Feel | Held | Swung across | Speed after 5.5 s |
|---|---|---|---|
| Main | +49° | -51° | 146 km/h |
| Wide (`driftAngleDeg` 70, `angleResponseSeconds` 0.55, `driftG` 0.22) | +61° | -63° | 138 km/h |
| Snappy (`driftAngleDeg` 45, `angleResponseSeconds` 0.25) | +40° | -41° | 154 km/h |
| Old tyres (`arcade.enabled` false) | +1° (no slide) | spun out to ±175° | 88 km/h |

Knobs for feel: wider or tighter slides `driftAngleDeg`; how fast the angle settles `angleResponseSeconds`; how much the path bends in a slide `driftG`; how much wheel starts a slide `slideFromSteer`; how hard the lever spins it `handbrakeSpinDegPerSec`; speed kept in a slide `keepSpeed` and `driftDragG`.

## tires.front / tires.rear
Part 2 set the rear (1.06) above the front (1.05): a rear that out-grips the front pushes wide
at speed instead of stepping out, which is what "planted" means. Initiation is paid for with
the throw controller and the lever's grip cut, not by softening the rear.

| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| grip | Peak friction. Rear lower than front = oversteer. | rear ↓ / front ↑ | rear ↓ | — |
| peakSlipDeg | Slip angle at peak. Lower rear = rear breaks away sooner. The rear is set later than the front so the front reaches its limit first. Moving it also moves that axle's stiffness, so change riseShape with it (see below). | rear ↓ | rear ↓ | — |
| riseShape | How the tire builds grip up to the peak. 1 is a straight line whose slope is 1/peakSlipDeg, so raising the peak on its own quietly softens the axle everywhere below it and the rear starts stepping out under power at cruise. Below 1 the curve is concave: full bite near zero slip, rounding over into the peak. Lower it to firm an axle up without moving where it lets go. | rear ↑ | rear ↑ | — |
| slideSlipDeg | Where the fade ends. Wider gap to peak = gentler fade = more progressive slide. | rear ↓ | rear ↓ | — |
| falloffShape | How the tire gives up grip past the peak. 1 is a straight line to the floor. Above 1 the first degrees past peak cost almost nothing and the loss steepens further out, which is the warning before the rear goes. Lower it toward 1 if you want the limit to arrive without notice. | rear ↓ | rear ↓ | — |
| slideGripRatio | Grip floor while sliding. Lower rear = bigger angles, harder to catch; higher = holds and recovers easier. Also sets how hard a handbrake pull can rotate the car, since a saturated tire sits at this value. | rear ↓ | rear ↓ | — |
| deepSlideSlipDeg / deepSlideGripRatio | Past deepSlideSlipDeg the floor eases toward the deep ratio by 90° of slip. It never touches the 10 to 35° region a held drift lives in. Since the throw controller took over the rotation this is purely a speed-carry knob for a 360: the lower both deep ratios, the less the car scrubs while fully sideways. Front 0.5 and rear 0.55 take a Ta'geed from 110 to 76 km/h; front 0.75 and rear 0.65 lost another 12. Front 0.4 was tried and slowed the tyres' own realigning after a bail. | rear ↓ | — | — |
| longitudinalGrip | Drive grip as a multiple of the lateral peak: the friction circle becomes an ellipse. Above 1 the axle puts more throttle down before it spins and nothing sideways changes, so every drift number is untouched. Rear 1.55 with the TC floor at 0.7: 0-30 in 1.05 s, 0-70 in 2.65, 0-100 in 3.9 (1.4 / 0.6 was 3.0 and 4.35; the original round circle was 3.8 to 60 and 6.3 to 100). Now 1.9 with the slip model's launch control: 0-30 1.02, 0-70 2.28, 0-100 3.64; power-over at 50 km/h under full lock peaks at 0.8°. On the slip model it also sets how hard a spinning rear pushes in a slide, so raising it carries more speed through tricks (lower slipModel.slideRelief to match). Front stays 1. | — | — | — |
| speedFadeMps | Speed below which lateral force fades. Only for parking jitter. | — | — | — |
| slideMomentum.slideRelief | Fraction of the tyres' sideways drag handed back while the car is sliding, at the centre of mass so nothing about the steering or yaw changes. This is the "does the car scrub to a halt in a chain" knob. 0 is the old car; at 0.38 a throw and four transitions on the gas from 96 km/h end at 87 (was 69) and a 43° slide held on the gas for 4 s loses 2 km/h (was 24). Lower it if long slides feel floaty; 0.55 held a slide at full speed. | — | — | — |
| slideMomentum.leverRelief | The same with the handbrake held, blended by the lever's level. A lever 360 sits on locked rears for two and a half seconds; at 0.6 one from 110 exits at 85 km/h (was 69) and a 720 at 63 (was 40). Lower it to make spins cost more speed again. | — | — | — |
| slideMomentum.fromDeg / fullDeg | Drift angle where the relief starts and is full (10 / 25). Below fromDeg nothing changes, so cornering, the grip limit and a straight-line lever pull are exactly as before. | — | — | — |
| slideMomentum.minSpeedKmh / fullSpeedKmh | Speed where it starts and is full (30 / 60), so a slow slide still stops. The relief is never allowed to push the car on: a slide can hold its speed on the gas, never gain it. | — | — | — |
| slipModel.enabled | The slip model: wheels with their own spin, tyre force from slip angle and slip ratio together, grip falling off with load (VehicleSim/Wheel.luau, DESIGN.md). false is the old friction-circle tyre, kept as the A/B; flip it and press L to compare in one session. Measured side by side the two match within a few hundredths on launch, pull, 360, 720 and two-wheel; the slip model catches faster (0.53 against 0.82 s) and carries a chain better (loses 5 against 9). | — | — | — |
| slipModel.peakSlipRatio | Slip ratio where drive and brake grip peak (0.12). Higher needs more wheelspin before the rear pushes; lower snaps to spin sooner. | ↓ | ↓ | — |
| slipModel.loadSensitivity / loadFactorMin / loadFactorMax | Grip lost per unit of load over static (0.08), clamped. Higher makes weight transfer matter more: lift-off and the flick swing harder, the loaded outside tyres give up sooner. | ↑ | ↑ | — |
| slipModel.wheelInertia / engineInertia | Wheel and crank inertia (the crank's reflected through the gearing, so first gear spins up slowly). Lower is a twitchier throttle-to-spin response. | — | — | — |
| slipModel.substepSeconds | Wheel spin integration step (3 ms). Only raise it if the client frame budget needs it. | — | — | — |
| slipModel.handbrakeTorque / handbrakeGripCut | The lever as a brake torque on each rear (700 Nm) and a grip cut on top (0.6). 2,500 locks the rears like a real handbrake and dragged a lever 360 from 110 to 72; 700 keeps it at 85 with a 0.27 s pull. More torque = slower spins, a harder-hitting throw. | — | ↑ | — |
| slipModel.flickRearGripMultiplier | The flick's rear grip cut in this model (0.7). The old tyre needs 0.35; weight transfer and wheelspin do the rest here. 0.35 flicked a part-throttle car to 85-89°, 0.5 to 82-84, 0.7 to 76-81. | ↓ | ↓ | — |
| slipModel.slideRelief / leverRelief | Slide momentum in this model (0.25 / 0.7). Off, pure physics scrubs a held slide from 97 to 70 and a chain from 96 to 76. With the rear's drive grip at 1.9 less is needed: 0.25 loses 6-7 km/h over a 4 s held slide and 5 over the chain. Sensitive: 0.2 lost 13 on the held slide, 0.3 lost 4. | — | — | — |
| slipModel.launchGripUse | Launch control: under tractionControlBelowKmh, pointing straight, the throttle is capped at this fraction of what the rear tyres can put down at their peak slip (plus the torque to spin the driveline up). 1.0: no wheelspin, 0-30 1.02 s, 0-100 3.64. Above 1 lets the rears spin up a little at the start; lower is a gentler launch. The old spin-and-cut loop alone gave 1.20 and 4.1. | — | — | — |

## drivetrain
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| torqueCurve | Engine torque by rpm. More torque = more power-over. Raised about a third for tafheet speeds; launch is traction-limited so 0 to 100 barely moved (7.7 s), the gain is above 100 km/h. | ↑ | ↑ | — |
| gearRatios / finalDrive | Shorter (bigger numbers) = more drive force at speed = easier to break traction with throttle. A sixth gear (0.62, about 350 at the limiter; 0.68 for the 300 top speed) because the five-speed box ran out near 270 km/h. 0.58 was too tall: the Kamri got to 280 later. | ↑ | ↑ | — |
| reverseRatio | Reverse gearing. | — | — | — |
| drivelineEfficiency | Scales all drive force. | ↑ | ↑ | — |
| layout / frontShare / frontDiffLock | Which wheels drive (`"RWD"`, `"FWD"`, `"AWD"`; Drivetrain.axleShares), the front axle's share of the torque under AWD (a fixed-split centre diff), and the front axle's diff blend like diffLock. RWD is the old path exactly (shares 0/1, measured within noise of before). Front drive measured on the Kamri: 0-30/60/100 in 1.22/2.42/4.20 s against 1.06/1.95/3.65 on rear drive (a launch moves weight off the fronts), the lever 360 2.48 s at 78 km/h against 2.45 at 84, the natl unchanged (40 degrees, down at 3.4-3.5 s). All-wheel drive on the Batrol and Kruzer 80: launch, 360 and natl within a few hundredths of rear drive. The drift styles set frontShare (Rally 0.45, Drift Mode 0.15); the catalog sets layout. | — | — | — |
| diffLock | 0 open to 1 welded. An open diff sends torque to the wheel with least grip, so on two wheels the airborne rear takes it and the grounded one barely drives; that is why a natl can run straight. Welded drives the grounded wheel alone and yaws the car (measured: 11° of heading drift in 4 s at 0.4 throttle; 3° at full throttle with 0.25 and yaw damping). In a four-wheel drift the loads stay close so partial lock still feels welded. | ↑ | ↑ | ↓ |
| idleRpm / redlineRpm | Rev range. | — | — | — |
| upshiftRpm / downshiftRpm | Shift points. A later upshift keeps the engine in the fat part of the curve through a slide. | — | ↑ upshift | — |
| slideShift / slideShiftFromDeg / slideShiftMinKmh | In a slide (past this drift angle, above this speed) the box shifts up by the engine's own rpm, spin included, and never down. Off (false) is the road-speed box everywhere, which held drifts on the limiter 93% of the slide. The speed floor keeps wheelspin launches on the road-speed box (without it 0-100 went 3.6 to 4.9-8.7 s). | — | — | — |
| slideShiftHoldSeconds / slideShiftMaxUpshifts | How long a slide lasts after the angle drops (a transition swings through zero; 0 hunts gears through a chain), and how many gears one slide may shift up. 1: held drifts brush the limiter 16-42% of the slide; more keeps revs lower but climbs gears. | — | ↑ upshifts | — |
| shiftTime | Torque cut per shift. 0.08 s; 0.15 left a quarter-second flat spot at the 1-2 change around 58 km/h. | — | — | — |
| spinRpmRate | How fast rpm climbs while spinning. Cosmetic. | — | — | — |
| engineBrakeTorque | Weight shift forward on lift. More = sharper lift-off rotation and easier transitions. Raised from 40 to 90 because 40 was too little to feel at the wheelbase and mass of this car. | ↑ | ↑ | — |
| brakeForce / brakeBias | Pedal strength and split. More rear bias = brake-induced rotation. | bias ↓ | bias ↓ | — |
| brakeFadeMps | Anti-jitter at rest. | — | — | — |
| reverseEngageMps | Speed under which the car counts as stopped for selecting reverse. | — | — | — |
| topSpeedKmh / topSpeedFadeKmh | The ceiling, as a limiter: drive fades to nothing over the last fade band so the car sits at the top instead of hitting a wall. 300 / 25 from 210 / 20 (speed-feel, 2026-10-05: the owner, "overall game driving feels pretty slow ... needs to feel at least 50% faster if not 2x"), then 330 for 10% more ("it feels to fast" at +20%); the Pickup 280 and the Cruiser 315 in the catalog, ceilings drag keeps them under (at the 1.45 pace they topped out near 245 and 270). The map's 400 m curve is at the grip limit at 220, so past that it is a braking corner. |
| powerScale | The game's pace: the torque curve times this (`Drivetrain.torqueAt`), on every car. 1.6: 1.45, then 10% more at the owner's request (2026-10-05; a straight 10% on the pace numbers, not re-measured; +20% measured Krown Vik 0-100 2.42 s, 0-200 7.42, and the owner found it too fast). With launchGrip and the sixth gear at 1.45, measured flat-out from a standstill (before → after): Krown Vik (rear) 0-100 4.06 → 2.86 s, 0-150 7.81 → 5.42, 0-200 14.13 → 8.92, 203 → 263 km/h at 16 s; Kamri (front) 4.42 → 3.39, 7.68 → 5.71, 14.99 → 8.81, 202 → 267; Batrol (all) 5.36 → 3.97, 9.75 → 6.97, none → 11.33, 196 → 238. Drifts are unchanged in feel at the new speeds: Hajwala holds 39 degrees from 150 (145 → 138 km/h over 4 s, path 5 degrees, 8 m), a lever 360 from 160 comes round in 2.54 s and exits at 131, 1 m off its line; Rally holds 19 from 150 with no speed lost; the natl tap at 105 is the same at 1 or 1.45 (peak 36-37 degrees, down after 3.4 s). Front drive past traction control's 120: the Hatch runs 100-160 in 2.46-2.53 s with the cut-off at 120 or 160 alike, its fronts at their peak slip. Up: quicker everywhere past the launch. | ↑ | — | — |
| launchGrip / launchGripFullKmh / launchGripEndKmh | The driven tyres' drive grip times launchGrip off the line, pointing straight (only while traction control is allowed: never in a slide, under the lever or on two wheels, so no drift number moves), fading out from 60 to 155 km/h (140 at the 1.45 pace). Below about 100 km/h the launch is grip-limited, so power alone did nothing there. 1.54 (1.4, then 10% more). Up: a harder launch. | — | — | — |
| tractionControlBelowKmh / tractionControlMaxDriftDeg / tractionControlMin / tractionControlCutRate / tractionControlRecoverRate | Traction control, a loop that winds throttle down while the rear spins and back up while it grips. Active under the speed and only while the drift angle is under the max and the lever is out, so it never touches a slide. Measured: 0-100 went 7.3 s (fixed cap) to 6.3 s (loop through the midrange) to 4.4 s with the floor at 0.6, recovery at 4/s, the rear's longitudinalGrip at 1.4 and the torque up 15%. Below 100 km/h the launch is grip limited (8.6 kN on the rear axle) and torque does not move it; the torque is what pulls 100-150. A lower floor or slower recovery is a lazier launch. |
| reverseHoldSeconds | How long the brake must be held once stopped before reverse engages. Any throttle returns to drive and resets it. Raise if stopping hard drops you into reverse; lower if reversing out feels sticky. The gearbox is automatic and there is no manual shift, so this is the only gear choice a player makes. | — | — | — |

## steering
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| maxSteerDeg | Lock. Must exceed the drift angles you want to hold minus assist. | ↑ | ↑ | — |
| steerSpeedDegPerSec | How fast the wheels turn in. Higher = snappier initiation, twitchier hold. | — | ↑ | — |
| steerReturnDegPerSec | How fast they return. | — | — | — |
| driftAssist | Automatic counter-steer fraction. Higher = easier hold, less skill. Keep low. Off on two wheels. | ↓ | — | — |
| driftAssistFadeStartDeg / driftAssistFadeEndDeg | The assist fades to nothing between these drift angles so it stops fighting a spin (at 90° it was steering 13° against the rotation). Lower both for easier 360s, raise for a car that always tries to catch itself. | — | — | — |
| speedLockCurve | Speed-sensitive lock, km/h to fraction of maxSteerDeg. Full lock for parking, tapering at highway speed so turning alone cannot pitch the car sideways. Raise the high-speed end if the car feels unresponsive at speed, lower it if a flick still breaks the rear loose. | ↑ high end | ↑ high end | — |
| counterSteerReliefDeg | Slip angle at which the taper is fully lifted, so a correction always gets the whole wheel. Lower = the full wheel comes back sooner in a slide. | — | — | — |
| counterSteerRelief | How much of the taper a correction lifts. 1 gives the whole wheel back, 0 disables the exception and the taper applies to counter-steer too, which makes big angles uncatchable at speed. | — | — | — |
| throwRelief | How much of the taper a deliberate throw lifts, while the handbrake is held. 1 = the wheel you actually turned, 0 = the taper still applies. Without it a Ta'geed at 160 km/h starts with 13° of steer and never comes round. | — | ↑ | — |
| throwReliefTailSeconds | How long the throw relief lingers after the lever is let go, so the wheel does not shrink to a third mid-spin. | — | ↑ | — |
| flickFromLock / flickWindowSeconds / flickRelief | The flick: a hard steer past flickFromLock one way then the other within the window is a deliberate throw and gets the taper back. A held turn never trips it. 0 relief disables it. | — | ↑ | — |
| flickRearGripMultiplier / flickGripSeconds | The reversal also cuts rear grip briefly, standing in for the weight transfer of a real pendulum turn. Lower = the flick breaks the rear harder. | — | ↓ | — |
| throwYawRateDegPerSec | The throw controller. While the lever is in (or for the flick window) the rate the drift angle changes is steered to the wheel's direction times this, scaled by how far the wheel is turned, on top of the path's own turn rate. Full lock under the lever comes round for a 360 (2.7 s at 150); centred, the car holds the angle it has; counter-steered, the angle comes back. It replaced a fixed onset impulse, which was either too weak for a 360 or an unrecoverable whip. Raise for faster spins that are harder to time; lower is lazier and scrubs more speed. | — | ↑ | — |
| throwYawGain / throwYawMaxTorque | Nm per deg/s of rate error and the cap on it while the wheel is turned. The cap sets how hard the onset kicks (20 degrees in 0.30 s from 95 km/h at 16,000) and whether the spin gets through the backwards half, where the steered fronts fight it. The gain over the chassis's yaw inertia (~3,600 kg m²) is the controller's time constant, 0.07 s at 600. | — | ↑ cap | — |
| throwHoldGain / throwHoldSettleDegPerSec / throwHoldMaxTorque | The held slide. Gain 6: at 3 a slide handed to the gas at 14 degrees faded to straight in two seconds, the tyres' realigning beating a 12 deg/s correction. Measured at 6: a 0.2 s tap hands off and holds 20 to 22 degrees, a 0.3 s tap 34 to 37. With the wheel centred under the lever the hold angle tracks the drift until it has stopped moving (under the settle rate), then latches, and the controller asks for holdGain deg/s per degree of error, capped at the throw rate. The hold gets its own torque cap, higher than the onset's, so the yaw a turn-in built is absorbed in a couple of tenths. Measured at gain 600 and cap 60,000 from 100 km/h: a 0.2 s tap of full lock settles at 22 degrees and stays there; full lock centred at 34 settles at 46; 0.4 steer centred at 31 settles at 37. At gain 250 and cap 32,000 the same full-lock case settled at 67. | — | — | — |
| throwPathFilterSeconds | Filter on the path's turn rate that the controller adds to its target. Shorter is more exact and noisier. | — | — | — |
| throwThrottleHold / throwThrottleHoldFromDeg / throwThrottleHoldKeepDeg / throwThrottleHoldGraceSeconds | Throttle as the second permission. The lever arms it too, so a hand-off from lever to gas holds whatever angle the car has; once on it keeps down to keepDeg, a lower bar than starting. Gas past the threshold with the car already past the angle keeps the controller alive with the lever out, so a slide started on the lever is held on the gas with full rear grip and no lever drag; once on it survives the straight moment of a transition and drops after the grace time under the gate with the wheel centred, or when the gas is lifted. Throttle alone never starts a slide. Measured from 100 km/h: a gas hold at 27 degrees bleeds 98 to 92 over 4 s (a lever hold 98 to 84); two flicks on the gas chain 30, 35, 31 degrees at 85 to 89 km/h; a 360 on the gas after a 0.3 s lever tap comes round in 2.3 s and exits at 63, on the lever 2.6 s and 76. Raise the angle to make the gas hold harder to keep. | — | — | — |
| throwMinSpeedKmh / throwFullSpeedKmh | The controller's authority fades to nothing at the low speed and is full from the high one. This is the "crazier tricks stay hard" knob: a 360 from 110 exits at 73 km/h, a 720 from 110 exits at 40, a 720 from 150 at 75. Raise the full speed and a second spin needs more entry speed. | — | — | — |
| throwFinishAuthority / throwFinishFromDeg / throwFinishCarryDeg | The catch. Lever in, past 90 degrees the speed fade is lifted to finishAuthority so a spin that has run out of speed finishes instead of stalling backwards. Lever out and wheel centred, past finishFromDeg the same authority brings the car back to straight, the short way, or on round if it is past carryDeg and still rotating. Measured hands off from 110 km/h: a bail at 150 degrees is straight in 1.9 s, at 110 in 1.5, at 60 in 0.9, at 28 in 1.4, all ending on zero with no swing past. The wheel overrides. Below finishFromDeg the damping and the hands-off assist do the job. 0 authority disables all of it. | — | — | — |
| slideYawDamping | Yaw damping while the driver is NOT throwing, Nm per deg/s. A slip-angle tyre model has no yaw stiffness once both axles slide, so a released slide kept rotating at 110 deg/s to 180 with full counter-steer on. This stands in for the rear's self-aligning and is what catches a released slide (let go at 28 degrees hands off: peaks about 60, settles straight). Off under the lever, where the controller holds the rate. | ↓ | ↓ | — |
| driftAssistHandsOff / driftAssistHandsOffBelow | When the wheel is centred (|steer| under the threshold) the assist rises to this and does not fade with angle. With no permission in, lift and straighten means "bring it back". Under a hold (lever or gas) the controller owns the angle and the assist only aligns the fronts with the path; that cut the speed a held slide bled from 23 km/h over 4 s to 6, because fronts sitting 27 degrees off the velocity were most of the drag. Hands on, the driver's authority is untouched. | — | — | — |

## handbrake
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| rearGripMultiplier (0.45) | Rear grip while pulled. Lower = snaps out faster. This is the knob that pays for a softer rear falloff: the gentler the falloff, the deeper this has to cut to initiate in the same time. | ↓ | ↓ | — |
| brakeForce | Rear drag while pulled. 1,000 now; at 8,000 the lever alone was 0.5 g, 11 km/h for every second of a spin, and the throw controller does not need the drag for rotation. Raise it for a lever that visibly slows the car. | — | — | — |
| releaseSeconds | How long the grip takes to come back after the lever is let go. 0 snaps it back in one step, which jolts the car straight; longer hands the slide off to the throttle more gently. The throw controller is scaled by this fading level too, so the rotation lets go with the grip. | ↑ | — | — |

## drift (the pedals in a slide; `VehicleSim/DriftControl.luau`)

Asked by the owner on 2026-10-05: drift styles by drivetrain, "the ability to kick off the exhaust during a drift where the flames would also flutter like in drifting videos", and then the drift overhaul ("from throlle bursts to stable trifting and the standdard hajwala 360s"). These are the **Classic** mode's numbers, the car as it was; every mode sets its own (`DriftStyles`, below). None of the pedal knobs acts while the lever is in: the lever's 360s, holds and catches are the same on every mode. In the overhaul's modes **the throttle sets the angle** (research: a saturated rear trades side force for drive, so more gas is more angle): gas held widens a slide toward the band's top, a lift tightens it (and flutters the exhaust), a stab kicks it.

| Field | What it does | Which way |
|---|---|---|
| featherSeconds | A lift shorter than this keeps a gas-held slide (a feather), so the exhaust can be set off mid-drift. Not with the lever in: a lift under the lever drops the gas hold at once, as before, so letting go of the lever and the gas together is the catch it always was (and the lever stops a lift throw it meets). Before it, a 0.25 s lift took a 30-degree slide to 1 degree a second later; now 0.2 s lifts keep it at 27-30. A longer lift is the catch, as before, so a hands-off catch waits this long first. 0 is the old car. It is also the window for the clutch-kick entry (kickThrow). | Longer: more forgiving feathers, a later catch |
| featherDegPerSec | How the angle moves during a feather, + toward straight (rear drive regains grip on a lift), - away from it (front drive's lift-off oversteer, Rally's rotation). Classic 50: a hands-off catch takes 0.59-0.68 s (0.82 at 25, 0.53 with no feather) and a 0.2 s feather dips the slide 3 degrees. High Angle 55 for 0.25 s: the catch from 55 degrees in 0.90 s (35 for 0.3 s: 1.01). | Higher: a feather tightens more and the catch is quicker |
| kickDeg / kickSeconds | The gas back inside a feather adds this much angle over this long: the clutch-kick feel on rear drive, - pulls it in on front drive and Rally. Classic 8 (each 0.2 s lift-and-stab nets -2: 42 > 35 > 40); Hajwala 8 (39 > 35 > 42); Kick 14 (43 > 39 > 50). | Bigger: a bigger kick |
| kickDriveScale | The driven wheels' drive times this for kickSeconds after a stab: the clutch dumped, a burst of wheelspin, revs and smoke under the kick (research: about a 2x pulse for 0.15-0.3 s). Kick 2, Hajwala and High Angle 1.5. 1 is none. | Up: a bigger surge |
| holdDecayDegPerSec | A gas-held angle moves toward straight this fast; - grows it (the gas widens the slide toward holdMaxDeg). Research: 10-20 deg/s of throttle-driven growth (the slowest build-up fails least). Hajwala -12, Kick -15, High Angle and Drift Mode -10; front drive's gas pulls it straight (Tafheet 15: a 31-degree slide straight in about 2 s, gaining 96 to 128 km/h), Rally 6 to its floor. | - wider on the gas, + straighter |
| holdMinDeg / holdMaxDeg / holdEaseDegPerSec | A gas-held angle is kept between these, moved at this rate. Under the band it grows even through the straight moment of a transition. Hajwala 20-40 (holds 40), Kick 25-45 (45), High Angle 45-55 (54), Rally 15-30 (18), Drift Mode 25-40 (39), Tatweef 12-25 (21). | — |
| keepThrottle / partialDegPerSec | Part throttle (a trigger): over keepThrottle an armed hold stays, tightening toward straight by up to partialDegPerSec the further it is off full gas: the gamepad's throttle angle. Arming still takes steering.throwThrottleHold. 1 / 0: as before (any lift under the gate is a feather). Hajwala, Kick, High Angle and Drift Mode 0.35 / 25-35. A hold on part throttle lets go straight with the wheel centred for the grace, as on full gas, and may tighten under holdMinDeg; a trigger let go and pressed again still kicks as it passes through. | Lower keep: lighter throttle still holds |
| liftFrom / liftTo / liftWindowSeconds | What a lift is, for the lift throw and the exhaust's bursts and drift flutter (EngineAudio reads it through `DriftControl.liftStep`, with its own `crackleLiftFrom`): the throttle under liftTo within liftWindowSeconds of having been at liftFrom or more. A one-step edge missed a gamepad trigger let go by hand, which passes through the middle over two or three frames; now a 1 → 0.5 → 0.05 release mid-drift fires the flutter. Easing off over a third of a second is not a lift. | Longer window: slower lifts count |
| liftThrow / liftThrowSeconds / liftThrowMinKmh / liftThrowSteer / liftThrowRearGrip | The lift throw (0 off; Lift-Off has one): a lift (above) at liftThrowMinKmh or more with the wheel past liftThrowSteer, before the car is sideways, throws it with this permission and the rear's grip times liftThrowRearGrip for liftThrowSeconds. Lift-Off 0.3 for 0.4 s at 0.6 grip: a full-key lift at 100 peaks 32 degrees. | Up: a bigger swing |
| kickThrow / kickThrowSeconds / kickThrowMinKmh / kickThrowSteer / kickThrowRearGrip | The clutch-kick entry (0 off; Kick has it): on the gas with the wheel past kickThrowSteer at kickThrowMinKmh or more, before the car is sideways, a real lift (under liftTo: a trigger wobbling under the gate is not one) and the gas back inside featherSeconds throws it (FR Legends' double tap; hajwala's neutral drop at speed), with the drive surging. Kick 0.5 for 0.3 s at 0.7 grip: at 120 km/h, 20 degrees in 0.25 s, held at 44. | Up: a bigger kick |
| brakeThrow / brakeThrowSeconds / brakeThrowMinKmh / brakeThrowSteer / brakeThrowRearGrip / brakeThrowFrom | The brake entry (0 off): the brake past brakeThrowFrom **on the gas** (a left foot) with the wheel past brakeThrowSteer at brakeThrowMinKmh or more, before the car is sideways, throws it once per press (left-foot braking; the rally pendulum's brake). Off the gas the brake is only a brake: the final review found braking into a corner threw Rally, a default. Pivot 0.5 for 0.35 s at 0.6, Rally 0.45 at 0.6 (measured below). | Up: a bigger throw |
| brakeGrowDegPerSec / brakeGrowBrakeScale | The pivot (0 off): brake and gas together on a held slide grow it this fast, with the brake's force times brakeGrowBrakeScale meanwhile (a light left foot; a key is a full 14 kN brake). Pivot 35 / 0.25: 31 to 39 degrees in half a second, 97 to 94 km/h (25 netted +5 against the gas's pull). | Up: a faster pivot |
| powerOverSteer / powerOverMinKmh / powerOverMaxKmh / powerOverThrow / powerOverRearGrip / gasHoldFromScale | Power-over: past powerOverSteer launch and traction control step aside (above 1 never), and with powerOverThrow above 0 the gas and that much wheel between powerOverMinKmh and powerOverMaxKmh throw the car (that permission, the rear's grip times powerOverRearGrip) until the gas hold takes it, which it does from throwThrottleHoldFromDeg x gasHoldFromScale. Traction control aside alone never broke the rear (1-3 degrees at 50-80 km/h: the rear's drive grip is set for the launch). Kick 0.7 / 30 / 90 / 0.5 / 0.8 / 0.5: 20 degrees in 0.52 s from 60 km/h, held 46; over 90 (a highway lane change) never. | — |
| dialMaxDeg | The ceiling: steering into a slide held without the lever or a flick (the gas hold, and the lift, brake, kick and power throws) adds no angle past this, so the wheel held into a slide takes it wider and the line carries it that way, where it used to spin (Classic, from 70 km/h with the wheel held into it: round to 180). 180 is none: full lock on the gas spins the car, the gas 360 (Classic and Kick: 2.69-2.80 s). | Down: harder to over-rotate on the gas |
| dialIntoScale | Steering into a gas-held slide turns the angle at this share of the throw rate; counter-steer keeps the whole rate, so a transition swings through at full speed (research: countersteer about 1.5-2x faster than steer-in). 1 is the old dial (Classic, and Kick, which keeps the gas 360); the other new modes 0.25-0.6. | Down: the wheel grows the angle more gently |
| slideReliefScale | Times the car's slide momentum relief (slipModel.slideRelief); the lever's is its own. High Angle 1.3, Rally 1.4, Tatweef 1.3. | Up: more speed carried sideways |

## line (where a held slide goes; `VehicleSim/Line.luau`)

The owner, 2026-10-05: "make sure its easy to control the sideway drifting within the highway boundries". While a slide is held (the gas hold, a throw, the lever, and the throw's tail after it), a sideways push at the centre of mass takes the slide's own curve out and aims it with the wheel. At the centre of mass and square to the velocity, it has no yaw moment and does no work: the angle, the 360 and the catch are the throw controller's, the speed is the tyres'. Off (0) on Classic; the new modes set it. Measured on the Kamri at 100 km/h, wheel centred, 1-5 s of a gas-held slide (a carriageway is 38 m): Classic turned its path 73 degrees and went 81 m sideways; with the line, 7 degrees and 9 m (Hajwala), 0 and 0 (Tatweef). A lever 360 from 110 ended 20 degrees off and 22 m over on Classic, 5-7 and 3-4 m on the new modes; a six-swing Tanteel chain wandered 49 m on Classic, 3-8 m on the new modes.

| Field | What it does | Which way |
|---|---|---|
| hold | How much of a held slide's own curve is taken out with the wheel centred: 0 is the tyres' circle, 1 dead straight on. Hajwala 0.9 (9 m in 4 s, toward the nose), Kick 0.85 (13 m), Tafheet 0.95, Tatweef 1 (0 m). | Up: straighter |
| steerG | Sideways g toward the steered side at full steer: how fast the wheel moves a held slide across the lanes. 0.35 (Kick 0.3, Tatweef 0.5). | Up: quicker across |
| intoRelease | Steering into the slide lets this share of the hold go at full steer: the wheel held into a drift is a corner being taken (from 70 km/h, the path turns 41 degrees in 1.8 s at 54-66 degrees of slide). | Up: drifts take corners tighter |
| leverHold / leverSteerShare / leverMinKmh / leverFullKmh | Under the lever: its own hold from straight up (a spin's onset is where its path turns), only leverSteerShare of steerG (the wheel turns the spin), faded in over 60-90 km/h so a highway 360 goes on down the road and a handbrake turn at city speed stays a turn. | — |
| maxG | The most the line adds, 1 g (a held slide's tyres pull 0.8 g). | — |
| fromDeg / fullDeg / minKmh / fullKmh | It fades in from 8 to 16 degrees of drift and 30 to 50 km/h (not under the lever), so turning and parking never feel it. | — |

## DriftStyles (the drift modes; `src/shared/DriftStyles.luau`)

A mode is a name, a drivetrain, a one-line blurb and a partial CarConfig deep-merged over a copy of the car's own config, only on keys no catalog car tunes (spec'd), so each car keeps its character. The car's drivetrain picks which modes it can take; the first is its default. Each drivetrain has **Classic**, the drift-feel default, and three modes. **Picking one: the tyres** (garage-tyres-flames, 2026-10-05; the owner: "make the differnt driftmodes we made different tire options in the garage instead of drift options in the car menu. by default start all at classic"). Each mode but the Classics is a tyre in `CosmeticsConfig` (category `tyre`: `driftStyle`, `layout`), 25,000 each, bought once for every car of its drivetrain and fitted per car like rims; the free stock tyre (`tyre_classic`) is each drivetrain's Classic. The garage's WHEELS tab lists the car's own drivetrain's tyres under its rims, with the blurb of the tyre showing; the server refuses a tyre on a car of another drivetrain. The client's `DriftStyle` reads the tyre from the car's `Look` attribute, and a tyre that no longer fits (the catalog changed the car's drivetrain) drives as Classic. **In Studio:** O cycles the car's modes (LocalPlayer attributes `DriftStyle_RWD` / `_FWD` / `_AWD`, which win over the tyre), Shift+O every mode on any car (`DriftStyleAny`), with a label for 1.5 s. **L** reloads the modes' numbers too, and the Studio-only `DriftLab` attribute (a JSON partial config, e.g. `{"line":{"hold":0.8}}`) is merged over the car's styled config live. Design and research: `docs/superpowers/specs/2026-10-05-drift-overhaul-*.md`.

Measured with the harness at 54-59 fps with the keyboard's steer ramp emulated (Kamri for rear and front drive, Batrol for all-wheel drive; a slide is a 0.3 s lever tap with full key at 100 km/h handed to the gas, wheel let go; a burst is a 0.2 s lift and the gas back, shown as before > lowest > highest after):

| Mode | Drive | Held 1-5 s (angle, speed, path, sideways) | Bursts | 360 from 110 (time, exit, path, over) | Catch | Entry |
|---|---|---|---|---|---|---|
| **Hajwala** (default) | rear | 40° (sd 0.5), 96 → 90, 7°, 9 m | 39 > 35 > 42 | 2.54 s, 83, 7°, 3 m | 0.78 s | lever / flick; tapped lane change 2.6° |
| **Kick** | rear | 45°, 95 → 86, 11°, 13 m | 43 > 39 > 50 | 2.53 s, 83, 7°, 3 m; gas 360 2.80 s at 78 | 0.83 | power-over at 60: 20° in 0.52 s, holds 46; double tap at 120: 20° in 0.25 s, holds 44 |
| **High Angle** | rear | 54° (sd 0.6), 95 → 85, 7°, 9 m | 53 > 47 > 56 | 2.53 s, 83, 7°, 3 m | 0.90 | 0.6 s presses chain 41-53° inside 3 m |
| Classic | rear | 39°, 96 → 90, **73°, 81 m** | 39 > 32 > 37 | 2.54 s, 83, **20°, 22 m** | 0.72 | gas + lock at 50/80: 1-3° |
| **Tafheet** (default) | front | the lever: 42° for 3 s, 100 → 65, 12°, 3 m; the gas pulls it straight (31 → 0 in about 2 s, 96 → 128) | — | 2.55 s, 78, 7°, 4 m | 0.62 | lever |
| **Lift-Off** | front | short: the gas pulls it in at 12°/s | — | 2.55 s, 78, 6°, 4 m | 0.60 | full-key lift at 100: 32° |
| **Pivot** | front | the gas pulls it in; brake and gas together 31 → 39° in 0.5 s, 97 → 94 | — | lever | 0.68 | left-foot brake (gas and brake) at 100 with the key held: 46°; braking into a turn off the gas at 60: 8°, no throw |
| Classic | front | 22°, 99 → 98, **57°, 76 m** | — | 2.55 s, 78, **21°, 26 m** | — | — |
| **Rally** (default) | all, 45:55 | 18° (14-25), 97 → 95, 8°, 9 m | 24 > 18 > 25 | 2.83 s, 82, 5°, 3 m | 0.70 | left-foot brake at 100: 32°; braking into a turn off the gas at 60 / 90: 7° / 6° (Classic 8°) |
| **Drift Mode** | all, 20:80 | 39°, 96 → 89, 7°, 8 m | 41 > 36 > 42 | 2.62 s, 85, 6°, 4 m | 0.75 | chain 24-40° inside 5 m |
| **Tatweef** | all, 41:59 | 21° (sd 0.1), 97 → 94, **0°, 0 m** | — | 3.19 s, 79, 6°, 4 m | 0.70 | steered across the lanes |
| Classic | all | 33°, 96 → 83, **70°, 76 m** | — | 2.65 s, 83, **22°, 26 m** | — | — |

Launches are the car's own on every mode (Kamri rear drive 0-100 3.65-3.67 s, front drive 4.17-4.21; Batrol 5.13-5.17).

| Field | What it does | Which way |
|---|---|---|
| styles[].tuning | The mode's numbers: `line.*`, `drift.*` (above), `drivetrain.frontShare`, `tires.front.longitudinalGrip` (front and all-wheel drive take the rear's 1.9: at 2.3 the front-drive launch was 3.9 s but the 360 took 3.42 s and the catch 1.25), `steering.throwYawRateDegPerSec` (the 360's rate: Rally 140, Tatweef 125, the rest 150) and `steering.throwFinishFromDeg` 15 for front drive and Rally, 20 for Drift Mode (the hands-off catch's authority from there) | — |
| order | Shift+O's order; within a drivetrain the first is its default (Classic, the free tyre). The garage lists tyres in `CosmeticsConfig.items` order | — |
| layoutName | The drivetrain's name over the garage's tyres and on the spawn menu's cards | — |

**The owner's feel knobs for drifting:** which mode is each drivetrain's default (`order`) and what the tyres cost (`CosmeticsConfig` items, `price`); `line.hold` (how straight a held slide runs) and `line.steerG` (how fast the wheel moves it across); `holdDecayDegPerSec` with `holdMinDeg` / `holdMaxDeg` (how far the gas widens a slide); `featherDegPerSec` / `kickDeg` / `kickDriveScale` (how a lift and a stab feel); `dialMaxDeg` / `dialIntoScale` (how much the wheel grows the angle); `steering.throwYawRateDegPerSec` (how fast a 360 comes round); `FRONT_DRIVE_GRIP`; and each car's `layout` in the catalog.

## twoWheel
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| liftTorque | Roll torque while lifting. **15,000** is the shipped value. 18,000 was tried for a bigger first tip and came back as too strong and overwhelming; 12,000 took a second and read as heavy; 20,000 with less damping overshot to 58 with the tip at 62. | — | — | ↓ (gentler arrival) |
| gravityCancel | Fraction of gravity's restoring torque cancelled while balanced. 1 = neutral pendulum, which needs nothing from the driver. 0.93 leaves enough gravity in that an ignored car drops back and lands in 3 s and a tap every 1.5 to 2 s keeps it; 0.9 needed one every second. This is the difficulty knob. | — | — | ↓ |
| targetRollDeg | Angle where lifting hands over to balancing. Keep below atan(tire grip) ≈ 45° or the base slides out. | — | — | ↓ |
| leanTorque | Constant outward push while balanced. Keep it small: throttle already pushes the car outward (only the grounded rear drives, so gas yaws the car away from the low side). At 400 the car leaned in at 12°/s under 0.4 throttle and a tap was erased in half a second; at 150 it wobbles slowly (from 40° up to 50° and back to 28° over 2 s with no input) and three E taps hold it at 40°. | — | — | ↓ |
| instability | Extra outward push per degree above targetRollDeg. 8. | — | — | ↓ |
| rollDamping | Resists roll rate while balanced. 60: this is the "heavy" knob. 80 made every tap answer slowly; 45 let the lift overshoot to 58°. | — | — | ↑ |
| leanInTorque | Gain of a fresh press toward the lifted side. With the tap envelope it lands all at once and decays, and it also rewinds the balance spring, which is most of what "keeps it up". 5,500. | — | — | ↓ |
| leanOutTorque | Gain of a fresh press toward the grounded side. This is the catch: 4,500 drops the car about 12° a tap; 6,000 was 16 and too much. Held, it lands the car in 0.35 s. | — | — | ↑ |
| tipRollDeg | Where the controller lets go. Set past the static tip (≈56°) so a tip is a real fall. | — | — | ↑ |
| rimGripStartDeg / rimGripBoost | Roll where rim dig-in starts and how much grip it adds. Without it the base slides out at ~45° and a tip is impossible. | — | — | ↓ boost |
| landingDamping | Softens the drop back to four wheels. 30: a drop should be a drop, not a float. | — | — | ↑ |
| suspensionBias | Loaded-side spring multiplier while lifted. | — | — | ↑ |
| minLiftSpeedKmh / fullLiftSpeedKmh | Nothing lifts below the first (90, the owner's rule: a tap at 75 does nothing, at 95 it lifts); lift torque scales up to full at the second (100). | — | — | ↑ min (harder to start) |
| holdFadeSpeedKmh | The balance controller's authority fades from full at minLiftSpeedKmh to nothing at this speed (60), so a car that stops keeping its speed up comes back down on its own even while the driver is tapping: measured, lifted at 100 with the gas off and a light brake, under 90 at 3.2 s and landed at 4.5 s. | — | — | ↓ |
| leanHoldDecaySeconds / leanHoldFloor / leanInHoldFloor | Tap envelopes. A fresh press lands the whole lean gain at once, then decays to the floor over the decay time while held. The catch key decays to leanHoldFloor (0.3), so a held catch is a landing. The key toward the lifted side decays to leanInHoldFloor, which is **0.3, the same as the catch key**: held, it stops pushing rather than carrying the car over. 1 makes a held key topple in 1.1 s, which was tried and came back as too punishing. | — | — | ↑ floor |
| balanceSpring | Spring toward targetRollDeg while balanced, Nm per degree. 320 was a magnet; 160 held the car by itself; 110 needs working. | — | — | ↑ |
| balanceSpringOneSided | **false**, the shipped setting: the spring works both ways, so it lifts a sagging car and pulls a high one back down, and the car settles to a hover near the target instead of going over. true makes it lift-only and silent above the target, which is what made leaning on the in-key topple. The two together (true plus leanInHoldFloor 1) are the unforgiving version. | — | — | false |
| balanceSpringDecaySeconds / balanceSpringFloor / balanceCancelFloor | The rhythm. The mode latches on a tap, and the spring then winds down to its floor over the decay time with no tap toward the lifted side; the gravity cancel winds down on the same envelope to its own floor (a fully cancelled pendulum is neutral at every angle, so without this the ignored car hovered at 9 degrees). Measured at 90 km/h: one tap lifts to 35 and the car lands itself in 4.4 s; a tap every 2 s holds 16 to 30; every 3 s is the edge. The engine's torque on the grounded rear holds the car up too, which is why the cancel floor went 0.85 to 0.8 with the torque bump. Longer decay or higher floors is a lazier ride; both floors at 1 never sinks. | — | — | ↑ decay |
| landHoldSeconds | The key toward the grounded side held this long is a landing, not a catch: the controller lets go and the car comes down in about half a second. | — | — | — |
| tapBoost / tapBoostFullDeg / tapBoostSeconds | The keep-up tap's lift: a pulse that swells to tapBoost of liftTorque halfway through tapBoostSeconds and back, full once the car has sagged tapBoostFullDeg below the target, less the closer it is, nothing above it (tapping cannot flip the car). 0.6 over 0.5 s; the carry does the lingering, so this only has to lift. | — | — | ↑ |
| carrySeconds / carryTapSeconds / carryFadeSeconds | The carry: after the launch (carrySeconds) and after each tap toward the lifted side (carryTapSeconds) the balance holds firmer, at full until the last carryFadeSeconds and then fading to normal. The catch key ends it at once. Measured at 100 km/h, one tap: above 25° for 2.5 s and down at 3.7 s (was 1.2 and 2.6); a tap every 2 s: above 25° for 5.2 of 9 s and never lands (was 3.0 and landed); every 1.5 s: holds 20-36° (was 11-34). Longer is a lazier ride. | — | — | ↑ |
| carrySpring / carryMaxTorque | How firm the carry is: carrySpring extra balanceSprings on the error from the target, capped at carryMaxTorque. The cap is what keeps it smooth: uncapped, a tap at 15° jolted the roll rate 214°/s in a step; capped at 3000, tap jolts are 16-31 (one rescue at the drop point, 69). A magnet-like hold is carrySpring up with no cap. | — | — | ↑ |
| dropReleaseDeg / dropFadeSeconds | Sagged under this with no tap toward the lifted side, the controller lets go over dropFadeSeconds (a one-frame cut was a jolt; a tap during the fade catches it) and gravity drops the car: it lands at 66°/s instead of being lowered in at 20. Lower keeps a slow-tapping driver up longer but lands softer; 0 lowers it all the way, as before. | — | — | ↓ |
| touchdownSeconds / touchdownDampingScale | After a two-wheel landing the suspension damping starts at this fraction and eases back to full over this long, so the drop rocks the car and then settles without a snap. 0.35 held flat for 0.6 s bounced it back up to 11.8° at 214°/s; 0.6 easing over 0.8 s is the shipped value. Lower scale or longer is a bouncier landing. Never touches ordinary driving. | — | — | — |
| leanAttackSeconds | A fresh lean press ramps to full over this long instead of landing on one frame. 0.06: short enough to read as a tap, long enough that the tap is not a jolt. | — | — | — |
| steerScale | Steering lock while lifted. 0.3: a 0.3 steer toward the low side for 0.3 s drops the car 17°, which is the lever a real skier uses. Steering is the strongest balance lever on two wheels (toward the low side drops the car, away lifts it) and at full lock a short tap flips it. Measured at 80 km/h with 0.22 and steerAwayScale 0.5: a 0.5 tap toward drops 10°, the same tap away leans 20° and is still catchable, a full-lock tap away tips. Raise for a twitchier, more expert car. | — | — | ↓ |
| steerAwayScale | Extra scale on a turn away from the low side while lifted, the direction that flips the car. Toward the low side keeps the full steerScale. | — | — | ↓ |
| yawDamping | Steady yaw damping while lifted, Nm per °/s: the driver's micro-corrections, so a natl runs straight. Measured at full throttle: 3° of heading drift over 4 s at 250. | — | — | ↑ |
| sidePickLean | Lean magnitude that picks the roll side (E/right = roll right). With nothing held, as when touch opens the mode with NATL, the car rolls left. | — | — | — |
| sidePickRollDeg | While lifting below this roll, a lean the other way still flips the side. This is what lets a touch player pick the side after NATL has already started the lift. | — | — | — |
| balancedEntryMarginDeg | Lifting hands over to balancing this many degrees before the target. | — | — | ↑ (earlier handover, less overshoot) |
| landedRollDeg | Roll under which the car counts as landed. | — | — | — |

## input
Lean is deliberately not ramped on any platform: balancing wants the torque the instant the
key or button goes down.

| Field | What it does |
|---|---|
| keyboardSteerRampPerSec / keyboardSteerReturnPerSec | Digital steer ramp. 4 = full lock in 0.25 s. |
| touchSteerRatePerSec | How fast the wheel chases the touch steer buttons, in full-locks per second (the buttons ramp their own ask first, 4.5/s out and 8/s back, in `HudLab/LayoutD.luau`). 8 = lock to lock in 0.25 s. Higher = snappier, lower = calmer. |
| gamepadDeadzone / triggerDeadzone | Stick and trigger deadzones. |

## camera
| Field | What it does |
|---|---|
| positionLag / directionLag | Smoothing rates (1/s). Lower = lazier camera. |
| profileBlendRate | How fast profile parameters cross-fade (1/s). |
| minSpeedForSwingMps | Below this the camera ignores velocity direction. |
| driftProfileEnterDeg / driftProfileExitDeg | Drift angle that switches to the drift profile and back (hysteresis). |
| followAhead | The follow carries this share of the car's own velocity, so at a steady speed the camera trails only (1 - followAhead) of v / positionLag. 0.7 (speed-feel, 2026-10-05): at 0 it trailed 8.4 m extra at 240 km/h and the car shrank to a speck; under acceleration it still pulls back. 0 is the old follow. |
| shake | A faint pitch and yaw shake with speed, from fromKmh to fullKmh, up to maxDeg, at about hz (130 / 320 / 0.2 / 7; 300 / 0.18 before the extra 10%). Subtle: the car must never look unstable. 0 maxDeg is off. |

### camera.profiles.normal / drift / twoWheel
The two-wheel profile is active while lifting or balanced; the drift profile past the enter angle; normal otherwise.
| Field | What it does |
|---|---|
| distance / height / lookHeight | Where the camera sits and aims, metres. |
| lateralOffset | Sideways offset: toward the lifted side on two wheels (airborne wheels in frame), toward the outside of the slide in the drift profile. |
| driftSwing | 0 looks along the heading, 1 along the velocity direction. |
| maxHorizontalFov (camera) | The widest the view may get across: 126 degrees, what a 16:9 screen sees at 96 vertical. The profiles' FOVs are vertical, so without it a 19.5:9 phone saw 135 across; it stops at 84 vertical there. |
| baseFov / fovPerKmh / maxFov | Speed-widened field of view (vertical, degrees). Normal 70 + 0.11 per km/h up to 96 (81 at 100, 92 at 200), drift 74 + 0.1 to 98, two-wheel 72 + 0.07 to 90; it was 0.08 up to 85 (speed-feel, 2026-10-05). A wider view streams the roadside past faster at the edges; the car looks smaller. |
| rollFollow | Fraction of the car's roll applied as horizon tilt. Two-wheel profile only, by default. |

### camera.views (client `CameraViews`)
Views to drive in, cycled with **V** or the phone's CAM button (left of STYLE); the name shows for a moment ("VIEW: CLOSE"). The choice is the LocalPlayer attribute `CamView` (a view's id) and lasts the session. The owner, 2026-10-10: "create different views for when im driving the car (at least 5 for testing purposes, feels to far and zoomed out right now)"; after trying five (with LOW, roof height looking level, and HIGH, looking down from 3.35 m): "make chase defauly have close and far be sepperate options". Each view is where the **normal** profile sits and how wide it sees; drift and two-wheel keep their own difference from normal, scaled: distance and lateralOffset by the view's distance over normal's, height by its height over normal's, lookHeight and both FOVs moved by the view's, fovPerKmh scaled so each view reaches its maxFov at the same speed. FAR is normal as it was, the camera from before views. The first view is where a session starts.

Heights are from the chassis's centre (1.0 m above the road on the Krown Vik Fleet). Closer in at the old height and aim, the car ran off the bottom of the screen (CLOSE at 5 m, 1.7 up, aim 0.8: its tail at 1.35 of the screen's height), so each view's height and aim (lookHeight; below 0 aims under the chassis's centre) were fitted in Studio on the Krown Vik Fleet, the biggest box (6.5 m with mirrors and tips), to keep the whole car on screen with the horizon showing. Measured parked, as fractions of the screen's height from the top:

| View | distance / height / lookHeight (m) | baseFov → maxFov | Car on screen | Horizon |
|---|---|---|---|---|
| CHASE (start) | 6.2 / 1.75 / 0.15 | 66 → 88 | 0.41-0.88 | 0.30 |
| CLOSE | 5.3 / 1.35 / -0.25 | 64 → 84 | 0.34-0.96 | 0.26 |
| FAR | 7.5 / 2.6 / 0.8 | 70 → 96 (the old camera) | 0.49-0.83 | 0.33 |

Closer: smaller distance. Lower: smaller height. Car higher on screen: smaller lookHeight (aims lower). Less zoomed out: smaller baseFov and maxFov. The car's tail sits behind the bottom-middle tacho in every view.

**DRIVER** is the fourth view, first person (`camera.firstPerson` below). It is only for cars in `CarCockpits`; on any other car (only the generated Kamri, off the menu, since 2026-11-08) the view in use is CHASE and V skips DRIVER, while `CamView` keeps it for the next car with a cabin.

### camera.firstPerson (client `CameraRig`, `SteeringWheels`; `CarCockpits`)
First person from the driver's seat, with the steering wheel turning (the owner, 2026-11-07: "work on the first person view for all of them and the steering wheel moving also in first person"). The eye sits at the car's `CarCockpits.eyeM` and moves rigidly with the cabin, roll and pitch included. The local character is hidden on this client only. The chase camera keeps following underneath, so switching back is seamless.
| Field | What it does |
|---|---|
| baseFov / fovPerKmh / maxFov | Vertical degrees (70, +0.05 per km/h, up to 82). At 74 the roof lining took the top third of the screen in the sedans. Narrower = less roof and dash, more road. |
| glassClear | The car's own glass while in first person, as a LocalTransparencyModifier (0.6): the Krown Vik's tint was a milky sheet from the seat. Higher = clearer. Others still see it tinted. |
| lookIntoSlide / lookIntoSlideMaxDeg / lookIntoSlideRate | In a slide the view turns toward the way the car is travelling, by this fraction of the slide angle (0.5), at most 40°, following at 6/s. 0 keeps it on the bonnet. |
| maxLookYawDeg / maxLookPitchDeg | How far free look turns the head (140 each way, 50 up and down). The same drag that raises the chase camera looks down here. |
| shakeScale | The speed shake as a fraction of the chase camera's (0.4): the eye is fixed to the car, which already carries the road. |
| wheelTurns | How far the steering wheel turns at full lock, each way: REAL 450° (the owner's pick), HALF 180°, QUARTER 90°. Chosen in SETTINGS (WHEEL TURN), kept on the LocalPlayer attribute `WheelTurn`. The wheel follows the front hubs' angle over `steering.maxSteerDeg`, so it counter-steers in a slide as the tyres do, on every car this client sees. |
| wheelDrawDistanceM | Steering wheels turn only on cars this near the camera (40 m). |

**`arms`** (client `CockpitArms`; branch `first-person-arms`, an experiment; the owner, 2026-11-07: "can u try make it so that the characters arms also show?"). The avatar sits 0.1 to 0.4 m ahead of and below the eye, so its own shoulders would float in front of the camera; these are copies of its arms (its colours and shirt) for this client only, each bent at the elbow from a shoulder under the eye to a grip on the rim. ARMS in SETTINGS (the LocalPlayer attribute `FirstPersonArms`) switches them off.
| Field | What it does |
|---|---|
| shoulderM | Each shoulder from the eye, car metres: 0.2 out, 0.26 below, 0.06 behind. Lower shoulders: flatter forearms, less arm on screen. |
| upperArmM / forearmM / handM | Segment lengths (0.30 / 0.27 / 0.09 m, an adult's). Longer arms bend less at the elbow. |
| thickness | The avatar's arm thickness times this (0.7; 0.8 read chunky across a turn). |
| gripDeg | Where the hands hold the rim, degrees each side of the top (60: ten to two). |
| followDeg | The hands turn with the wheel this far, then the rim slides through them. 720: past every wheel turn, so they hold on all the way and the arms cross over (the owner: "make sure the arms follow the wheels all the way ... even if they cross over"). Checked at 180°, 270° and full lock (450°) on the Sonatta. 60 keeps the arms apart (ten to two turns only to twelve and four). |

Per car (`src/shared/CarCockpits.luau`): `eyeM` (0.29 m above and 0.62 m behind the wheel's centre, lowered where the lining still filled the view: Akord 0.05, Kamri SE 0.03, Krown Vik 0.04), and `wheel` (the pieces, the pivot and the column axis, fitted from the pieces' own triangles; every column leans back 18 to 28°). Higher eye: more bonnet and roof. Further back: smaller wheel.

### CarDashes (working dash gauges; client `DashGauges`)

The speed and rev needles in the dash of the car you drive, for the cars whose store model came with gauges (the owner, 2026-11-08: "yea put those guages back"). Each dial is an invisible part placed in car space (`posM`, `rotationDeg`, `sizeM`, like a catalog piece) with a SurfaceGui on `face`; the needle turns `zeroDeg + degPerUnit * value` degrees clockwise from the canvas's left, held at `maxDeg`. `reads` is `speedMph` (the dials are marked in mph) or `rpm`.

| Car | What it is | Needles |
|---|---|---|
| Krown Vik | the store kit as it was: white needles, backlit numbers (0-160 mph, 0-7 x1000) and a gear and clock screen, on its blank dial openings | -30 + 1.5 a mph; -30 + 0.03 a rpm |
| Tahu | its own red needles on its printed dials (the store kit was behind the dash, the wrong way round) | -7.5 + 1.67 a mph to 120; -9.8 + 0.03374 a rpm to 6000 |
| Kamri SE | its store blue needles, on square screens, the rev dial moved 4 cm onto the printed centre | -15.6 + 1.553 a mph to 140; -96 + 0.01572 a rpm to 8000 (its screen is turned a quarter) |

Measured in Studio: the Tahu's hubs sighted from two eyes, each needle fitted to its printed numbers (within 3 degrees). The Tahu and Kamri SE dials print their own needles, which stay visible at rest beneath ours. To move a needle onto a printed number, change `zeroDeg` (the whole sweep) or `degPerUnit` (the spread); `needle.lengthPx` / `widthPx` / `startPx` size it on its 210 px canvas.

### camera.freeLook (client `FreeLook`)
Looking around while driving (the owner, 2026-10-10: "allow me to freelook while driving, resets after i a) on phone let go or b) on pc resets after a seccond or 2 in the same mouse position"). The camera swings round the car from where the follow put it: yaw all the way round, pitch from minPitchDeg (lower, looking up) to maxPitchDeg (higher, looking down). The follow carries on underneath, so the glide home lands on a camera that kept up. The glide starts and ends slowly (smoothstep), so it never snaps.
| Field | What it does |
|---|---|
| degPerPixel | Mouse: degrees per pixel moved while the **right button** is held (0.25). The cursor stays put while it looks (MouseBehavior LockCurrentPosition), so the view turns as far as you like. Any movement looked at first, but then the cursor could not reach a button without swinging the view (the owner: "will make it hard to click buttons... thing of an alternative"). |
| mouseHoldSeconds / mouseReturnSeconds | Mouse: after the button lets go, the view holds this long (1.5), then glides home over this long (0.6). |
| degPerScreen | Touch: degrees per screen width dragged, across and up/down (180). Only a drag that starts away from the controls looks (each control is Active, so its press arrives processed). |
| touchHoldSeconds / touchReturnSeconds | Touch: after the thumb lifts, the view holds this long (0.5), then glides home over this long (0.9). It sprang back at once at first, fastest at the start (6/s, about 0.5 s; the owner: "on mobile have it be a bit less 'eslastic'"). Longer = calmer. |
| minPitchDeg / maxPitchDeg | How far the camera may swing below and above where the view puts it (-10 / 40). |

## speedFeel (client `SpeedFeel`)
Speed you can feel (speed-feel, 2026-10-05). The desert highway is wide and sparse, so little streams past the camera at any speed. **Studio:** the LocalPlayer attribute `SpeedFeelKmh` forces the speed these and the camera read, so a parked car can be framed at 200 km/h.

| Field | What it does |
|---|---|
| lines.fromKmh / fullKmh / perSecond | Faint speed lines in the outer ring of the screen, running out from the point the car is heading for: none under 140, 60 a second at 280 (55 before the extra 10%). Only while the car goes where the camera looks: through a lever 360 at 190 they fade out from 1.2 s, when the car is backwards, and come back as it comes round. World-space particle streaks were tried first and read as smudges on the road from a chase camera. |
| lines.lifetime / innerRadius / midRadius / outerRadius / avoidDeg | Each lives 0.18-0.3 s, born between 0.5 and 0.75 of the half-diagonal and gone by 1.1; none within 35 degrees of straight down, where the car is. |
| lines.length / thickness / transparency / color | 0.08-0.2 of the half-diagonal (longer with speed), 3 px, 0.7 at their brightest (0.82 and 2 px were all but invisible in a still at 220). |
| wind.soundId / fromKmh / fullKmh / volume / pitchMin / pitchMax | A wind roar under the engine (Creator Store "loop_wind_05"), rising from 60 to full at 280 km/h, to 0.45, its pitch 0.8 to 1.25. Empty id is off. |

## road
| Field | What it does |
|---|---|
| lengthM / widthM / thicknessM | The straight. Segments are split automatically under Roblox's 2048-stud part limit. |
| dashLengthM / dashGapM / dashWidthM | Centreline dashes. |
| curveRadiusM / curveSweepDeg / curveSegments | The gentle left curve at the end. |
| padStartM / padLengthM / padWidthM | Transition pad: a wider stretch of the straight (default 900 to 1300 m, 160 m wide) for left-right swings. Edge lines mark its start and end. |
| bayLengthM | Parking bay depth. The bay and the player spawn sit on the transition pad's right-hand wing when the preset has a pad, behind the start line otherwise. |
| groundTileM | Sand ground tile size; the plane covers the straight, the curve and 500 m of run-off. |

## spawn
| Field | What it does |
|---|---|
| spawnHeightM | Cars spawn this far above rest and settle on their springs. |
| slotStartM / slotSpacingM | Bay slot layout, one per player. |
| settleSpeedMps / settleSeconds | A driverless car below this speed for this long is anchored. |
| fallBelowM | A car this far under the road is re-parked in its bay (self-healing). A destroyed chassis respawns the car. |
| exitGapM / exitLiftM | Leaving a car puts the driver beside the driver's door: this much clear space from the car's side (1.0 m), this far above the chassis centre (0.5 m). Up the gap if players land against the door. |

## autoFlip
Client-side, for the car you are driving (client `AutoFlip`, maths in shared `AutoFlip`). Owner, 2026-10-04: flip the car back over "seamlessly/naturally" when it capsizes; then the scripted roll was "to robotic": "if i get into a flipped (upside down or flat state) i can like turn my wheels to reflip back to normal ... make it look more natural", without waiting. A capsized car lying on something is rolled by a real torque about its long axis (a `RightingTorque` on the chassis, apart from the sim's, which keeps running): steer and it heaves up off its edge, tips past the balance point and drops onto its springs; let go and it falls back. Untouched, after a moment at rest it rolls itself the same way. Only a car wedged where it can't roll gets the old scripted roll, as a last resort. The R reset (back to the road) is unchanged.

Measured on the Kamri 07 (Studio, 2026-10-04): off its side steering, upright in 0.6-0.7 s, landing with one small bounce, settled within 0.2 s more; off its roof steering, 1.7 s (it rolls over its side, about 3 m across the road); hands off, 0.7 s at rest then up, 1.5 s off its side and 2.7 s off its roof from when it landed.

| Field | What it does |
|---|---|
| enabled | Master switch. |
| tiltDeg | Past this lean from upright, with no wheel on the ground, it counts as capsized (on its side or roof). 75: a natl balances at 35 and lets go at 62, so a natl never trips it. Lower catches a car resting at an angle against a dune; never below 62. |
| steerDeadzone / roofChoiceDeg | Steering past 0.15 rolls it. On its side either way rolls it back up the short way (steering "into the ground" used to roll it on over the roof and round, 270 degrees and 4 m across the road); past 135 degrees of roll (on or near its roof) the way you steer picks the side it goes over. |
| rollRateDegPerSec | The roll rate it is driven toward (120 deg/s); past the balance point gravity speeds it to about 200 as it drops onto its wheels. Lower reads heavier. |
| rollGain / rollTorqueG / rollRampSeconds | How hard it chases that rate (20 a second, so it pushes at the cap until rolling), the most torque, as a multiple of what holds the car's weight at half its height off its edge (1.5), and how long the push takes to build (0.35 s). At 2 with no build-up it jumped to 115 deg/s within 0.05 s and read as a machine; this heaves it up. Too low and it can't lift off its side: never below about 1.2. |
| releaseTiltDeg | It lets go once this upright (40 degrees), past the balance point, and gravity and the springs finish the landing. |
| groundGapM / rollMaxSpeedMps / rollMaxFallMps | Only a car lying on something can be rolled: its centre within half the car's cross-section diagonal plus 0.5 m of the ground, slower than 40 m/s, and (to start) falling slower than 1.5 m/s, so a tumble through the air can't be steered. The speed limit was 6 m/s, and a car on its roof slid a long way before it got that slow (owner, 2026-10-04: "make it so that i can flip back before coming to a complete halt"); now it can be rolled while it still slides. Rolling itself still waits for it to stop. |
| restSpeedMps / restSpinDegPerSec / settleSeconds | Untouched, it rolls itself once it has been slower than this, turning slower than this, for this long (0.8 s): the crash has finished. Shorter = sooner. |
| giveUpSeconds | If rolling itself hasn't got it up in 3 s (wedged against a wall, say), the scripted roll below takes over. |
| flipSecondsPer90 | The scripted roll (last resort): how long per 90 degrees, 0.75 s off its side, 1.5 s off its roof. |
| clearanceM | Gap kept under the edge the scripted roll pivots on (0 at the start and the landing), so it lifts over the edge rather than scraping through. It pivots on its real outline (each part's corners, not a box round the car) and lands at its rest height with its tyres where they sit on loaded springs: off its side in 0.67 s with 0.26 m of lift, landing within 1 cm of its rest height; off its roof in 1.44 s with 0.69 m. |
| cooldownSeconds | After a scripted roll, how long before it can roll itself again (a car that lands on a slope and tips once more). |
| clearShiftsM | Where the scripted roll would stand it must be clear of walls, pillars and other cars, and so must the way there (checked every half metre, so it never rolls through a wall to a clear spot beyond). These sideways shifts are tried in turn; if none is clear it stays down and R resets it. Measured: against a wall at its roof it stood up 1.25 m clear of it; boxed in by walls 0.95 m each side it stayed down. |

## effects
Visual only; the physics never reads any of these. Client-side: skid marks and the screech for the car you are driving (DriftEffects); tyre smoke and dust on every car (TireSmoke, heat, load and dust model in shared TireHeat).

| Field | What it does |
|---|---|
| enabled | Master switch for smoke, marks and wheel spin-up. |
| smokeMinSpeedMps | Below this speed there are no skid marks and no screech. Smoke has its own rules (a burnout smokes standing still). |
| tireHeat.gripSlipDeg / gripSlipRatio | What a gripping tyre takes up without its tread sliding: 8 degrees of slip angle, 12% of spin or lock, both scaled with rolling speed. Only motion beyond it heats the tread. Without it plain cornering at 40 km/h (fronts at 7 degrees, measured) slid 1.35 m/s and fast grippy corners would smoke. Lower = smoke on harder cornering. |
| tireHeat.frontSideShare | Share of a front tyre's sideways slide that heats it (1). Owner, 2026-10-04: first "tone it down a bit" (0.4: then the fronts smoked only when the car was truly sideways), then "the front wheels have no tire smoke, make it more like it was before", with the front on the camera's side smoking. In a drift the chase camera looks at the outside of the turn, and the outside front carries the weight, so it smokes most (in a flick drift 1.0 against 0.3-0.5 for the far front, which the body hides). Lower to tone the fronts down again; 0 for no front drift smoke. Sideways only: a front lock-up under braking smokes in full whatever this is. |
| tireHeat.frontLoadSwap | The two fronts take each other's load share (true), so their smoke is the other way round: the loaded outside front of a drift, which would smoke hardest, smokes least and the light inside one most (flick drift: inside front 1.0, outside 0.2-0.5; without it, outside 1.0 and inside 0.3-0.5). Owner, 2026-10-04: "the way the front 2 tires smoke works, reverse it". false puts it back. The rears are untouched. |
| tireHeat.slideStartMps / slideFullMps | Contact-patch slide speed (beyond grip) where the tread starts heating, and where it heats flat out: 1.5 / 8 m/s. A committed drift at 60 km/h slides the rears 7-9 m/s. |
| tireHeat.heatPerSec / coolPerSec | How fast a sliding tread heats and how fast it cools (2.2 / 1.3). A full slide starts smoking after about 0.15 s and is at full smoke after about 0.7 s; once it grips the wisps die over about 1 s. Faster heating = smoke snaps on; slower cooling = longer tails. |
| tireHeat.smokeHeat / wisp | Heat where smoke starts (0.3), and the share of smoke a hot tyre keeps giving off the moment it grips (0.18), fading as it cools. |
| (heat and load) | Each wheel's heat input is scaled by its share of the car's weight from the sim's per-wheel loads (shared `TireHeat.loadShares`; 1 = an even quarter), and so is how hard it tears rubber off once hot: friction follows load, so the loaded outside rear of a drift smokes hardest and the light inside one less (a 0.5 share in a full drift still smokes at about 0.6). Not a field: it follows the sim. |
| smokeTexture / smokeTextureFallback | Roblox's own realistic smoke texture (rbxassetid://16830673704, from their volcano VFX tutorial): wispy, turbulent, near white, nearly opaque at its core. The first pass drew the built-in `smoke_main.dds`, a 128 px grey blob never more than a third opaque, which read as a soft grey ball however it was tinted. If the texture fails to load every emitter falls back to the built-in one. |
| smokeColor / smokeColorEnd | White at the tyre, a touch of blue-grey (232, 234, 238) as it thins. |
| smokeLightInfluence / smokeLightEmission / smokeBrightness | How much the scene's light tints it (0.25), how much it glows by itself (0.12), and a brightness lift (1.5). The texture's brightest is a light warm grey, and backlit at sunset the cloud read grey at 1; 1.5 reads white at sunset and light grey at night under the street lamps (checked), not glowing. Dust keeps brightness 1, so it stays its ground's colour. |
| smokeLayers.trail / wisp / billow / haze | Road smoke, four layers per tyre, born at the live contact patch (where the wheel's weld puts it, so it follows the springs) and laid by distance with `Emit` (shared `TireHeat.puffRate`: one puff every 1 / `perMetre` metres the patch travels, never fewer than `perSecond`, for a burnout). **trail**: the fresh smoke lying along the tyre's track, 3 a metre (14 a second standing) times the level, 0.8-1.3 s, 0.35 to 1.7 m, 0.45 to 0.72 see-through. **wisp**: its light twin (0.6-1 s, 0.25 to 1.1 m, 0.75 to 0.88) at the same 3 a metre times (1 - level), so every third of a metre gets a puff, full or light, and a fading slide thins to wisps instead of breaking into dots (shared `TireHeat.streamShares`; below `smokeWispTaper` 0.15 the wisps thin too, so the stream ends gently). **billow**: the softer cloud, 1 a metre (5 a second) times level squared, 2-3 s, 0.6 to 3.2 m, 0.6 to 0.82, fading in over its first 18% so it is only seen once grown into the trail, never as separate small balls. **haze**: a faint bank, 0.08 a metre (0.5 a second) times level squared, 4-6 s, 2 to 4.5 m, 0.88 to 0.93, fading in over 20%. `fadeIn` per layer is that share of life. All barely thrown (0.12 of the tread's slide at most for the trail, up to 1.5 m/s) and none carried along with the car. Owner, 2026-10-04: on the road the second pass was "patchy", it "bursts clouds and doesn't follow the wheels", and "a bit too much ... smoke and opacity": it was thrown up to 6 m/s, let out at a fixed rate a second that swelled and dipped by 0.6 (so at 70 km/h puffs landed 1-2 m apart, in bunches), born at the wheel's rest height, and twice as opaque. Other fields per layer: `power` (level exponent), `lifetime`, `sizeM` (birth, quarter, end), `transparency` (birth, half; clear at the end), `throw` and `maxSpeedMps`, `spreadDeg`, `drag` (Roblox's: halvings of speed a second), `riseMps` (climb it settles into), `inherit` (share of the car's velocity), `rotSpeedDeg`, `squash` (birth, a third, end; below 0 is wider than tall). Cost: four tyres at full round a parked car, median frame 16.6 ms against 16.7 with no smoke (95th percentile 30.7 against 25.3) on the Mac. The second pass's first sizes (up to 5 and 8.5 m) had taken that to 38.4: the cost is the screen area the puffs cover. More `perMetre` = a denser trail; lower `transparency` = whiter. |
| smokeTravelCapMps | Travel counted for laying smoke stops at 30 m/s, so a very fast slide doesn't pour out puffs without end. |
| smokePitchDeg | Fresh smoke rolls up off the road at 10 degrees above the tread's slide, not skimming it. |
| smokeAttackSeconds / smokeReleaseSeconds | The level the puffs are laid at eases toward the heat model's (0.1 s up, 0.3 s down), so a tyre whose load or slip flickers over a bump doesn't stutter out bursts. |
| squash (per layer) | Trail -0.2, billow -0.4 at a third of its life easing to -0.25, haze -0.2 to -0.5, dust -0.3. A puff is a flat card facing the camera, and a round one low over the road cuts into it in a hard line; flattened, the cloud spreads along the road like settling smoke and the line all but goes (Studio, 2026-10-04). |
| smokeWindMps | The breeze the smoke drifts on, m/s along world X and Z ({0.4, 1.0}): Riyadh's shamal from the north-north-west (north is -Z), gently south-south-east. Applied as each emitter's Acceleration (drag times ln 2 times the wind, which settles a puff at the wind's speed under Roblox's drag), so the world's GlobalWind and the sky's clouds are untouched. 0 for still air. Road smoke only; dust has its own copy. |
| smokeZOffsetM | Each road puff is drawn this far toward the camera (0.15 m). It was 0.84 m, to keep big low puffs from cutting into the road in a hard line, but that drew any smoke up to 0.84 m behind the car's body in front of it: a far front wheel's smoke showed over the bonnet and wing while turning (owner, 2026-10-04: smoke "should only come from the wheels that are visable to me", the far one's "should not be visable through the car"; reproduced with the camera at the rear quarter). At 0.15 the body hides the smoke behind it, which shows only once it rises above or trails out behind the car, and the flattened, slowly rising puffs no longer cut the road (four tyres at full, chase view). Don't raise it past about 0.2. Dust keeps its own 0.84. |
| dust | Off the road: a tyre on any of `materials` (sand, ground, grass, mud, snow, salt) doesn't smoke (it never grips hard enough to cook its tread; its heat cools), it throws the ground up as dust at once, coloured from what the ray under it hit (a part's Color, or Terrain's material colour) and `lighten` 0.3 of the way to white. `amount` (shared `TireHeat.dust`): sliding from 1 m/s, full at 6; a fast rolling tyre lifts a thin trail too (up to 0.3 at 30 m/s, from 8). Eases in over 0.08 s and settles over 0.4 s. `layer`: 28 a second, 1-2 s, 0.4 to 3.2 m, thrown at 0.55 of the tread's slide, barely climbing. One ray a wheel every fourth step finds the ground. Other players' cars get the same relayed level; each client's own ray decides smoke or dust. Dust keeps its own copy of everything it once shared with the smoke (`texture`, `lightInfluence` 0.25, `lightEmission` 0.12, `brightness` 1, `zOffsetM` 0.84, `windMps`, `pitchDeg` 15, and its rate puffing by `pulse` 0.6 about `pulseHz` 1.8 times a second), its own attachment at the wheel's rest contact patch and its running rate, so road smoke tuning never moves it. Owner, 2026-10-04: on sand "it is perfect so preserve the way it works on sand exactly as is". |
| smokeRelayHz | The driver's client sends its four smoke levels at most this often (10), only when they change; the server checks the driver and stamps them on the car as the `TireSmoke` attribute. Other players see the driver's curve about 0.2-0.3 s late, eased. |
| remoteSmokeMaxM | Other cars smoke within this distance of the camera (150 m). |
| lowQualityLevel / lowQualitySmokeScale | Below this graphics quality (1-10; Automatic counts as full) smoke and dust rates are scaled by 0.5. |
| skidSlipDeg | Lay rubber above this slip angle, or whenever a wheel is saturated (spinning or locked). |
| skidLifetime | Seconds a mark stays on the road. |
| skidTransparency | How dark the marks are. |
| wheelSpinUpRate | How fast a driven wheel that has broken loose visually winds up to engine speed, and how fast a locked wheel stops. |
| screechSoundId / screechMaxVolume | Looped tire screech, volume and pitch follow rear slip. Empty id = silent. 0.2 since the owner asked for it much mellower (was 0.6); 0 silences it. |
| screechSlipStartDeg / screechSlipFullDeg | Rear slip where the screech starts and where it is full. 18 / 45 so ordinary cornering is quiet (it used to share smoke's 10 / 35). |
| screechSpinLevel | Level wheelspin alone holds the screech at (was 0.7). |
| screechMinPitch / screechMaxPitch / screechEq | Pitch from a light slide to a full one, and EQ in dB (low, mid, high). Lower pitch and a deeper high cut are mellower. |
| engineAudio.masterVolume | Engine loudness at full load. 0.5 matches the old single loop. |
| engineAudio.pitchExponent | Each layer plays at (rpm / refRpm) ^ this. 1 is pitch exactly proportional to rpm, right for real loops recorded at refRpm. 1 with the SR20 set; the old single placeholder loop used 0.55 because one loop stretched over 900 to 6800 rpm at 1 sounds sped up. |
| engineAudio.idleFadeRpm | Idle has faded out this far above idleRpm. Larger = the idle tone lingers into the first pull. |
| engineAudio.loadBlendStartRpm / loadBlendEndRpm | Low load hands to high load across this range. Lower = the engine sounds strained earlier. |
| engineAudio.gainSmoothSeconds | Smoothing on layer volumes, only to stop clicks. Longer makes throttle stabs sound late. |
| engineAudio.loadAttackSeconds / loadReleaseSeconds | How fast the layers follow the throttle: pressing blends to on-load over the attack, lifting tapers to overrun over the release. Measured on a lift at 110 km/h: volume 0.50 to 0.26 over about 0.8 s (was inside 50 ms). Longer release = a lazier taper. |
| engineAudio.layers.{idle, lowLoad, highLoad, overrun} | Per layer: `soundId`, `refRpm` (the rpm it was recorded at), `volume` (relative) and `eq` (dB low/mid/high). Layers sharing an id share one Sound and blend its EQ. Now the SR20 set: idle 1000 on, low load 2000 on, high load 5000 on, overrun 4000 off, EQ flat. Overrun is what lifting off sounds like; in reverse the brake is the load. |
| engineAudio.shiftDipGain / shiftDipSeconds | Upshift: the engine drops to this fraction of its volume for this long (the torque cut). Measured: 0.50 to 0.26 at each of the 1-2, 2-3 and 3-4 shifts. Lower or longer = a heavier shift. |
| engineAudio.shiftSoundId / shiftSoundVolume | Optional mechanical thunk played on each upshift. Empty for now. |
| engineAudio.blipPitch / blipRiseSeconds / blipFallSeconds | Off-throttle downshift: pitch rises by this fraction, then falls back, about 30% louder while it lasts. Braking from 200 km/h blips at 4-3, 3-2 and 2-1 (pitch peaks 1.58 to 1.72, volume 0.25 to 0.32). |
| engineAudio.crackleMinRpm / crackleMinKmh / crackleLiftFrom | Lifting from above crackleLiftFrom throttle while over both crackleMinKmh and crackleMinRpm starts an exhaust burst in the car's style (`ExhaustStyles`, below the flames table). Throttle back on cuts the rest. Raise the speed or rpm for rarer bursts. The pop sound, its loudness and the 1-3 pops in 0.5 s moved to the Classic style (2026-10-04). |
| engineAudio.driftFlutterFromDeg / driftFlutterMinKmh | A lift with the car at least this far sideways (12°) and this fast (40 km/h) fires the exhaust style's drift flutter instead of its burst, at any revs: feathering mid-drift flutters the flames while the drift carries on (`drift.featherSeconds`). Measured on the Kamri: three 0.2 s feathers in a held slide, 5 pops each, one flutter and one cut on the server per feather. Lower the angle for flutters on smaller slides. |
| engineAudio.crackleRevFloor | A lift from crackleMinRpm gets this share of the style's pops, rising to all of them at the redline (`ExhaustStyles.revFactor`; Classic's count ignores it). 0.6: a lift at 5,650 rpm measured scale 0.84 on the factory exhaust. Up for more pops from low revs. |
| engineAudio.crackleShiftRpm / crackleShiftChance / crackleLimiterPerSecond | Single pops, each with its flame: an upshift from above crackleShiftRpm (6000; the box shifts at 6400) pops with crackleShiftChance, and on the limiter about crackleLimiterPerSecond a second, both times the exhaust's crackleChance. **Both 0 (off) by default**: the owner's 2026-09-22 ruling is pops only when going fast and letting off; turning them on is the owner's call. Tried in Play at 0.35 / 1.2 (twin tips: two upshift pops in 9 s of full throttle; each sound and flame on the same frame). |
| engineAudio.punchRpm / punchDecaySeconds / punchFullKmh / punchFadeKmh / punchMinFactor | Sound only: pressing the throttle kicks the note up by punchRpm times the pedal travel, settling over punchDecaySeconds. Full kick up to punchFullKmh, tapering to punchMinFactor of it by punchFadeKmh. |
| engineAudio.limiterBandRpm / limiterHz / limiterDipGain / limiterPitchDip | On throttle within the band of redline, the engine eases down to limiterDipGain and back this many times a second, the pitch sagging by limiterPitchDip at the bottom of each cut. 11 Hz to 0.6 with 4%; it was 16 Hz hard cuts to 0.35, a harsh buzz. Lower Hz or a higher dip gain is gentler. |
| engineAudio.chimeSoundId / chimeVolume / chimeSeconds | Getting in plays this chime for chimeSeconds (the file is a 5.5 s sequence; the first chime is enough). From the store Camry's scripts. Empty id = none. |
| engineAudio.startSoundId / startVolume / startDelaySeconds / crankSeconds / fadeSeconds | The starter plays startDelaySeconds after getting in; once crankSeconds have passed the engine layers fade in over fadeSeconds, so the car is heard starting. Longer crank = a lazier start. |
| engineAudio.offSoundId / offVolume | Played on the car when you get out. Empty id = none. |
| horn.soundId / volume / rollOffMaxDistance | The horn: H held (L3 on a pad), looped on the server so every player hears it. A car sets its own id in its tuning (the Kruzer 80 and Batrol use the Kruzer's store horn). |
| lamps.headlightsOnAtStart | Headlights on when you get in (the world is at sunset). G toggles them (D-pad up on a pad). |
| lamps.headColor / tailColor / brakeColor / reverseColor | Lamp colours. The car's own lamp pieces (HeadLamps, TailLamps, ReverseLamps) turn Neon in these; a textured lens drops its texture while lit. Tail lamps sit at tailColor with the headlights on and brighten to brakeColor braking. An opaque lens reads brighter than a glass one, so such a car sets a darker tailColor in its tuning (the Kruzer 80: 105, 5, 7). Nothing lights the ground. |

## scoring
A slide opens when the drift angle passes minAngleDeg while above minSpeedKmh, and accrues
`pointsPerSecond x (angle / referenceAngleDeg) x (speed / referenceSpeedKmh) x multiplier`
every second. Going straight for graceSeconds banks it. A completed 360 inside the slide adds
spinBonusPoints times the multiplier on top, measured on the drift angle unwrapped: one full
turn of the car relative to where it is going, whatever the path did.

| Field | What it does |
|---|---|
| minAngleDeg | Drift angle a slide needs to stay open. Lower = gentle cornering scores, higher = only real slides count. |
| minSpeedKmh | And the speed it needs. |
| graceSeconds | How long the car may be straight before the slide banks. This is what makes a left-right transition one long slide instead of two short ones, so raising it makes chaining easier and lowers the skill floor. |
| spinOutSpeedKmh | Falling under this mid-slide drops the run immediately. |
| impactDecelKmhPerSec | A sustained deceleration this hard counts as a crash and drops the run. Hard braking reads about 40, a wall reads several hundred. Lower it and firm braking will start killing runs. |
| impactSmoothSeconds | The window that deceleration is measured over. Must stay comfortably above 1 / scoring.sampleHz or the server will read replication jitter as a crash. |
| pointsPerSecond | Master payout knob. Points per second at the reference angle and speed at x1. |
| referenceAngleDeg / referenceSpeedKmh | What "one unit" of angle and speed means. Lower either one to make every slide pay more. Since speed-feel (2026-10-05) slides happen faster (150 instead of 100 is ordinary), so they pay about half again per second at the same angle; raise referenceSpeedKmh to about 140 to keep earnings where they were. Left at 100: the owner's call. |
| maxAngleFactor | Ceiling on the angle term, so a 179° slide is not worth four times a 45° one. |
| chainStep | How much each direction change adds to the multiplier. |
| chainMax | Ceiling on the multiplier. |
| minBankPoints | Slides worth less than this bank silently, so a twitch does not flash the HUD. |
| natlMinRollDeg / natlPointsPerSecond | Two wheels. Past the roll the run pays this many points per second at referenceSpeedKmh, scaled by speed, on top of any drift points, and the same grace window closes it. The server reads the roll off the replicated pose. 80 makes a natl at 90 km/h worth about what a 30-degree slide is; measured, a six-second ride banks about 430. |
| spinBonusPoints | Paid, times the multiplier, each time the drift angle travels a full 360 inside one slide; a 720 pays twice. 500 is about what two seconds fully sideways at 100 km/h earns, so a Ta'geed is worth roughly double the same time in a plain slide. The HUD flashes "360!" beside the live counter. The sign flip a spin makes at 180 is not a chain transition; only a crossing through straight is. |
| cashPerPoint | Points to cash. 0.01 = 1000 points is 10 cash. |

Validation. These are not feel knobs; they decide what the server will pay out. The server
scores every driven car from its own samples and never banks more than it saw.

| Field | What it does |
|---|---|
| maxPlausibleSpeedKmh | A sample faster than this throws the slide away. Set it above anything the car can actually reach: 390 with the top speed at 330 (speed-feel, 2026-10-05). |
| teleportToleranceM / teleportToleranceSeconds | Movement beyond speed x (the sample's time + teleportToleranceSeconds) + teleportToleranceM is a teleport and throws the slide away. The time term (0.25 s) is from the speed-feel review: a fixed 8 m was 0.19 s of travel at 150 km/h and 0.1 s at 300, so a replication stall gave honest slides away. |
| teleportToleranceM | Movement beyond `speed x dt` plus this counts as a teleport and throws the slide away. Too low and normal replication jitter will eat honest runs. |
| serverTolerance | How far a client's claim may exceed the server's own total before it is capped. It exists because the two sample at different rates; 1.25 means a cheat can gain at most 25% over an honest run of the same slide. |
| claimWindowSeconds | How long a submitted claim stays usable. Past it the server banks its own figure. |
| sampleHz | Server sampling rate per driven car. Raising it tightens validation and costs server time. |
| autosaveSeconds | Cash autosave interval. |

## hud
| Field | What it does |
|---|---|
| enabled | Show the driver HUD (layout D, `src/client/HudLab`, in the finish the player picked: the tacho with gear and speed, cash and records, the live slide score while sliding). |

## debug
| Field | What it does |
|---|---|
| enabled | Master switch for the tuning panel. |
| showOnTouch | Show it on phones too. |
| updateHz | Panel refresh rate. |
| spinSlipDeg / spinResetSeconds | The SPINS counter measures the drift angle unwrapped, from the moment the car is sideways past spinSlipDeg (seeded with the angle already built, so a full turn back to straight reads exactly 360), and keeps counting through the brief straight moment at the end of a rotation so a 720 reads as two. Straight for spinResetSeconds clears it. Display only; the scored version lives in `scoring`. |

---

# World (`src/server/World/WorldConfig.luau`)

Separate file from CarConfig and not live-reloadable: the world is built once
at server start, so a change here means restarting the server. `WORLD.md`
explains the architecture and the performance reasoning; this is the field
list. Scale comes from `CarConfig.units.metersPerStud`, so the world and the
car stay the same size.

## preset / presets
| Field | What it does |
|---|---|
| preset | Which layout to build. `testRoad` is the Phase 0 physics road (2 km straight, 400 m pad at 900 m, 400 m radius 30° curve) and keeping it is how tuning keeps its reference surface. `ringRoad` is a longer loop for driving. |
| presets.\<name\>.segments | List of `{ kind = "straight" | "curve", ... }` expanded into waypoints. A straight takes `lengthM`; a curve takes `radiusM`, `sweepDeg` and `direction` (-1 turns left). |
| presets.\<name\>.waypoints | An explicit `{ xM, zM, widthM, bankingDeg }` list, used instead of segments when present. |
| presets.\<name\>.pad | The wider stretch for left-right swings: `startM`, `lengthM`, `widthM`. |

## road
| Field | What it does |
|---|---|
| curveSegmentM | Arc length a curve is chopped into. Shorter is smoother and costs parts. At 400 m radius and 18 m steps the road sits 10 cm inside the true arc. |
| straightThresholdDeg | Heading change under which two segments merge into one part. |
| maxMergedRunM | Longest single merged part. **Raising this breaks streaming**: a part belongs to the region containing its centre, so a very long slab is absent until you are on top of it. Lower = more parts, smoother streaming. |
| jointOverlapM | How far curve segments overlap to close the gap on the outside edge. Raise if you see slivers on tight curves; do not raise far, it is overlap on a visible surface. |
| markingEpsilonM / markingThicknessM | How far paint and wear sit above the asphalt, and how thick. Raise epsilon if markings z-fight, lower it if the car feels a step. |
| dashLengthM / dashGapM / dashWidthM | Lane divider dashes. |
| edgeLineWidthM | Solid line at each road edge. |
| laneCount | Lanes per carriageway (6 now, on request; 5.3 m each in a 72 m corridor). Lane width is not a field: it is (preset widthM - medianWidthM) / 2 / laneCount, so widen lanes with the preset's widthM and grow pad.widthM and CityConfig gateway.widthM by the same amount. Dividers are laneCount-1, and tyre tracks are two per lane, so this drives part count as well as looks. |
| shoulderWidthM / kerbWidthM / kerbHeightM | The strip outside the paint, and the lip beyond it. Along the transition pad they follow the wing's outer edge instead of cutting across it. |
| padTaperM | Length of the flat asphalt triangle that leads into each end of the pad's wings (60 m), so the widening is a diagonal and not a step. Longer is gentler; it also sets how far before the pad the ordinary shoulder stops. |
| baySlotLines | Painted lines across the parking bay, one each side of every CarSpawner slot (pitch from CarConfig.spawn). |
| asphaltColor / padColor / shoulderColor / kerbColor / paintColor / bayColor | Surface tones. asphaltColor and padColor **tint the asphalt texture** (they multiply its colour map), so they sit near white and the map sets the grey; lower them to darken the road. Shoulder, kerb and bay are Concrete, so theirs is the colour you see. |
| asphalt.colorMap / normalMap / studsPerTile | The road texture: ambientCG Asphalt031, a plain mid-grey asphalt. Must match the HajwalaAsphalt ids in default.project.json. |

### road.wear
Surface realism. None of it is geometry the car can feel.
| Field | What it does |
|---|---|
| slabTone | Per-slab colour jitter. 0 gives one flat colour over 2 km, which is the thing that reads as a prop. |
| tyreTracksEnabled / tyreTrackWidthM / tyreTrackGapM / tyreTrackDarken | Polished strips where wheels actually run, two per lane. Darken too far and they read as paint (0.07 now; 0.16 was fine on the old near-black road and striped the grey one). |
| seamsEnabled / seamWidthM / seamDarken | A darker line across the road at each slab joint. |
| patchesEnabled / patchSpacingM / patchChance / patchMinLengthM / patchMaxLengthM / patchTone | Repair patches in a different shade. |
| markingWear | How far each dash's colour is pulled toward the road. 0 is crisp white, which no real road has. |
| markingFadeMax | Most a worn dash fades into the road. Mixed into the dash's colour, not Transparency, so markings stay opaque parts. |
| renderedAsphaltColor | The grey a dash fades toward: what the asphalt tint renders as (88, 88, 92), not the near-white tint. Re-pick it if asphaltColor moves a lot. |

## ground
| Field | What it does |
|---|---|
| tileM / marginM | Sand tile size and how far the desert reaches past the road. **tileM must stay under 573 m**: a Part axis caps at 2,048 studs and a bigger tile silently shrinks and leaves holes. |
| dunes.* | Low wedge ridges beyond the shoulder band: spacing, edge distances, size range. Non-collidable. |
| thicknessM / dropM | Slab thickness and how far the sand sits below the road. |
| color | One tone for the whole plane, from the SAND palette at the top of the file. It multiplies the sand map, so keep it light. |
| sand.* | The sand MaterialVariant: colour, normal and roughness image ids and studsPerTile. roughnessMap 0 leaves it out (the set's map reads glossy). enabled false falls back to Roblox's sand. |

## the sand palette
Three constants at the top of `WorldConfig.luau` feed every sand surface in
the world: the plane, the terrain, the berm, the far dune field, the drifts,
the median and the city kerb dust. Change one and everything moves together;
that is the whole point, because six separate sand colours are what made
nothing match.

| Constant | Where it lands |
|---|---|
| SAND | Ground plane, far dune ridges and crescents, terrain floor. |
| SAND_LIGHT | Shoulder drifts and wind-blown crest sand. |
| SAND_DARK | Terrain tint, dune mounds, median, roadside ridges. Terrain renders ~1.15x brighter for the same tint, which is why it takes the dark one. |

## duneField
The border on the sunset side. Every distance is metres from the road
centreline or along the road; the build prints the tallest crest angle next
to the sun's elevation, so check that line after changing heights.

| Field | What it does |
|---|---|
| side | `sun` reads Lighting at build time and puts the field on the sunset side; `left` / `right` pin it. |
| innerM / outerM | Nearest and farthest crest from the road centreline. Closer is more imposing and starts eating the sun. |
| startM / endM | Extent along the road; negative starts behind the start line. |
| edgeHeightM / fullHeightM / fullDepthM | Crest height envelope: from the inner edge up to full height by fullDepthM into the field. Height over distance is the silhouette angle. |
| gapNoiseScaleM / gapThreshold | Patchiness. Raise the threshold for more bays and gaps, lower it toward -1 for a wall. |
| sheets.* | Broad flat ellipsoids laid first so the floor rolls. |
| ridges.* | Round-crested ridges parallel to the road. Tilt is the roll toward the road: bigger is a steeper slip face. spacingFrac keeps ridges off each other. |
| seifs.* | Sharp-crested prisms. slipFaceDeg / windwardDeg are real slope angles; sink buries the prism's foot. |
| barchans.* | Crescents: body across the wind, two horns swept toward the road. |
| mounds.* | Low mounds, biased to the inner edge by innerBias. |
| outcrops.* | Sandstone meshes from AssetRegistry.outcrops, scaled 2 to 4 times. |
| color / moundColor / colorVariation | Red Sands palette with per-form variation. |
| clearSkylineBehind / skylineMarginM | Drops skyline ring sites that would stand behind the field. |

## road (dual carriageway)
| Field | What it does |
|---|---|
| medianWidthM | Width of the central reservation, taken out of the preset's total. 8 m now: a lamp post down the middle and a palm either side of it. Wider = more room for palms and a bigger gap to cross when you run wide on the inside. |
| medianColor / medianMaterial / medianDropM | The strip between carriageways. It is ground, so it collides. |
| kerbWidthM / kerbHeightM | A visual lip only; collision is off. |

There are no barriers anywhere: the berm and the dune field are built but
switched off (`relief.enabled`, `duneField.enabled`), so the desert is a flat
plane and running wide costs speed and dignity, not the run.

## relief
The border dunes, as terrain either side of the road. Everything in metres from the road centreline.

| Field | What it does |
|---|---|
| innerGapM / featherM | Where terrain may start past the asphalt, and a feather to nothing toward the pad and station (a safety; the mounds fade out well before either). |
| sinkM / shellM | How far the dune terrain sits under the plane, so a mound breaks the sand where its slope has begun; and how thick the solid sand shell is. |
| hummocks.* | Small mounds per km per side between the road and the dunes (0: that sand is flat), with the chance of a scrub tuft on top. |
| sandColor / gravelColor | Terrain tints; the sand is the plane's own tint, since terrain wears the plane's MaterialVariant. |
| chunkStuds | Voxel write chunk. 128 is 32 columns; bigger chunks mean fewer, larger writes. |

### relief.berm
The dune field: random soft mounds over the sand between a flat strip beside the road and the fence.

| Field | What it does |
|---|---|
| nearM / capNearM | Nothing of a dune shows nearer the centreline (or the start line, behind it) than this. **Move both to change the road-to-dune gap.** |
| cityMarginM | Flat sand kept round the city's grid, inside the fence circle. |
| field.perKm2 | Mounds per square km of usable sand. More is a busier field; about 100 covers 40 to 50%. |
| field.patchWavelengthM / field.minDensity | The slow noise that makes thick and thin stretches, and how empty the thinnest ones get. |
| field.maxOverlapM | No new mound where the others already stand this high, so overlaps are broad hills and not lumps. |
| field.pastFenceM | How far past the fence a mound may run: the fence goes over the dunes. |
| waves.baseM / waves.amplitudeM | The light waves under the mounds: their lowest height above the sunk base (keep it over sinkM or flat patches show) and the crest height over that. |
| waves.spacingM / waves.crestLengthM / waves.angleDeg / waves.detail | Crest to crest, length along a crest, turn off the road, and a finer octave as a fraction. Slope is roughly amplitude x 2 / spacing. |
| waves.startWanderM / waves.startWanderWavelengthM / waves.rampM | How far the wave start line wanders past nearM and how fast, and how far they take to rise from flush. |
| waves.pastFenceM / waves.fadeM | How far past the fence the waves carry on, and how much of that they spend easing out. |
| lengthM / nearSpreadM / farSpreadM / heightM | Ranges each mound is drawn from (low ones come out smaller all round). **Steepest slope is about 1.7 x height / spread**, so raise a spread or lower the height for calmer dunes. |
| yawDeg | Mounds turn off the road by up to this. |
| overlapM | Overlapping heights add, eased from the first value toward the second, so two tall mounds make a broad hill rather than a peak. |
| clearanceGapM | No mound within this of the petrol station's site. |
| endM / endTaperM | Where the dunes sink away before the city. |
| wallHeightM / wallPieceM | The invisible stop where the fence would be, only built when the fence is off. |

## fence
The chain-link border (`Fence.luau`).

| Field | What it does |
|---|---|
| fromRoadEdgeM / behindStartM | How far out the side fences stand (from the road edge) and how far behind the start line the cross fence is. The dune field fills out to them. |
| endM | Where the side fences stop when there is no city circle. |
| city.enabled / city.radiusM / city.clearM | The circle round the city: at least radiusM, at least clearM past the grid's corners, and always wide enough to meet the side fences, which run on until they do. |
| heightM / postSpacingM / postWidthM / railWidthM / postColor | The frame. |
| meshTextureId / meshTileM / meshTransparency | The chain-link mesh texture. |
| barbedWire / barbedHeightsM / barbedColor | Strands above the rail. |
| clearanceGapM / clearanceBlendM | How far the fence swings out round the station, and over what distance. |
| wallHeightM | The invisible stop in the fence. |

## duneLife
Sparse palms and scenes out in the dune field (`DuneLife.luau`). Counts are for the whole field, both sides.

| Field | What it does |
|---|---|
| oases / camps / majlis / wrecks / tyreStacks / waterTanks / camelGroups | How many of each scene to try to place. A scene that finds no flattish spot clear of the others is skipped. |
| ruins / areesh / wells / outcrops / drums / skeletons / markers | The second group of scenes: mud-brick ruins, palm-frond shades, wells, sandstone outcrops, oil drums, camel bones, painted markers with signposts. |
| lonePalms / acacias | Single trees (a lone palm is one or two). |
| sceneSpacingM / loneSpacingM | Clear ground between scenes, and round a lone tree. Raise for sparser. |
| nearMarginM / fenceMarginM / endMarginM / stationGapM | Keep-outs: past the flat strip and the city margin, inside the fence, short of the dunes' end (only without a city circle), and from the station. |
| maxMoundM | Never where a mound stands higher than this (its face). |

## lamps
| Field | What it does |
|---|---|
| spacingM | Distance between lamps. Drives both the rhythm of light and the part count. |
| bothSides | False alternates the outer sides and halves that part count. |
| medianLamps / medianSpacingM | Double-arm posts down the reservation at their own spacing (45 m, the outer spacing), offset half a spacing so each median post stands midway between two shoulder lamps. |
| useMesh | The post is one store mesh (AssetRegistry.highwayLamp: BryanROBLOXgamer10's "Street Lamp Light", pedestal, tapering pole, cobra arm and head in a single textured piece). Off, or if the mesh fails to load, the box stand-in below is built. |
| meshScale | The mesh is 10.6 m tall with the head 4.5 m out at scale 1; 1.15 makes a 12.2 m highway post reaching 5.1 m. Raise for a taller road, and the head moves out with it. |
| pairGapM | A median post is two mesh posts back to back; the second stands this far along the road (12 cm) so the two poles read as one thick pole and never share a surface. |
| setbackM | From the kerb to the pole (0.4 m now: the arm is shorter than the old boom, so the pole stands at the kerb to put the head over the outer lane). Nothing here collides. |
| lensSizeM / lensLitColor / lensLitTransparency / lensOffColor / lensOffTransparency | The lit panel under the head: a thin slab, warm-white Neon at an hour whose lamps are lit, pale glass otherwise. The light manager hangs its SpotLight from it. |
| poleHeightM / poleWidthM / armLengthM / headSizeM / poleColor / bulbColor / headOffColor | The box stand-in only. |
| jitterSeed / yawJitterDeg / heightJitter | Per-lamp variation. Zero makes a row read as a copied object. |
| highwayDownlights | Whether highway lamps take a pooled SpotLight. Off: the owner asked for no pools of light on the highway, so the lenses glow and nothing lights the road. City street lamps and the station canopy keep their lights either way. |
| lightColor / lightAngleDeg | Colour and cone of the pooled SpotLights (120 degrees, shining straight down from the lens: a pool on the road rather than a glow in the air). Brightness and range come from the time of day. |
| maxLiveLights | **Hard cap on Light instances in the whole client.** The pool is this size, so the cap cannot be violated. Raising it past about 16 is where Roblox starts to hurt. |
| lightUpdateInterval | How often the client re-picks which lamps are lit. Lower = tighter following, more CPU. Never per frame. |

## cityscape.aura
Haze and glow round the backdrop skyline (`Cityscape.luau`). Every layer is a line of invisible panels facing the road with an unlit SurfaceGui gradient.

| Field | What it does |
|---|---|
| enabled | The whole aura. |
| panelM / pixelsPerStud | Panel length along the band, and the gradient's resolution (it is smooth at any value). |
| endFadeM | How far the layers fade out past each end of the band. |
| curtains[].lateralM / heightM / color | Where each haze curtain stands from the centreline, how tall, and its colour. |
| curtains[].fade / glow.fade | Transparency at four heights: top, 2/3 up, 1/3 up, foot. Lower numbers are denser. |
| glow.lateralM / heightM | The glow dome behind the band. 570 m is the tallest a layer can be (a part axis caps at 2,048 studs). |
| glow.groundColor / topColor | Its colour at the foot and at the top. |
| glow.brightness | Over 1 makes it bloom. |

## timeOfDay / timesOfDay
`timeOfDay` picks one of `dusk`, `goldenHour`, `blueHour`, `night`. Each preset:
| Field | What it does |
|---|---|
| clockTime | Sun height. At latitude 60: 17.4 = 7° up, 17.55 = 5°, 17.68 = 3.9° (golden hour now, and the Sunset option in SkyConfig), 17.75 = 3°, 17.88 = 1.5°. Lower = longer shadows and a darker sky. |
| geographicLatitude | **This is the sun azimuth control**, because Roblox has no other. 24.7 (real Riyadh) puts the evening sun 90° off the road, out of the driving view; 60 puts it 127°, ahead-left, in the windscreen with shadows diagonal across the asphalt. 80 is 147°, nearly dead ahead. |
| ambient / outdoorAmbient | Fill light. This is the readability knob: too low and the car disappears between lamps. |
| brightness | Sun strength. |
| exposureCompensation | Overall exposure. |
| colorShiftTop / colorShiftBottom | Tint on lit and unlit faces. What stops asphalt reading as grey plastic. |
| globalShadows | Master shadow switch for the hour. |
| atmosphere.density | Distance fade. The biggest "sells distance" knob, and the biggest risk: too high and the road edge vanishes, which is worse than the mood is good. Golden hour is 0.2: at 0.26 the backdrop skyline at 1.3 to 2.4 km was a grey ghost; below 0.18 the horizon goes hard. |
| atmosphere.offset | How far up the haze starts. |
| atmosphere.color | Horizon glow colour. |
| atmosphere.decay | Colour the sky falls to away from the sun. |
| atmosphere.glare | Brightness right around the sun. |
| atmosphere.haze | How far the atmosphere colour spreads up the dome. Above about 1 the warm tint reaches the zenith and mixes with blue into olive. |
| sunRays.enabled / intensity / spread | Light shafts. Keep intensity low; it is a full-screen post effect. |
| sky.useSkyObject | False draws Roblox's procedural dome, which tracks ClockTime but stays day-blue until the sun touches the horizon. True builds a Sky from `sky.skybox`. |
| sky.skybox | Six texture ids `{ bk, dn, ft, lf, rt, up }`. Golden hour ships a photographed sunset; swap the ids for a different sky. |
| sky.starCount / celestialBodiesShown / sunAngularSize | Only used when `useSkyObject` is true. |
| lamps.enabled / brightness / rangeM | Whether street lamps are lit at this hour, and how hard. |
| bloom.intensity / size / threshold | Glow round anything brighter than threshold: the skyline's Neon and aura glow, the lamp lenses, the sun. Lower threshold blooms more (and blows the sun out sooner). |
| grade.contrast / saturation / tint | A light colour grade over the whole frame. |

## SkyConfig (the player's time of day)
`src/shared/SkyConfig.luau`. The times of day a player can pick in the menu's Settings tab (Sunset, Night). Each client sets `ClockTime`, `Brightness` and `ExposureCompensation` over the world's preset, on that player's screen only; the choice is saved in the profile. Everything else (ambient, haze, the skybox) is the active `timesOfDay` preset. The client puts those three fields back whenever they change, which also undoes Properties-panel edits in Play. **To try values live in Studio:** in Play, switch the Explorer to the Client view, select Players > your name, and tick the `SkyFree` attribute. `ClockTime`, `Brightness` and `ExposureCompensation` on Lighting then keep whatever you type; untick it and the chosen option returns. It exists only in Studio. Put the numbers you like into SkyConfig.
| Field | What it does |
|---|---|
| default | What a new player sees (`sunset`). Keep `goldenHour`'s clockTime, brightness and exposure equal to it, or the world changes as a client starts. |
| options[].id | Saved in the profile. Never rename one that players may have saved; an unknown id falls back to the default. |
| options[].label | The button text. A new row adds a button. |
| options[].clockTime | The hour. Sunset 17.68 (sun about 3.5° up), Night 18.9 (just below the horizon). Lower = more daytime; 0.05 is a visible step. |
| options[].brightness | The sun's strength. Sunset 1.36, Night 0.5. |
| options[].exposureCompensation | Overall exposure for that hour. Sunset −0.3, Night 0.1 (raised so the road reads between lamps). ±0.1 is a small step. |

## shadows
Per-type switch. Shadow cost scales with the **number** of casters, not size.
| Field | What it does |
|---|---|
| lamps / signage / palms | On. Sparse, tall, and their long raking shadows across the road are most of the realism. |
| rocks / cityscape | Off. Too small and too far to pay for themselves. |
| fence | Off. The fence was 2,503 of 5,515 casters and stands 700 m from the road. `true` brings the post shadows back. |
| sceneryReachM | 150. Dune life further than this from the road edge casts no shadow. 0 = everything casts. Raise it if a camp near the road loses a shadow you miss. |

## signage
| Field | What it does |
|---|---|
| gantrySpacingM / gantryFirstM | How often an overhead gantry appears. |
| gantryHeightM / legColumnM / legSpreadM | Portal frame height (11 m, which leaves 6 m under the boards: they hang trussDepthM + panelHeightM + 0.3 m below it); each leg is two columns this thick, this far apart, with ties and diagonals between. |
| trussDepthM / chordM / bayM / braceM | The beam truss: depth, chord section, bay length (a vertical and a diagonal per bay), brace section. |
| panelWidthM / panelHeightM / panelColor / panelBlueColor / borderWidthM / borderColor / postColor / textColor | Boards: green direction, blue distance, the white border strip round each, galvanised steel, text. |
| gantryTexts / roadsideTexts | `{ arabic, english, shield }` rows. **Placeholders** — replace with real Riyadh route names. |
| roadsideEnabled / roadsideSpacingM / roadsideWidthM / roadsideHeightM / roadsidePostHeightM | Boards on twin posts between gantries, alternating sides and colours. |
| speedSigns.* | Red-ring speed signs on one post, both shoulders: spacing, first, the number, disc diameter, post height. |

## station
The petrol station (`Station.luau`). Metres in a local frame: u across the road (+ away from it), v along it (+ direction of travel), from the origin.
| Field | What it does |
|---|---|
| enabled / alongM / lateralM / yawDeg / scale | Where the site is: distance along the road and from the centreline (1100 m, 122 m, beside the bay), an extra turn and an overall scale. Aprons, keep-out and the pad edge-line openings all follow. |
| pumpCount | 4 to 6, split across the two islands. Six pumps are 216 triangles of pumps and hoses. |
| nameArabic / nameEnglish / shopArabic / shopEnglish / prices | Invented station branding and the totem's price rows. Every glyph is two triangles. |
| forecourt / forecourtPanels | The concrete lot's extent and how many bays it is split into (each bay its own tone). Keep u1 deep enough that the canopy's golden-hour shadow lands on concrete. |
| apronWidthM / apronFlareM / entryV / exitV | The drive-in and drive-out aprons from the pad edge: width, the flared mouth, and where along the lot each sits. |
| keepOutMarginM | How far the scatter stays off the whole site. |
| canopy.* | Centre, footprint, clearance (5.8 m soffit), fascia depth, column section and where the columns stand on the islands. |
| islands.* | The two islands' u positions, length, width and kerb height. |
| shop.* | Centre, depth, length, height and parapet of the shop. |
| pylon.* | The price totem: position, height, width and how far it turns toward oncoming traffic. |
| palms / parkedCars | Palm positions (from parts, 96 triangles each) and how many parked cars (100 each). |
| colors.* | Every station colour: concrete and apron tints, brand green and gold, sandstone, glass, the warm strip lenses. |

## garage
The garage workshop (`Garage.luau`, WORLD.md "The garage"). Metres in a local frame: u along the front (+ to your right as you face the doors), v into the building (the front wall is at -depthM/2), from the building's centre.
| Field | What it does |
|---|---|
| enabled / alongM / lateralM / yawDeg / seed | Where it stands: 1,530 m along, 60 m left (the middle of the pad's left wing, across from the bay), doors turned yawDeg right of the direction of travel (90 faces the road from the left). Seed for tints, tyre marks, stains, stock. |
| widthM / depthM / eavesM / wallM / plinthM | Footprint (26 x 16), wall height (6.5), wall thickness, the darker base band. |
| displayU / liftU | Centres of the two bays: the open door and turntable, the shut door and lift. |
| door.widthM / door.heightM | The roller-door openings (5 x 4). The DoorZone is the open one. |
| shutterBox / shutterSlatM | The rolled-shutter box over each opening, and the closed shutter's painted slat pitch. |
| fascia.* | The sign over the doors: height, depth, projection, and the English / Arabic text (UITheme display font). |
| roof.* | Roof slab thickness, overhang, the ribbed edge's depth and rib pitch (ribs are painted frames: a smaller pitch costs frames). |
| window.* | The high window strip in the lift bay's back wall and its mullion pitch. |
| columns.* / beams.* | The two steel columns on the line between the bays, and the roof beams' positions and section. |
| floor.* / doorApronM | The slab (2 cm proud of the pad), its saw-cut pitch, and the concrete strip outside the doors. |
| turntable.* | Where along v, diameter (5.4 m), ring width, and the plate / ring top heights. Its spin rate is `GarageConfig.spinDegPerSec`. |
| backdrop.coveM | The 45 degree cove where the backdrop meets the floor. |
| lift.* | The two-post lift: along v, how high the car is raised (1.8 m; LiftCarSpot), post spacing and height. |
| doorZoneDepthM / exitSpot.* | The threshold box's depth (4 m, centred on the door line: 2 m out, 2 m in; a box you are in, not a line you cross, since 2026-10-14; ExitSpot at 3 m and the parked car at 7 m stay outside it); where a leaving player stands (outM outside the door) and the root height of that spot. |
| bakedLight.* | LightInfluence of the painted-on lit tone over the floor, linings, backdrop, ceiling and turntable: 0 fully self-lit, 1 only real light. Lower is brighter inside. Needed because the pool's lamps are dark at golden hour. |
| strips.* | Warm strip fittings: row offset from each bay's centre, fittings per row, length, spacing, hanger drop. Each lens is a pooled lamp head. |
| apron.* | Painted apron: number of bays, where they start, bay width and depth, line width, the lettering and arrow positions, the hatch depth. |
| tyreMarks.* / oilStains.* | How many, their transparency range, width / size range. Painted frames, not parts. |
| props | The workshop dressing: `{ kind, u, v, yawDeg, y?, widthM?, heightM?, load?, count? }`. Kinds: workbench, toolBoard, rollCab, compressor, hoseReel, shelf (load "tyres" or "boxes"), tyreStack, drum, jack, extinguisher. (u, v) is the back edge's middle for wall things (lined faces at u = +-12.66, v = +-7.66), the centre otherwise; yawDeg 0 backs onto the back wall, 90 the right, -90 the left, 180 the front. |
| keepOutMarginM | How far scatter and dune life stay off the building and apron (8). |
| colors.* | Every colour: sandstone (the station's), lining and dado, floor #8C8A84, backdrop #6E6A64, turntable #4A4C50, ring #2A2A2C, the sign (UITheme asphalt900, paint, sodium), strip #FFECC8, the lift, roll cab, compressor, racks, stock. |

## GarageConfig (the customisation view, shared)
`src/shared/GarageConfig.luau`, read by the client. Light positions are metres from the turntable's top centre in the view frame: -Z into the garage (DoorZone's LookVector), +X right as you look in, +Y up.
| Field | What it does |
|---|---|
| fovDeg / eyeHeightM / yawDeg / framingMargin / screenOffset | The full framing (MY CARS and PAINT's colours; the close shots below take its bearing): 50 degree lens (the spec's 40 put the eye 10.3 m out, in the bay's front-left corner inside the tyre rack), eye 1.5 m, 30 degrees round from the nose toward the right (3/4 front right; 35 crowded the side wall), margin round the body's bounding sphere, and how far right of centre the car sits (0.18 of the width) so the panel does not cover it. The camera turns to put the car there; it does not slide. Distances by rig box: 7.0 m (hatch) to 8.4 m (cruiser), the eye at least 1.9 m off the side wall and 2 m inside the door. Lower fovDeg = longer lens, farther eye. |
| layoutOffset | Where the car sits for each garage layout (GaragePanel, 2026-10-12), in place of screenOffset: dock 0.2 and shade 0.22 (their panels are on the left; SHADE is parked out of the layout list), showcase, glass and frame -0.06 (the car in the middle, between the category words and the blocks on the right). Raise one to push the car right, out from under a left panel. |
| viewHides | The garage shell's parts hidden on this screen while the view is up: RoofBeam and Beam, the dark steel beams under the roof that crossed right behind the cash and read as its shadow (the owner's phone, 2026-10-12). Add a part's name to hide it from the view too; empty shows the whole shell. |
| thresholdRangeM / fadeSeconds / noticeSeconds / exitCamera | The doorway is watched within 12 m (on foot the character's root; seated, the car's chassis, see driveIn); the fade is 0.2 s each way; a short notice (the car could not be shown) stays 3 s; on leaving the camera starts 4 m behind and 1.6 m above the character at ExitSpot. |
| spinDegPerSec / dragDegPerPixel / inertiaSeconds / resumeAfterSeconds / maxFlickDegPerSec | Turntable: 8 degrees a second (measured 7.6 in Play), 0.35 degrees per pixel of drag (a 200 px drag turned it 76 degrees, auto-spin included), flick decay over 1 s capped at 360 degrees a second, and 3 s before auto-spin resumes. |
| driveIn.zoneMarginM / outM / clearM / leaveRangeM / blockedText / holdSeconds | Driving in (round 2 §3): driving your own car, the chassis's centre in DoorZone's box opens the view with that car at any speed (the 20 km/h limit, maxKmh and serverSlack, went on 2026-10-14: the car parks at once, so the walls never come into it). The server checks the chassis within zoneMarginM (6 m: about 3 m of travel over 100 ms of ping at 100 km/h, past the box's 2 m inside the door) of the zone's box, then parks the car outM (7 m) straight out from the zone's centre, facing out, anchored, prompt off; leaving seats the player back in it there. clearM (3 x 6 m) is the spot's footprint: any other car or player in it refuses the drive-in with blockedText. The parked ride height is the live chassis height over the floor, clamped between half the body's height and the bay's spawn height (half body + spawn.spawnHeightM). A drive-out is refused (walk-in exit instead) unless the character's root is within leaveRangeM (20 m) of DoorZone. On a drive-out the car stays anchored through the seating until the client's car controller runs and sends "go" (about 50 to 270 ms; VehicleController skips its sim step while the chassis is anchored, so no warnings); the server lets go after holdSeconds (2) if it never comes, or clears a hold whose player is no longer the driver. Un-anchored at the seat instead, the car fell for the 20 to 75 ms before the client's sim started and 2 in 5 drive-outs flipped (fix, 2026-09-28). Measured in Play 2026-09-28 (kamri07): drive-ins at 9.7 and ~15 km/h opened the view, parked at 7.00 m out, facing out (dot 1.00), 1.01 m chassis ride height kept; one at 74 km/h did nothing (then the limit). Final pass (same day, after the ride-height clamp): parked chassis 1.007 m over the pad against 1.003 m for the car settled after a normal spawn, tyres on the pad. outM down parks nearer the door (below ~5.7 a 5 m car's tail reaches ExitSpot). |
| shots | The close shots (garage-polish, 2026-10-05; the owner: "when selecting exhaust tips or flames, it should like zoom into that part and for the flames, shoudl do a quick play of it"). Each turns the turntable so the car shows the camera one side and holds it (no spin), and brings the camera in toward a point on the car: `faceDeg` (0 nose on, 90 the right side, 180 the rear), the aim (`hub` a wheel hub, `outlets` the exhaust outlets' middle, or `box`, a point in the body's box as fractions; a hub or outlets the car lacks falls back to `box`), `distanceM` (eye to aim, flat), `eyeHeightM`, optional `fovDeg`, `brake` (brake lights on). The camera keeps the full framing's bearing and only comes closer, so it never meets a wall. side (tint) 90°, 4.2 m, 1.35 m up; wheel (rims, tyres) the front-right hub, 75°, 3 m, 0.7 m (at 2.3 m the wheel filled the frame); head 35°, tail 150° with the brake lights; windscreen (sun strips) 10°, 3.6 m, 2.4 m up; plate 180°; exhaust (tips, flames) the outlets, 195° (REV's old angle: at 35 off square the right-hand flame ran off the screen), 3 m, 0.45 m (from 0.8 m the Krown Vik's factory pipe hid under its bumper). Closer: smaller distanceM. |
| focus.easeSeconds / arriveDeg | The turntable eases to a shot's angle with a 0.25 s time constant (1.1 s from 76 degrees away, measured for REV); a shot's follow-up (a flame's burst) runs once the camera move (`UITheme.motion.camera`, 0.8 s, Sine in-out) is done and the turntable is within arriveDeg (1.5). A drag goes back out to the full framing; tapping the sub-tab again goes back in. |
| views | The panel's sub-tabs per category, each with its label and shot (`"full"` is the whole car, turning). A category with one view shows no sub-tabs. PAINT has COLOUR, FINISH and TINT: FINISH became a sub-tab of its own in the garage-ui-overhaul (2026-10-06), where its pills took three rows above the colours. How the panel looks is in UI_SYSTEM.md (the shade, the rail, palettes and lists). |
| headFlash | A headlight colour tapped: the lamps blink `blinks` (2) times, off 0.09 s, on 0.14 s. |
| sounds | The panel's sounds for this player (`GarageSounds`): tab (Roblox_UI_Small_Click), tap (Roblox_UI_Bright_Click, an unbought preview), fit (Pro Sound Effects impact wrench, an owned item fitted), buy (Pro Sound Effects cash register), error (Roblox_UI_Delete); ids and volumes, picked unheard for the owner. A sound that fails to load stays silent; volume 0 mutes one. |
| feel | An item's press scale (0.96), the pop when an item is fitted or bought (1.06 and back), the cash count-down after a purchase (0.6 s). |
| previewLampsOn | The preview's headlights (and so its tails) are lit, so the Lights category shows. |
| aimHeightM | Spot lights aim at the turntable centre this high (the car's middle). |
| lights.key / fill / rim / under | The view's four lights: type, positionM, brightness, rangeM, angleDeg, color, sizeM (the fill's face), shadows (the key only; no effect under ShadowMap). The fill is a 3 m softbox 4.6 m over the car, brightness 1.5, angle 120, range 11 m (from a 1.2 m panel on the far side): the Glass finishes take their sheen from it. A white gloss car still does not bloom. Brightness: key 1, fill 1, rim 1.5, under 0.4 (from 3 / 1 / 2.5 / 0.8, because a white car passed the world bloom threshold and glowed). **The owner's feel knob is `lights.key.brightness`**: higher gives a hotter highlight and more bloom on white. Each light is scaled per sky option by 2^(default exposure - option exposure), so at night (+0.4 stops) they run at 0.76. Four lights with the pool suspended keeps the client under maxLiveLights (12). |
| bakedGlow / bakedGlowSkip | The interior's painted-on light per sky option: each panel's LightInfluence becomes 1 - (1 - built) * glow. Sunset 1 (as built), night 0.5. The sign (Fascia) is left alone. |

## PaintLooks (how car paint catches the light; side variants)
`src/shared/PaintLooks.luau`, read by `CarCosmetics` (the finishes) and `Sky` (the hour). The owner, 2026-11-08: the cars looked flat, "so the sun has an effect on it". **In Studio, B cycles the looks** (Main, Finishes only, Wet, As before), named on screen; the LocalPlayer attribute `PaintLook` holds the choice; players get Main. Once the owner picks, the rest go.

What was measured that day, in Play, with five red and five white Kamris parked in open sun on the road (z −6200):
| Change | What it did |
|---|---|
| Sunset sky at 17.68 (sun 3.5° up) | Roblox gives a sun that low almost no direct light: a red ball had no lit side, every car one flat colour. Brightness 3.5, OutdoorAmbient a third lower or Atmosphere density 0.05 changed nothing. |
| 17.6 (4.8°) | Shading begins, still mostly flat. |
| 17.5 (6.0°) | A lit side, a shaded side, warm reflections; the road lit; still a sunset sky. |
| Reflectance 0.1 / 0.2 / 0.3 / 0.45 on the paint | 0.2 shows the sky on the boot and the sides away from the sun and reads as paint; 0.45 washes red toward pink. On factory white the coat alone is subtle; on red it is plain. |
| A warm SpotLight from the sun's side on each car | Glowed and lit a patch of road: dropped. |
| Metal | No different from SmoothPlastic on these meshes (as the garage found in 2026-09). |

**The finishes, 2026-11-09.** The first cut laid that 0.2 coat under every finish as a floor. The owner: "the factory finish on the camry looks more like the glossy one ... make sure there is an actual difference between the finishes". Measured with five red (Beacon Red) Kamris on the sand at 17.5, from the sun's side and against it:
| Finish | Under the 0.2 floor | Now (Main) | How it reads now |
|---|---|---|---|
| Factory | SmoothPlastic 0.2 | SmoothPlastic 0.1 (the car's own, at least) | Solid red |
| Gloss | Glass 0.2 | Glass 0.3 | Red with bright sky over the panels |
| Matte | SmoothPlastic 0, 20% darker, 30% less saturated | SmoothPlastic 0, 40% darker, 35% less saturated | Dull brick red (20%/30% read close to factory outdoors) |
| Metallic | Glass 0.2, 25% darker | Glass 0.35, 40% darker | Deep wine with a warm sheen |
| Chrome | Glass 0.2 (its own 0.15 was under the floor) | Glass 0.7, 40% less saturated | Pale tinted silver |

Under the floor, factory looked like gloss and metallic like chrome; now all five read apart, so none was cut. SmoothPlastic's reflectance barely shows outdoors (0.04 and 0.25 looked alike); Glass is what reads as shine. **The garage turntable keeps the CosmeticsConfig ladder** (tuned under its lights in 2026-09): there, Glass 0.3 turned a red car pale pink, while gloss at Glass 0 still shows a sheen beside factory. So a finish looks a little different on the turntable and on the road; outdoors is where it is seen most.

| Field | What it does |
|---|---|
| looks[].finishes | How each finish is painted on the cars in `cars` out in the world, by CosmeticsConfig finish id (material, reflectance, darken, desaturate; a finish with no material keeps the piece's own and reflects at least its own). Main and Finishes only use the ladder above; Wet takes every shiny finish a step wetter (factory 0.2, gloss 0.4, metallic 0.45, chrome 0.8, matte as is), still five apart on red; As before has none (the CosmeticsConfig finish everywhere). More reflectance on Glass = more sky and a paler colour; past about 0.3 red goes pink. |
| looks[].sunClockTime | The hour a SkyConfig option is shown at instead of its own, by option id: Main and Wet show Sunset at 17.5. Night keeps 18.9. This moves the sky, the sun and the whole world, not only cars. If the owner keeps it, write 17.5 into SkyConfig's sunset and WorldConfig's goldenHour and drop the field (until then the server builds at 17.68 and each client moves to 17.5 as it starts). |
| cars | The cars the finish ladders are tried on: `kamri07` only, as the owner asked ("for testing and development purposes rn we will work on only the camry"). Add an id to try another; the hour reaches every car. |

## CosmeticsConfig.render (how a garage look is drawn, shared)
`src/shared/CosmeticsConfig.luau`, read by `CarCosmetics` (client) and `CarLamps`. Each car's strip and tip spots are in `src/shared/CarCosmeticMounts.luau` (car frame, metres before scale, like `CarPlateMounts`).
| Field | What it does |
|---|---|
| brakeBrighten | A chosen tail colour's brake lamp is that colour this much brighter in HSV value (0.4): Deep Red tails #8A0508 brake at #C1070B (measured in Play). Smoked brakes dim (#670E11); raise this if braking gets lost. |
| stripThicknessM / stripPixelsPerM / stripDrawStuds | The sun strip's slats (the `decal` category, shown as SUN STRIPS): 4 mm thick, canvas 400 px per metre, not drawn past 250 studs. |
| stripSlats / stripOverlapM / stripGlassGapM | Garage round 3 §3: the strip is 14 flat slats moulded to the windscreen (`CarStripShapes`, written by `tools/cosmetics/strip_shapes.py` from each car's glass mesh). More slats follow a tighter curve at one part and one SurfaceGui each. Joins overlap by at least 2 x 4 mm; the generator widens a join until even the slats' corners overlap that much where the strip bends in the glass's plane (8-10 mm on most cars, 9 mm at the hatch, 11 mm at the pickup's outer joins, recomputed from `CarStripShapes` after the fix-round smoothing; raise it if a seam shows). The strip's two outer ends are not widened. The slats stand 6 mm off the nearest point of the glass under them (outside on opaque glass, behind it on see-through glass). Rerun the script after changing any of the three. Cost: 14 parts and 14 SurfaceGuis per strip car (99 instances); 8 strip cars in view (112 SurfaceGuis) measured the same frame time as none in Studio (16.7 ms mean at the 60 fps cap, 2026-09-28). |
| tipStyles | Garage round 3 §1: each exhaust item's `tipStyle` names one. `mesh` is its generated piece (`tools/cosmetics/exhaust_tips.py`, in `src/shared/CosmeticMeshes/ExhaustTips`): one mesh per style, so one EditableMesh (fix round 1: at most 4 in all; a client holds 8). rolled (single, twin), quad (`QuadPair`: a whole pair on its Y inlet, `pair = true`, so a quad has two pipes; the pieces, their pipes and the cylinder fallback's pipes all follow `pair` through `CarCosmeticMounts.pieceFrames`, final review), slash (titanium, `baked`: the mesh carries its heat colours) and oval (`tileAspect` 1.56, the panel tile). `meshAssetId`: the same mesh uploaded from `tools/cosmetics/out`; set, the style costs no EditableMesh (upload steps in `tools/cosmetics/README.md`). All four are uploaded (2026-09-29), so tips no longer use EditableMeshes; the generated pieces stay as the fallback if an asset fails to load. `textureAssetId`: the slash's heat colours as an image on its uploaded mesh (the importer drops vertex colours). `uploadedTipTurnDeg` 180: the importer turns an OBJ half round about Y; uploaded tips are turned back. The shapes (lengths, radii, lip, bore depth, slash angle, heat colours) are constants at the top of the generator, each with its why. |
| bakedTipColor / tipBoreColor / tipMeshReserve | The part colour of a baked mesh (#EEEDEA, near white so the heat colours show at their own value). Each tip's bore is a flat dark disc Part 1.6 cm in (a sphere SpecialMesh 1 cm deep, so it goes oval in the oval) in tipBoreColor #060607 SmoothPlastic; #141416 read brown-grey under the sunset. tipMeshReserve: a style takes an EditableMesh only if enough stay free after it for the largest generated car body, so car bodies come first; otherwise cylinder tips. CarCosmetics derives that from the catalog (the most distinct generated mesh pieces any car has) and uses it or `tipMeshReserve` (4, now only a floor), whichever is more. Measured in Play 2026-09-29 on the working-copy catalog (final review M1): kamri 5, krownvik 4, lekzas, batrol, krownvikfleet 1 each, the other five cars (kamri07, the default, among them) none; so the reserve is 5: with no generated car in view 3 tip styles can be meshes, with a kamri none. A short probe is remembered until a tip template frees a slot, so a client at the cap probes (and logs the engine's "Failed to create empty EditableMesh") once, not per look change. A style's mesh is freed when no car on the client wears it (measured: 5 free with a tip on, 6 with stock, on a client holding two generated bodies). |
| tipRadiusM / quadPairGapM / boreColor | 0.09 m: the round tips' outer radius (the generator builds Rolled, QuadPair and Slash at it, CosmeticsConfig.spec); quad tips are two pairs 0.2 m apart centre to centre (QuadPair is built for it). boreColor is the factory pipe's flush bore, and the cylinder fallback's. Before the car's scale (1.2 on every car now). |
| pipeRunFromM | 0.16 m: every tip's pipe ends forward `tips.pipeLengthM` ahead of a point this far in from the mouth (round 2's tip length, which each car's pipeLengthM was measured from), so the pipes still end hidden where they did. They now start inside the tip's inlet collar (20.5 cm in on Rolled, 23.5 on Slash, 21.5 on Oval, 33 on QuadPair's Y inlet). |
| pipeRadiusM / pipeOverlapM / pipeColor | The pipe each tip (or quad pair) sits on (0.04 m radius, dark metal), from 3 cm inside the inlet collar (0.046 m radius, spec-checked) forward to the end above, into the body or the car's own muffler, so no tip floats. |
| factoryPipeRadiusM / factoryBoreRadiusM / factoryPipeColor | The plain pipe built where a body has no pipe of its own (kamri): 0.032 m radius, 0.022 m bore, running forward the stock outlet's own `pipeLengthM` (kamri 0.35; defaults to the tips' run). It goes when tips go on. |
| pipeBendRadiusM / pipeBendMaxDeg / pipeBendSegments / pipeEndBuryM | Garage round 3 §2: every pipe (tips' and factory) runs straight to where round 2 ended it, then bends up into the body (`CarCosmeticMounts.pipeRoute`). Plain Parts, not an EditableMesh (a client holds 8): a cylinder per chord of the bend, a ball the pipe's size at each joint. 0.1 m centreline radius (2.5 pipe radii); a small rise bends only as far as it needs (a 4 cm rise: 73°, 3 chords), a large one bends the full 90° and runs straight up (kruzer80: 22 cm); a riser shorter than about a chord (5 cm) is folded into a lengthened last chord instead (fix round 1: the batrol's 1 cm riser depended on float rounding). 3 segments per 90° (30° chords, round from rear 3/4 and the side); up for a smoother bend up close, at 2 parts per segment per pipe. The end's whole rim sits pipeEndBuryM (2 cm) above the car's `riseM`, inside the body. Spec: the end at least riseM up, rim buried, the pipe's true top (a joint ball's r, a slanted end's r·cos) below the boot line, clear of the rear tyre (behind it, or inboard of its inner face from the catalog's `wheelWidthM`), for the mesh tips and the cylinder fallback alike. Thin margins: the batrol's bend clears the tyre lengthwise by 2 mm, the kruzer80's pipe is 2 mm inboard of its tyre's inner face, so raising `pipeBendRadiusM` or those cars' spread fails the spec. |
| pipeAxisRunM | A turned tip's pipe (the krownvik and fleet quad pairs, 10°) leaves along the tip's own axis for 5 cm past the inlet, then turns straight forward at a ball joint. |
| hangerBackM / hangerWidthM / hangerThickM / hangerColor / hangerMaxM | One dark rubber strap per pipe (#161617, Rubber), 8 cm behind the bend, 3 cm wide and 1.4 cm thick, from the pipe's centre up to riseM + pipeEndBuryM (into the body; its height is the one measured at the run's end). None where it would be taller than hangerMaxM (0.12 m): the kruzer80's would be a 32 cm strap (fix round 1). A detail for low views; lower hangerWidthM to make it quieter. |
| CarCosmeticMounts windscreen | The strip generator's inputs: `piece` (the glass piece, or a shell car's shell), `side` (inside behind see-through SmoothPlastic glass; outside on opaque glass, and on Glass-material glass, the Batrol's and Krown Vik's, where a SurfaceGui behind it does not draw), `heightM` (0.12), `topGapM` (how far under the glass's top edge the strip starts, down the glass: kamri07 0.1 so it clears the dark band under its roof edge), `ends` (`mesh`: to the glass's outline at the pillars, less `endInsetM` (Krown Vik 1.5 cm, Batrol 5.5 cm: their glass runs under the pillar trim; the Batrol's uninset strip, 1.40 m, stopped about 1 cm short of the pillar head-on but poked about 2-3 cm over the far A-pillar from the garage's front 3/4, where its flat end slat stands off the wrapping glass: a 2 cm inset still touched the pillar there, 5.5 cm clears it, measured 2026-09-29); `spot`: a shell whose screen is painted into its texture, `posM` picks the screen and `widthM` sets the ends by eye: pickup 1.25, cruiser 1.26). Rerun `tools/cosmetics/strip_shapes.py` after any change. |
| CarCosmeticMounts exhaust | One shape on every car (garage round 2 §1): `stock` (the car's own pipe mouths: posM at the mouth's centre, optional `dir` the way the pipe points, `factory = true` where we build the pipe), `tips` (posM: between a twin pair at the tips' mouth; spreadM: twin tips at ±spreadM/2, a single on stock[1]'s side, quad as two pairs; pipeLengthM: the pipe run forward) and `bumperZ` (the body's rear face just above the tips), plus optional `quadOuterBumperZ` (that face over a quad's outer two tips where the bumper curves forward; krownvik and fleet: the quad pair turns about 10° about Y so its outer mouth moves with it, `quadPairFrames`, the outlets following the tips' axis) and optional `quadSpreadM` (quad pair centres at ±quadSpreadM/2, where a one-pipe car's own pipe would sit in a pair's gap; batrol, kruzer80). Every tip mouth sits 2-5 cm past the face above it (3 cm on every car but the lekzas, 4.5), and over the car's own pipes where it can (a quad on a one-pipe car: a tip, not a gap, spec-checked). `CarCosmeticMounts.spec` holds every car to it. Garage round 3 §2 adds `riseM` (how far above the tips' pipe centre the body sits where the run ends; the pipe bends up that far plus `pipeEndBuryM`) and a factory outlet's own `riseM`; where the run already ends inside the body it is a nominal 0.04 (spec: > 0 on every car and factory outlet). |
| ExhaustOutlet attachments | `CarCosmetics.outlets(model)`: one Attachment per mouth of the exhaust fitted, at the mouth's centre, its LookVector (the attachment's -Z) out of the pipe. Stock: one per stock outlet. With tips: only the tips (they replace the whole exhaust); an own pipe left showing beside them (the other pipe of a twin under a single tip) gets no outlet. The flame contract; switching the exhaust item rebuilds them. |

**Exhaust spots, measured 2026-09-28** (near-orthographic captures from behind, the side and below, calibrated at ~700 px/m; car metres before scale):

| Car | Stock mouth(s) (x, y, z) and what they are | Tips y / mouth z / spread | bumperZ | Parts: stock / single / twin / quad |
|---|---|---|---|---|
| kamri | factory pipe (-0.55, 0.33, 2.47): no pipe on the generated body | 0.30 / 2.48 / 1.1 | 2.45 | 3 / 4 / 7 / 9 |
| krownvik | twin in Underbody (±0.715, 0.265, 2.655), 8° down | 0.265 / 2.78 / 1.43 (quad outer two at 2.745) | 2.75 (2.715 over the quad's outer tips) | 1 / 4 / 7 / 9 |
| krownvikfleet | twin in Underbody_6 (±0.715, 0.265, 2.665), 8° down | 0.265 / 2.79 / 1.43 (quad outer two at 2.755) | 2.76 (2.725 over the quad's outer tips) | 1 / 4 / 7 / 9 |
| lekzas | chrome tips Chrome_2 (±0.553, 0.325, 2.52), slightly down | 0.24 / 2.635 / 1.106 (fix round 1, from 0.30 / 2.62: the bumper underside sweeps down over the tips, 0.39 m at the mouth to 0.32 m 15 cm in) | 2.59 | 1 / 4 / 7 / 9 |
| kamri07 | slash-cut tips P50 off mufflers P31 (±0.565, 0.337, 2.31) | 0.31 / 2.43 / 1.13 | 2.40 | 1 / 4 / 7 / 9 |
| batrol | single in Trim (-0.666, 0.485, 2.395), 29° out to the left | 0.44 / 2.52 / 1.332 (quad pairs at ±0.566, `quadSpreadM` 1.132, so a tip covers its pipe) | 2.49 | 1 / 4 / 7 / 9 |
| kruzer80 | single in Chrome_13 (0.60, 0.643, 2.41), a little out and 8° down | 0.62 / 2.47 / 1.2 (quad pairs at ±0.5, `quadSpreadM` 1.0: its pipe showed beside the right pair) | 2.44 | 1 / 4 / 7 / 9 |

Parts per car are the `LookExhaust` folder: 1 invisible outlet holder, plus per tip a mesh (a quad: one per pair) and a bore disc, and per pipe the routed pipe (garage round 3 §2): a straight, 3 bend chords, 3 ball joints and a hanger (8 Parts; the kruzer80's is 9, a riser and its ball but no hanger; +2 for the leg of a turned quad pair on the krownvik and fleet), or per factory pipe its routed pipe and bore. All massless, non-colliding, unqueryable, unshadowed, welded. The Parts column in the spots table above is Task 1's (garage round 3, before routed pipes); the per-look table below has today's counts. Outlets per item: stock 1-2 (one per stock outlet); with tips, exactly the tip count (1, 2 or 4) on every car.

**Tips per look (garage round 3 §1, fix round 1, measured in Play 2026-09-28 on kamri07, lekzas, batrol, kruzer80, hatch):**

| Item | Style | Visible parts (+ holder) | Mesh triangles (plus disc and pipe Parts) | EditableMeshes on the client (once, shared by every car wearing it) |
|---|---|---|---|---|
| Single Chrome Tip | rolled | 3 (tip, bore disc, pipe) | 1,312 | 1 (Rolled) |
| Twin Chrome Tips | rolled | 6 | 2,624 | 1 |
| Quad Tips | quad | 8 (2 pairs, 4 discs, 2 pipes) | 3,968 (2 x 1,984 per pair) | 1 (QuadPair) |
| Burnt Titanium Twin | slash | 6 | 2,744 | 1 (Slash) |
| Big Oval Tip | oval | 3 | 1,394 | 1 (Oval) |

**Parts per look with routed pipes (garage round 3 §2, counted in Studio 2026-09-28, the LookExhaust folder with its holder; outlets unchanged):**

| Car | Stock | Single | Twin | Quad | Titanium | Oval |
|---|---|---|---|---|---|---|
| kamri (factory pipe) | 10 (was 3) | 11 (was 4) | 21 (was 7) | 23 (was 9) | 21 (was 7) | 11 (was 4) |
| lekzas, kamri07 | 1 | 11 | 21 | 23 | 21 | 11 |
| krownvik, krownvikfleet (turned quad pairs) | 1 | 11 | 21 | 27 | 21 | 11 |
| batrol (fix round 1: no riser) | 1 | 11 | 21 | 23 | 21 | 11 |
| kruzer80 (a riser, no hanger) | 1 | 12 | 23 | 25 | 23 | 12 |

The cylinder fallback routes its pipes the same way, one per tip and one per quad pair between the pair's two cylinders (fix round 1; it was four pipes at the tips' own x, which ran the pickup's outer two through its rear tyres): a fallback quad is 25 parts, 29 on the krownvik and fleet, 27 on the kruzer80. The pipe Parts are cylinders, balls and a block.

**riseM per car** (raycasts up through precise-collision copies of the body pieces, then checked by eye from under the car; the why for each is in `CarCosmeticMounts`): kamri 0.04 (inside the body; factory 0.04), krownvik and fleet 0.04 (into their own pipes and mufflers), lekzas 0.03 (underbody 2.7 cm up, under its own chrome pipes), kamri07 0.04 (into its own mufflers), batrol 0.09 (underbody 9.2 cm up), kruzer80 0.30 (floor 30.5 cm up: a full bend and a 22 cm riser, its end 8 mm under the spec's boot line).

All five on one client take 4 EditableMeshes; each is freed when no car wears it, and none is taken unless the body reserve (5 today, see tipMeshReserve) stays free, so a tip never displaces a car body. A look change that leaves the exhaust item as it is (paint, rims, lights, strips) no longer rebuilds the tips; a change of tip style takes the new template before letting go of the old (final review I1). Where no mesh can be had the tips are cylinders (same outlets). Final pass (2026-09-29): generated body pieces keep their EditableMesh for the whole session (`MeshData.template`), so once a client has shown a Krown Vik (4) and a Batrol (1), 3 slots stay free and every tip style is cylinders on that client until it rejoins. Uploading the four tips (`meshAssetId`) removed this (2026-09-29): with all four uploaded, a Krown Vik shows mesh quad, oval, single and titanium tips, measured in Play. The reserve and cylinder fallback now only matter if an asset fails to load. Parts per car in the table above count the quad as 9 (was 13).

**Finishes** (the FINISH items; retuned 2026-09-28 in the lit bay). Under ShadowMap the view's lights give no specular highlight, and Metal and Foil ignore Reflectance on these meshes. A red Lekzas at Metal with Reflectance 0.08, and again at 0.35, was the same flat red as SmoothPlastic. EnvironmentSpecularScale and EnvironmentDiffuseScale changed nothing indoors. Glass is the one material that picks up the view's lights, as a sheen. So the ladder is:

| Finish | Material and reflectance | Colour treatment | How it reads in the bay |
|---|---|---|---|
| factory | the car's own | none | flat |
| matte | SmoothPlastic | `darken` 0.2, `desaturate` 0.3 | dull, clearly flatter than factory (the old 8% darken could not be told from factory on red) |
| gloss | Glass, 0 | none | the colour, with a lit sheen on the bonnet, roof and flanks; gloss black reads as real gloss black |
| metallic | Glass, 0.05 | `darken` 0.25 | sheen over the whole panel: navy turns slate-silver, red turns a lighter pinkish red |
| chrome | Glass, 0.15 | none | pale silver tinted by the paint (0.3 with the colour lightened read as a plain white car) |

- **Rims:** chrome is Glass 0.15 (#B8BCC2) and gold is Glass 0.05 (#B8892E). Gold reads as bright gold with a sheen; chrome reads near white.
- **Round 2 additions** (2026-09-28, lit bay, kamri07 / lekzas / kruzer80 / krownvik / batrol / fleet): Candy Red rims (Glass 0, #A3161C) read as bright gloss red; Champagne (Glass 0.05, #C4AE84) as cream gold. The bay lifts and warms every paint, so the new paints were picked on the car, not the swatch: Najd Clay #6B4636 renders terracotta (#9A4B30 rendered as a second Sodium Orange), Oasis Teal #1E6B68 a bright teal, Gulf Blue #7A9BB5 a pale blue (it replaced a saffron that rendered as a second Sodium), Wadi Olive #474E36 a military olive (#5C5A3C read mustard beside Dune Gold). Sun strips: Natl (نطل, green on black) and White Strip (HAJWALA, black on white; the most readable strip from the view).
- **The knobs:** each finish item's `material`, `reflectance`, `darken` and `desaturate`. Glass reflectance is very steep: 0.04 already washes a colour.
- **Not reachable under ShadowMap:** a mirror chrome. Red chrome reads salmon.

Paint and finish only show on cars with `paint = true` body pieces; on a car with none `CarCosmetics.paintable(carId)` is false and the garage panel greys paint and finish out. Every car has them today (the single-shell Pickup and Cruiser that had none were removed 2026-11-08).
Likewise a car with no windscreen or exhaust spot in `CarCosmeticMounts` would get its SUN STRIPS or EXHAUST items greyed out (`CarCosmetics.hasSpot(carId, "windscreen" | "exhaust")`); every catalog car has both today, and `CarCosmeticMounts.spec` fails if a new car ships without them.

**Window tint** (garage round 2 §4, 2026-09-28; the TINT items, a third row under PAINT). Each car lists its glass pieces in `CarCosmeticMounts` `windows`: `side` (door, quarter and rear windows), `screen` (the windscreen alone) and `whole` (one piece that is the windscreen and other windows together: the lekzas, batrol and kamri all-round glass, and the krownvik's windscreen-roof-rear piece). A film puts every listed piece on SmoothPlastic in its `glassColor`, at `glassTransparency` for side, `screenTransparency` for screen and halfway between for whole. Factory puts each piece's colour, material and transparency back exactly (checked on all ten cars: no body part differs after a full look and back to stock).

| Film | side | screen | whole | Read in the lit bay |
|---|---|---|---|---|
| Light | 0.5 | 0.7 | 0.6 | clear, cabin plainly visible; lighter than the kamri07's factory doors (0.2) |
| Dark | 0.3 | 0.62 | 0.46 | smoked sides, cabin still visible through the windscreen |
| Limo | 0.12 | 0.55 | 0.335 | near-black sides with a little depth; windscreen still shows the dash and the strip |

- SmoothPlastic whatever the factory glass was: the krownvik's glass is white Glass at 0.3 and reads clear, and a dark colour on Glass at the same transparency went pitch black, strip and all.
- Absolute, not relative to factory: a film limited to "never clearer than factory" did nothing at all on the kamri07, whose doors are already 0.2.
- The strip stays readable under every film (inside strips on the lekzas, krownvik and fleet were checked at Limo; the lekzas's all-round glass was also checked at 0.2).
- A car with no `windows` would have TINT greyed out with "This car's windows can't be tinted yet"; every car has them, and `CarCosmeticMounts.spec` fails if a car ships without windows, or lists a piece its body does not have.
- **Rollout (owner's call):** `tint` is a new look slot. Economy now carries any stored slot it does not know across a save, so every slot after tint is safe on an older server, but servers already deployed without that carry drop tint on a known car when they save. Ship tint as a single-version rollout (no old servers alongside new ones), or accept that a tint chosen during the overlap can be lost.
- **The knobs:** each film's `glassTransparency` / `screenTransparency` / `glassColor`. Keep `screenTransparency` at 0.5 or more (the spec checks it and that it is above the side value), so windscreens stay legal-looking.

## cityscape
| Field | What it does |
|---|---|
| seed | Fixed, so every server draws the same city. |
| band | The backdrop skyline: a band along one side of the road (side +1 is the right, away from the sun) from fromAlongM to toAlongM (metres from the start line; negative is behind it), full density at densestAlongM easing to thinFraction at the ends. Each row is { nearM, farM (from the centreline), count (slots along the band), size and height ranges, towerChance }: a low front row at 1.3 to 1.6 km so the towers behind have a foot, and the tall back row at 1.6 to 2.4 km. Widen it with fromAlongM/toAlongM; move it with densestAlongM; bring it in with nearM, but past 2.5 km the haze takes it. |
| downtown | The tall slim cluster: centred alongM from the start line, bunched within spreadM, between nearM and farM, plus one wide dim Neon slab along its base (the sodium haze). Anything that would land inside the city grid is skipped. |
| landmarks | Kingdom-Centre style (slab, two pillars, sky bridge: the arch) and Faisaliah style (four corner wedges as a pyramid, a globe near the tip), each placed by alongM and lateralM. |
| lights | alwaysOn keeps the city lit at every hour; dayExtraTransparency pulls every light back in daylight (0 now: solid Neon is what survives the haze). ledStrip* are the vertical LED strips up tower corners, ledPalette the weighted colours they and the rings and spires come in (gold and cool white mostly, some magenta, cyan, green), ring* the lit rings round towers at random floors, roofEdge* the lit line along block roofs, spire* the lit needle on some towers. |
| tierChance / crownChance / antennaChance / antennaHeightM | A narrower tier on top of a share of buildings, a lit band at the top of towers, and an antenna on some. |
| windowSegments / blockBands* / towerBands* / windowHeightM / windowInsetM / windowColorWarm / windowColorCool / coolFraction | Emissive floor bands, split into segments of different brightness so floors read as lit and unlit, warm or cool per building. Cheaper than a texture and needing no asset. |
| color / towerColor / colorVariation | Blocks warm, towers bluer (glass). Darker than the first pass: the haze adds sky colour at this range and a mid tone came out pale. |
| beaconChance / beaconColor | Red aircraft warning lights on towers. |

## scatter
| Field | What it does |
|---|---|
| seed | Fixed, so the desert is identical on every server. |
| useMeshes | Real meshes from AssetRegistry. Off, or a mesh that fails to load, gives the primitive stand-in. |
| palm.medianEnabled / medianClumpSpacingM / medianJitterM / medianMarginM / medianMaxPerClump | The planting down the reservation: a clump of up to medianMaxPerClump every spacing, jittered along and across, never inside the margin of a kerb. Sparse now (a pair every 90 m in the 8 m median) on request. |
| palm.varietyFraction | Fraction of palms that use the second mesh. |
| palm.minScale / maxScale | Height range. Uniform height is the thing that reads as copied. |
| scrub.* | Desert clumps on the verges (AssetRegistry.scrubs: five grasses and shrubs plus the old bush) in clusters of clusterMin..clusterMax within clusterSpreadM every spacingM, and at `medianChance` between the median palms. minSizeM/maxSizeM is the clump size. |
| tree.* | Acacia-style trees on the verge: spacing, jitter, chance, edge band, scale range (the mesh is 4.5 m at 1). |
| artifacts.campSpacingM / campJitterM / campChance | A roadside camp every spacing or so: a tent facing the road, a carpet in front of it, camels loitering beside. |
| artifacts.minEdgeM / maxEdgeM | How far out from the verge a camp can sit. |
| artifacts.camelsMin / camelsMax / camelSpreadM | Camels per camp and how far they wander from the tent. |
| artifacts.carpetChance / carpetSizeM | The carpet: a thin Part with a decal, twelve triangles. |
| artifacts.strayCamelSpacingM / strayCamelChance | Camels on their own between camps. |
| falloffStartM / falloffEndM | Density falls off with distance from the road, so the near shoulder reads as maintained and the far desert as empty. |
| palm.clumpSpacingM / clumpJitterM / minPerClump / maxPerClump / spreadM / minEdgeM / maxEdgeM | Outer palms go in loose clumps. Evenly spaced trees read as generated; clumps read as planted. Denser on request: a clump every 45 m, up to four trees, out to 60 m from the road. |
| palm.minEdgeM / maxEdgeM | Band either side of the road they can occupy, measured from the kerb. |
| palm.trunkHeightM / trunkWidthM / frondCount / frondLengthM / frondWidthM | The primitive stand-in's proportions, used until a mesh is approved. |
| palm.leanMaxRad | Palms lean. A vertical pole reads as a lamp post. |
| rock.* / debris.* | Same spacing, jitter and edge-distance rules at lower density. |
| drift.* | Sand banked against the outer kerb: spacing, chance, and the length, width and height of each wedge. Cosmetic. |

## streaming
| Field | What it does |
|---|---|
| enabled | Records intent. `Workspace.StreamingEnabled` is a place setting; a runtime script cannot write it. |
| targetRadius / minRadius | Also place settings, and not exposed to Lua at all — set them in the Studio Properties panel. |
| roadPersistent | Keeps the road replicated always. **Leave this on.** The client owns vehicle physics, so a car that outruns the streamer finds no road under it and falls out of the world. |
| palmsPersistent | Keeps every palm replicated. Off, the median is bare ahead of the car at speed because the streamer cannot keep up. ~650 mesh pieces. |
| cityscapePersistent | Stops the horizon popping. ~300 small boxes. |

---

# City (`src/server/World/City/CityConfig.luau`)

Not live-reloadable either; restart the server.

| Field | What it does |
|---|---|
| originM / blocksX / blocksZ / blockM | Where the north-west roundabout sits (world metres) and how many blocks the grid grows east and south. Now 2 x 2 at 360 m: origin (-360, -2022) puts the central boulevard on the highway axis (x = 0). To grow it, keep originM.x = -blockM * gateway.i so the highway still lands on a boulevard. |
| gateway.i / gateway.widthM | Which first-row boulevard the highway feeds (1 now) and the width of that square, so the whole road lands on asphalt. |
| boulevard.widthM / medianWidthM / laneCount / parkingLaneM | The cross-section: 48 m kerb to kerb, an 8 m palm median, three 5.7 m lanes and a parking lane each way. |
| surface.asphaltColor / sideStreetColor / tyreTrackColor | The first two tint the asphalt texture like the highway's (near white). Tyre tracks are SmoothPlastic, so tyreTrackColor is the rendered colour: keep it a shade under the grey road. |
| boulevard.vergeM | The kerbed lawn between carriageway and parcels, both sides (18 m). It is also the room a roundabout ring has at the corners: keep radiusM under about vergeM + half the boulevard + 8, or the ring reaches the parcels. |
| sideStreet.widthM | 16 m, one lane each way plus parking. |
| roundabout.radiusM / gatewayRadiusM | Outer edge of the ring carriageway (48 m, 55 m at the gateway, where the highway's 79 m corridor runs in). Bigger is a better drift circle and eats more verge. |
| roundabout.islandRadiusM / gatewayIslandRadiusM / islandHeightM | The raised island; its kerb is the one raised thing in the city that collides. |
| roundabout.laneWidthM / splitterNoseRadiusM / kerbSegmentM | Ring lane marking width, the rounded median nose at each entry (half the median), and the length of the straight pieces the curved kerb is made of. |
| roundabout.kerbProudM / rimWidthM | How far the ring kerb stands above the lawn (0.03 m; at 0 they z-fight), and the asphalt band under and inside the kerb (1.5 m) that covers the ring disc's polygon edge. |
| roundabout.lampSetbackM / lampSpacingDeg | Mesh lamp posts round the ring: how far outside it and how far apart. |
| roundabout.palmsOnIsland / lawnColor / shrubColor | Island planting. |
| roundabout.monuments / monumentScale | The centrepieces, in turn round the grid: "dallah", "obelisk", "fountain". The gateway always gets the Riyadh arch. |
| lights.coolLed / warmLed | The city's two LED colours: cool for rings, strips and edges, warm for uplights and plinth lines. |
| lights.medianLed | An LED line along both median kerbs of every boulevard. |
| lights.towerStripChance / towerRingChance / towerRingsMin / towerRingsMax / stripWidthM | LED strips up box-tower corners and lit rings round them, in the skyline's palette. |
| lights.vergeLawnColor / vergePalmSpacingM / vergePalmOffsetFrac | The verge lawn, and date palms with uplights down it. |
| ramp.offRamp / onRamp / widthM | Waypoint lists { x, z, width } in world metres; empty now that the highway ends in the grid. For a side entry, start them just outside the highway kerb (35.4 m from the centreline) as a narrow taper. |
| surface.* | Slab thickness, run cap (streaming), colours, tone jitter, kerb dust, marking sizes, tyre tracks, pavement width. |
| districts | One row per block row, one entry per block: commercial, towers, plaza, residential, lot. |
| buildings.palette / accentPalette / accentChance / tone | Sand, cream and warm grey, the odd colour, per-part jitter. |
| buildings.meshChance / meshMinScale / meshMaxScale | Share of shop slots that take a textured mesh building (AssetRegistry.cityBlocks) instead of a box shop, and how far a mesh may be scaled to fill its frontage. 0 gives the all-box city back. |
| buildings.commercial.* | Shop row sizes, storeys, gap chance, setback, awning, fascia colours, sign chance. shopNames is the { arabic, english } list the shop signs and blade signs draw from; crenellationChance is the share of shops with a Najdi crenellated parapet; mashrabiyaChance the share with a timber lattice screen on the third storey; najdiVentChance the share with a row of diamond vents under the parapet. |
| buildings.litChance | Fraction of first-floor window segments that glow. 0: a lit strip on a textured wall read as a blank panel at golden hour. |
| buildings.residential.* | Lot size, wall height, gate, villa size and storeys, tier and dish chance. |
| buildings.towers.* | Podium size and storeys, tower storeys and width, glass and frame colours, setback chance, crown colour. meshChance is the share of tower spots that take a mesh tower (AssetRegistry.cityTowers), meshScales the scale range per mesh; a mesh tower is never wider than podiumMaxM. |
| buildings.plaza.* | Bay geometry for the few painted rows. |
| furniture.* | Palm, lamp, bin, bench, parked-car and signal densities. A parked car is five parts; parkedCarChance is the first thing to cut on a slow phone. lampMeshScale is the scale of the highway's mesh post used for city lamps (0.85, a 9 m post); lampHeightM and the rest of the lamp fields only size the box stand-in. |
| shadows.* | Which city things cast: buildings and palms yes, compound walls, lamps and furniture no. |

## technology / fogEnabled / debug
| Field | What it does |
|---|---|
| technology | The intended `Lighting.Technology`. A script can neither write nor read it, so this is a record and a reminder; set it by hand. `ShadowMap` is what the shadows are tuned for, `Voxel` is the mobile fallback and makes them blobby. |
| fogEnabled | Legacy distance fog. Off: Atmosphere does the fade, and fog thick enough to sell distance hides the road edge. |
| debug.report | Prints the per-system part and triangle report at build. |

# Plates (`src/shared/PlateConfig.luau`)

Number plates (docs/superpowers/specs/2026-09-26-number-plates-design.md).

| Field | What it does | Which way |
|---|---|---|
| `prices.SA[1..4]` | Saudi cash price by number of digits (500,000 / 200,000 / 75,000 / 20,000) | First guesses; the owner sets them against how fast cash is earned |
| `prices.DU[1..5]` | Dubai cash price by number of digits (1,000,000 / 400,000 / 150,000 / 40,000 / 15,000); higher than Saudi as Dubai numbers are the prestige market | First guesses, as above |
| `prices.AD[1..5]` | Abu Dhabi cash price by number of digits (900,000 / 350,000 / 125,000 / 35,000 / 12,000) | First guesses, as above |
| `prices.KW[1..5]` | Kuwait cash price by number of digits (600,000 / 250,000 / 90,000 / 30,000 / 10,000) | First guesses, as above |
| `repeatMultiplier` | Price multiplier for Saudi AAA letters or all-identical digits in either style (2) | Up to make those rarer |
| `pendingSeconds` | How long a purchase holds a plate while cash is taken (120) | Down frees abandoned claims sooner; never below about 20 s — a purchase can queue behind the 6 s per-key write limit twice plus the lock |
| `availabilityCacheSeconds` | How long a server trusts a "free" answer (30) | Down shows sold plates sooner, at a read per plate per search |
| `availabilityCacheMax` | Entries the availability cache holds before it is cleared (2000) | Up if legitimate searches are clearing it early; a player cycling plate strings would otherwise grow it for the life of the server |
| `historyLength` | Owner history lines kept on a plate key (5) | |
| `maxInputBytes` | Longest plate text accepted (64) | |
| `queriesPerSecond`, `actionsPerSecond` | Remote rate limits per player (2, 1) | Down if the DataStore budget runs short |
| `minReadBudget` | PlateQuery backs off to "busy" below this `GetRequestBudgetForRequestType(GetAsync)`, live store only (30) | Up to protect profile loads and plate settlement harder; down if searches feel throttled with budget to spare |
| `defaultPicks` | Tries to find a default plate nobody owns (3) | |
| `retrySeconds` | Retry period for an unfinished purchase or release (30) | |
| `studioCash` | Starting cash in Studio's fake store (2,000,000) | Studio only |
| `standoffM`, `thicknessM` | Plate offset from its spot and thickness (0.006, 0.01 m) | Up `standoffM` if a plate flickers against the body |
| `drawDistanceStuds` | Plates beyond this are not drawn (150) | Down for phone performance |

# Cosmetics (`src/shared/CosmeticsConfig.luau`)

The garage's items (docs/superpowers/specs/2026-09-28-garage-design.md), read by the server (`CosmeticsService`), the look renderer (`CarCosmetics`, `CarLamps`) and the garage panel. How a look is drawn is `render` (World section above, "CosmeticsConfig.render"), with the finish ladder.

| Field | What it does | Which way |
|---|---|---|
| `actionsPerSecond` | Garage actions (buy, equip, plate) a player may send per second through `CosmeticsAction`; more get "busy" (4) | Each is one tap, so 4 is well above a person and below a script. Down if the DataStore budget runs short |
| `CATEGORIES` | The look slots, in the order `CarLook.encode` writes them. `tint` (garage round 2) was added last, so every look string written before it encodes the same | Append only |
| `items[].id` | The permanent id stored on profiles (in the `Looks` string) | Never rename a shipped id; only add |
| `items[].price` | Cash price. 0 marks the category's free factory item (`stockId`), exactly one per category | First guesses in PlateConfig's economy (10,000 to 200,000 here); the owner sets them against how fast cash is earned |
| `items[].rare` | Shows the dusk diamond in the panel; nothing else | |
| `items[].color` | Paint: the body colour. Rims: the rim colour. Head / tail: the lamp colour (a tail's brake lamp is `render.brakeBrighten` brighter) | |
| `items[].material` / `reflectance` | Finish and rims: the material and reflectance painted pieces or rims take. Nil material keeps the car's own | Glass reflectance is steep: 0.04 already washes a colour (finish table above) |
| `items[].darken` / `desaturate` | Finish only: the paint colour's value and saturation this much lower (0..1). Matte 0.2 / 0.3, metallic 0.25 | Up for a duller, deeper base |
| `items[].text` / `textColor` / `stripColor` / `stripColor2` | Sun strip (`decal` items): the strip's text and colours; a second strip colour makes it a gradient | |
| `items[].tips` / `tipColor` / `tipMaterial` / `tipStyle` | Exhaust: how many tips (0, 1, 2 or 4), their colour and material, and their modelled shape (`render.tipStyles`). Chrome (single, twin, oval) is #C2C6CC Metal (fix round 1, from #D8DADD Foil, which crinkled close up and bloomed near white under the bay's lights): reads polished without bloom in the bay and at sunset | `tipMaterial` on the chrome items is the feel knob |
| `items[].glassColor` / `glassTransparency` / `screenTransparency` | Tint: the film's colour, and the transparency it gives side windows and the windscreen (an all-round piece takes halfway). Light 0.5 / 0.7, Dark 0.3 / 0.62, Limo 0.12 / 0.55 | Down for darker. Keep screen at least 0.5 and above side (window tint table above) |
| `items[].engineVolume` / `crackleChance` | Exhaust: multiplies the engine sound's volume and the number of pops (1.1 to 1.35, 1.3 to 2.5). In a style, the pop count goes as 1 + (crackleChance - 1) x the style's `chanceGain` (0.25-0.35; Classic 1), so a titanium crackle is ~1.5x a factory one, not 2.5x | Down if a tip is too loud; crackle scaling is not yet checked by ear |
| `items[].flameSize` / `flameCore` / `flameColor` | Exhaust: the flame profile. flameSize scales every flame length and size in every style (factory 0.9, single 1.2, twin 1.25, big oval 1.3, quad 1.4, titanium 1.5); flameCore is the hot core's colour at the mouth (factory #6C8CFF pale blue, sport #3A6BFF, quad #2E62FF, titanium #6A3CFF blue-violet); flameColor the tongue's body (#FF6A1A to #FF8A24). The two colours apply to Classic only; the other styles carry their own | Keep cores saturated: pale blues read white under bloom |

### `flames` (exhaust flames, `ExhaustFlames`): the Classic style

These are the garage round 2 flame, kept as the **Classic** exhaust style (`ExhaustStyles`, next section) to compare the new ones against. One pop is a layered burst at every `ExhaustOutlet` (CarCosmetics), all `Emit`, no Light. Built in Edit and Play on 2026-09-28 by freezing the effect at set ages (BEHAVIOURS, "Freeze a particle effect"), judged from the side, a drift 3/4, the chase cam at 100 km/h, at sunset and night, and on the garage turntable. Lengths are metres before the car's scale, times the item's flameSize.

| Layer | What it is | Particles per pop per outlet |
|---|---|---|
| `core` | Blue-white cone at the mouth, let out over 0.09 s, 0.05-0.08 s life, drawn nearest the camera | 5 |
| `flash` | Camera-facing glow on the mouth for 0.08 s, in the flameColor: the pop from straight behind, and the light the cap rules out | 1 |
| `tongue` | The flame body: 9-10 stretched particles over 0.08 s at 3-8 m/s with drag 6, fullest early and shrinking after, so it tapers; orange-yellow to the flameColor to deep red; rises 8 m/s² so it curls up as it dies | 9-10 |
| `lick` | A wider, fainter envelope round the tongue (5-6 over 0.09 s) | 5-6 |
| `sparks` | Hot flecks thrown back and falling, in the world | 0-3 |
| `smoke` | A faint dark wisp 0.06 s after, in the world | 1 |

Most per pop per outlet: 26 (spec: at most 30). A titanium lift-off (up to 8 pops) on twin tips is at most 416 particles over half a second, each alive under 0.25 s except smoke (1 s) and sparks (0.45 s).

| Field | What it does | Which way |
|---|---|---|
| `mouthLeadM` | Flames start this far out along the outlet, plus however far the mouth sits inside the bumper (bumperZ), so a recessed stock pipe (kamri07, ~9 cm in) still shows its core (0.015) | Up if a car's core hides in its bumper |
| `trailFullKmh` / `trailGain` | At speed the car-locked layers reach further back: speed times 1 + trailGain x (kmh / trailFullKmh, capped at 1). 160 / 1.2 (a style may set its own trailGain) | Up for longer flames at speed |
| `inheritVelocity` | Sparks and smoke keep this much of the car's velocity when born (0.8), so they fall back rather than drop at the tip | |
| `glowColor` / `glowAmount` / `glowSeconds` | A built tip (or factory pipe) is pulled this far toward this orange at each pop and eases back (0.6 over 0.45 s) | Down if the tips flash too much |
| `timeScale` | Studio inspection only: particle time for a harness to slow and freeze a pop. Must stay 1 (spec) | |
| `layers.*` | Each layer's texture (built-in `rbxasset://textures/particles/...` only, each checked to load), count, jetSeconds (let out over this long), lifetime, speed, spread, drag, riseMps2, size / transparency / squash keyframes, colours, lightEmission, brightness, locked (rides with the car), alongMotion (VelocityParallel), zOffsetM | Keep Brightness at or near 1 on coloured layers (BEHAVIOURS, "Colour past 1 goes white") |

### `ExhaustStyles` (exhaust pop styles; `ExhaustSputter`, `ExhaustPops`)

Asked by the owner on 2026-10-04: "different exhaust flame variants but really cool ones ... the audio has to be like the sputter". Design, research and plan: `docs/superpowers/specs/2026-10-04-exhaust-flame-variants-design.md`, `...-research.md`, `docs/superpowers/plans/2026-10-04-exhaust-flame-variants.md`. A lift-off is a **burst**: `ExhaustSputter.generate(pattern, seed, scale)` makes its pops (time, size class small/mid/big, level 0..1); each pop plays a real pop cut from a recording (`Sound.PlaybackRegion`) and fires its flame on the same frame, and the newest pop of any car moves the one pooled flash light. The driver sends one relay message a burst (kind, style, seed, scale); every client rebuilds the same burst. A lift mid-drift is a **flutter** instead (`styles[].flutter`, below; 2026-10-05).

| Style | Rhythm (pattern) | Sound | Look |
|---|---|---|---|
| `crackle` (Crackle) | 7-14 pops; gaps 30-70 ms easing to 120-300 ms, jittered by half; 1 in 5 a quick double (15-35 ms); mostly small, the odd big; fades to 0.45 | pops-and-bangs grains by size, six clean pops, one crack | ragged animated flame licks (~1 m plume at a big pop) over a blue root, an orange glint, a dark wisp; no sparks |
| `blue` (Blue Flame) | 3-6 sharp cracks, even 70-110 ms | small and mid pops pitched up 1.1-1.4 | a blue-violet torch (~1 m) with a white core and violet fringe, a blue light |
| `twostep` (2-Step) | 6-10 bangs on an even 90 ms beat (6% jitter; gaps within 12% of each other, spec'd under 17%) | the dense crackle's grains | fireball bursts with licks and sparks |
| `classic` (Classic, the default) | 1-3 pops in 0.5 s, whatever the revs (`revScaled` false) | "Car Backfire Exhaust" whole, 0.35 x 0.55-1, pitch 0.85-1.2 | the `flames` table above |

An Anti-Lag style (2-4 big bangs with fireballs, sparks and soot) was tried and taken out at the owner's word on 2026-10-05: "get rid of the anti-lag one completely for now" (its last version: commit `ca776e7`).

Measured in Play (kamri07, harness, lifting at 110-125 km/h, 2026-10-05): Crackle 8 pops thinning over about 1 s (0.08, 0.14, 0.28 double, 0.34, 0.48, 0.60, 0.82, 0.97 s); each pop's sound and light on the same frame; a stab of throttle stops the rest; one server message a burst and one a cut. Frame time with a quad exhaust bursting every 1.5 s: median 16.6-16.8 ms per style against 15.3-16.6 ms with none (Studio caps at 60 fps, so this shows no frame lost rather than a cost in ms).

| Field | What it does | Which way |
|---|---|---|
| `default` | The style every car uses | The owner's pick |
| `order` | The Studio switch's cycle; the index is what the relay sends | Append only (relayed numbers) |
| `styles[].pattern` | `kind` (burble or uniform), `count` (pops at scale 1), `maxPops`, `minGap`, `maxSeconds`, `first` (the first pop's size), `weightsStart`/`weightsEnd` (how likely small/mid/big are, eased over the burst), `fade` (the last pop's level), `levelJitter`; burble: `gapStart`/`gapEnd` (s), `jitter`, `doubleChance`/`doubleGap`; uniform: `spanSeconds` | Wider jitter reads as a burble, near zero as a 2-step; longer gapEnd = a longer tail |
| `styles[].flutter` | The drift flutter: what a lift with the car sideways fires instead of the burst (EngineAudio, `driftFlutterFromDeg`). A pattern like `pattern`, dense and mostly small so the flames overlap into a flickering tongue: Crackle 8-12 pops 30-50 ms apart easing to 80-140; Blue Flame 6-10 at 40-50 easing to 60-80; 2-Step 6-10 on an even 60 ms; Classic 3-5 at 40-70 ms. The gas back on cuts it. Relayed as its own kind (4). | Shorter gaps: a faster flicker |
| `styles[].chanceGain` | How much the exhaust's crackleChance adds pops | |
| `styles[].trailGain` | The style's own reach at speed for car-locked layers (0.4: at Classic's 1.2 Blue Flame's jets flew 2-4 m behind the car at 110 km/h, cut off) | Up for longer flames at speed |
| `styles[].sounds.{small,mid,big}` | `grains` (clip, from, to, gain), `pitch` range, `volume`: Volume = volume x gain x level | Volumes are first guesses by measured peak, not checked by ear |
| `styles[].classes.{small,mid,big}` | Multipliers on the layers' size, particle count and speed, and on the light, per pop size | |
| `styles[].light` | Colour, brightness at a full big pop, range (m), fade (s). Crackle 1.5 at 5 m, Blue 1.8 at 5 m, 2-Step 2 at 6 m: a first try at 6 at 12 m washed the whole car and road orange-white | Down if it lights too much |
| `lightMaxDistanceM` | The one flash light only answers pops this close to the camera (60 m), so a car across the map doesn't take it from the one in front of you | |
| `textureFallback` | A built-in stand-in for each Creator Store texture; ExhaustPops preloads the textures and a layer whose texture failed draws its stand-in, without the flipbook | |
| `styles[].revScaled` | false: the revs of the lift don't change the count (Classic) | |
| `styles[].layers` | As the `flames` layers plus `flipbook` (grid, OneShot), `from` (the smallest pop size that emits it), `colors` keyframes, `turn` | At most 40 particles a big pop per outlet (spec); flash glints 0.45-0.7 m at Brightness 1.2 (at 1.3 m and 2.2 two outlets' flashes burnt to a white blob) |
| `clipSeconds` | Measured clip lengths; the spec keeps every grain inside its clip | |
| `relayPerSecond` / `maxScale` | Server relay: 12 messages a second per player (feathering four times a second sends a flutter and a cut each time, 8; at 8 a fast keyboard feather's cuts could be dropped); a burst's scale at most 4 | |

**Picking one: the flames** (garage-tyres-flames, 2026-10-05; the owner: "have classic be the default and the other flames purchasable in the garage"). Each style is a flame in `CosmeticsConfig` (category `flame`: `flameStyle`, and `flameCore` / `flameColor` for its tile): Classic free (`flame_classic`, `ExhaustStyles.default`), Crackle 20,000, 2-Step 30,000, Blue Flame 40,000, first guesses. Bought once and fitted per car in the garage's EXHAUST tab under the tips (greyed out where the car has no tips: the flames come out of their outlets); REV plays the flame showing. The driver's client reads the flame from the car's `Look` attribute and other clients see the driver's style, since each burst carries it. The exhaust item still scales whichever flame is on (`crackleChance`, `flameSize`).

**Trying the styles (Studio only):** P cycles this client's style through `order`, over the fitted flame; a label shows its name for 1.5 s and the LocalPlayer attribute `FlameStyle` holds it (set it by hand to pick one, clear it to go back to the fitted flame).

**The owner's feel knobs for the flames:** `ExhaustStyles.default` (the free style; keep it the stock flame's `flameStyle`), the flames' prices in `CosmeticsConfig`, each style's `pattern` (`count`, `gapStart`/`gapEnd`, `jitter`: how much and how sputtery), `sounds.*.volume` (how loud), the layers' `size` and the classes' `size` (how big), `light.brightness`, the items' `flameSize` (bigger or smaller flames per exhaust), `trailGain` (how far flames reach at speed), and `crackleShiftChance` / `crackleLimiterPerSecond` (upshift and limiter pops; 0, off, by default per the owner's 2026-09-22 ruling).

**The owner's feel knobs for the garage:** `GarageConfig.lights.key.brightness` (hotter highlight, more bloom on white), `GarageConfig.fovDeg` (longer lens, farther eye; the wall limits it), the finish items' `material` / `reflectance` / `darken` / `desaturate` (the finish ladder above), and `GarageConfig.bakedGlow` (how much painted-on light the interior keeps per sky option).
