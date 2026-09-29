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
| cars.&lt;id&gt;.tuning | Any part of CarConfig this car tunes differently, deep-merged (arrays replace). The hatch softens its springs to 27000/2100 for its 1250 kg; the pickup and cruiser are almost all tuning (below). |
| cars.&lt;id&gt;.displayName / blurb / order | The spawn menu card: name, one line under it, and position (low first, then by name). |
| spawn.autoSpawnOnJoin (CarConfig) | false: players start on foot with the spawn menu open. true: a car is parked for them at join, the Phase 0 way. |
| spawn.spawnCooldownSeconds (CarConfig) | Shortest gap the server allows between two spawn requests from one player (1.5 s). |
| spawn.carId (CarConfig) | Overrides the default for everyone without a `CarId` attribute. |
| spawn.showRig (CarConfig) | Draws the collision box, hubs and seat translucent over the body, for fitting a new car. |

### Car personalities

The pickup and the cruiser were added with catalog entries only: a rig, one body mesh, and a `tuning` block. No code changed for them. Each one is described below by what it feels like, the fields that make it so, and which way to move them. All three cars share every other number in CarConfig.

These numbers were measured in Studio, focused, at scale 1.2, using the input-override harness on the test road. The table gives the same protocol for each car.

| | Sedan (baseline) | Pickup | Cruiser |
|---|---|---|---|
| Mass / wheelbase / track | 1600 kg / 2.8 / 1.55 m | 2200 kg / 3.15 / 1.64 m | 1800 kg / 3.0 / 1.7 m |
| Centre of mass (car space, +Z back) | 0.2 m forward | 0.25 m back | 0.1 m forward |
| Box centre above road at rest | 1.063 m | 1.085 m | 0.864 m (sits 0.2 m into its travel) |
| 0–50 / 0–100 km/h | 1.59 / 3.67 s | 2.70 / 7.20 s | 1.74 / 4.82 s |
| 100–0 km/h, full brake | 44.3 m | 59.1 m | 60.4 m |
| Turn-in at 80 km/h, half wheel: yaw at 0.1 s / 0.2 s | 22.9 / 29.6 °/s | 20.3 / 26.7 °/s | 5.5 / 17.4 °/s |
| … yaw still held at 3 s | 15.4 °/s | 17.9 °/s | 16.5 °/s |
| … peak body roll | 3.5° | 3.6° | 4.6° |
| Natl, 0.2 s lean tap at 105 km/h | 41°, down at 2.6 s | 32°, down at 2.5 s (0.6 s lean: 36°) | 34°, down at 5.1 s |
| Lever 360 from 110 km/h | 2.59 s, 52 km/h at 4.5 s | 2.78 s, 42 km/h | 2.75 s, 58 km/h |
| Slide held 20–70° with wheel centred, 5 s at gas 0.5 / 0.75 / 1.0 | 0.6 / 0.6 / 5.0 s | 0.5 / 0.4 / 4.9 s | 5.0 / 5.0 / 5.0 s |
| … exit speed at full gas | 73 km/h | 89 km/h | 97 km/h |
| Continuous lever 720, full lock and gas | 5.1 s | 5.4 s | 5.1–5.2 s |

**Pickup: heavy, slow to wind up, and once it goes, it goes.** It is the slowest car by far off the line and the longest to stop. A turn arrives a touch late but then keeps rotating. It takes the throw longest, and a slide carries the most momentum. Its natl lifts on the first tap but lower, with less to spare.

- **Launch.** `drivetrain.torqueCurve` peaks at 580 Nm against the sedan's 640 and runs out at 6000 rpm. `slipModel.wheelInertia` is 2.8 (the sedan's is 1.4) and `engineInertia` 0.45 (0.15). Together these give a slow, heavy launch.
  - To make it quicker, raise the curve. That keeps the heavy feel better than lowering the inertias.
  - The curve started at 520 Nm peak, which was 8.9 s to 100; at 580 it is 7.2 s.
- **Braking.** It stops late because `brakeForce` 15000 is hauling 2200 kg.
- **Turn-in and rotation.**
  - The yaw rate builds more slowly (`rig.shellMassFraction` 0.55 puts more mass out in the long box, so it has more yaw and roll inertia).
  - The front is lighter (`tires.front.grip` 0.95), and the wheel is slower (`steerSpeedDegPerSec` 200).
  - `centerOfMassM` 0.25 m back with `rear.grip` 1.1 keeps the tail planted until it goes.
  - `throwYawMaxTorque` 13000 means a throw gets less help, so its 360 is the slowest.
  - Going up on the rear numbers makes it more stable; going down on `shellMassFraction` makes it more eager.
- **Momentum.** `slideRelief` 0.35 and `leverRelief` 0.75 (less speed bled while sideways) are why it leaves a full-gas slide at 89 km/h.
  - Its slide sits shallow, 24–29°, because the heavy tail and grippy rear won't swing wider on their own.
  - To make it hold a wider angle, lower `rear.slideGripRatio` (0.88).
- **Natl.** `twoWheel.liftTorque` 16500 and `leanInTorque` 6000 are more than the shared torques (which lifted it only 11° before dropping) but less than the sedan-equivalent 21000/7500 (40°, as easy as the sedan).
  - This range is steep: 18000 gave 35° and 15000 gave 11°.
  - Stiffer springs (`stiffness` 45000, `damping` 4200, anti-roll 9000/6000) keep it at the sedan's ride height under the extra weight.

**Cruiser: big, soft and lazy on the way in; it holds a slide all day.** You wind the wheel on and the nose follows a beat later, while the body leans more than any other car's. A slide, once started, stays at part throttle with the wheel centred and exits fastest. On two wheels it floats up slowly and stays up twice as long as the sedan. It is moderately quick in a straight line and stops long.

- **Lazy turn-in.** At 0.1 s after the wheel moves it has a quarter of the sedan's yaw. Four settings stack for this:
  - `steering.steerSpeedDegPerSec` 100 (the sedan's is 320).
  - A slower speed lock, `speedLockCurve` 0.45 at 90 km/h (the sedan's is 0.55).
  - A soft front tyre that peaks late: `front.peakSlipDeg` 12, `riseShape` 1.0.
  - `rig.shellMassFraction` 0.6, for yaw inertia.

  Before the first, second and fourth were added, it turned in exactly like the sedan (20.6 °/s at 0.1 s), which is why all four are there. `steerReturnDegPerSec` stays at 300, and `counterSteerRelief` gives the whole wheel back in a slide, so catching one is not lazy.
  - To make it sharper, raise `steerSpeedDegPerSec` first.
- **Soft body.** `suspension.stiffness` 20000 and `damping` 1400 on `restLength` 0.45 and `travel` 0.32 give the sag, the float and the low stance. `antiRollFront`/`antiRollRear` at 1500/600 give the roll. Raise the anti-roll to lean it less.
- **Holds a slide.** `throwThrottleHold` 0.5 from `throwThrottleHoldFromDeg` 15 means half throttle past 15° keeps a slide. The sedan needs 0.8 past 20°, which is why it drops the slide at gas 0.5 and 0.75.
  - `throwThrottleHoldGraceSeconds` 1.0 and `throwThrottleHoldKeepDeg` 6 forgive a lift through a transition.
  - `throwHoldGain` 8 holds the angle stiffer.
  - `rear.slideGripRatio` 0.84 and `falloffShape` 2.0 keep grip past the peak, so it doesn't let go.
  - `slideYawDamping` 100 (the sedan's is 130) lets a released slide swing wider before it settles.
  - `slideRelief` 0.4 and `leverRelief` 0.8 keep the speed.
  - To make it harder to hold, raise `throwThrottleHold` back toward 0.8.
- **Engine.** A torquey, early curve (620 Nm at 3500, gone by 6000) with quick 0.14 s shifts pulls well to 50 and then fades: 4.8 s to 100.
- **Natl.** It gets no two-wheel overrides. The wide 1.7 m track and soft springs make the shared torques lift it slower and lower (34°). The low damping lets it hang up there for 5 s.

The sedan remains the reference: the quickest to answer the wheel, the easiest to throw, and the one that needs the most throttle to keep a slide.

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
| gearRatios / finalDrive | Shorter (bigger numbers) = more drive force at speed = easier to break traction with throttle. | ↑ | ↑ | — |
| reverseRatio | Reverse gearing. | — | — | — |
| drivelineEfficiency | Scales all drive force. | ↑ | ↑ | — |
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
| topSpeedKmh / topSpeedFadeKmh | The ceiling, as a limiter: drive fades to nothing over the last fade band so the car sits at the top instead of hitting a wall. 210 because the 400 m curve is at the grip limit at 220 and the straight takes 34 s. Raise for a faster map, lower for a tighter one. |
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
| touchSteerRatePerSec | How fast the wheel chases the thumb on the steer pad, in full-locks per second. 8 = a jump across the pad is a 0.25 s counter-steer. Higher = snappier, lower = calmer. |
| touchPadDeadzone | Fraction of the pad half-width around centre that reads as straight. Raise if the car wanders while the thumb rests. |
| touchPadFullAt | Fraction of the pad half-width where steer reaches full lock. Lower = full lock sooner, easier throws, coarser fine control. |
| touchPadCurve | Exponent on the pad position. Above 1 = finer control near centre, full lock still at the edge. |
| touchLeanDeadzone | How far the lean slider must travel from centre before it counts as a lean, as a fraction of its half-width. The slider springs back, so a flick out and back is one tap, which is what the two-wheel balance model wants. Lower = twitchier, higher = needs a deliberate push. |
| touchScale | Overall size of every touch control. 1.2 for big thumbs, 0.85 to see more road. |
| gamepadDeadzone / triggerDeadzone | Stick and trigger deadzones. |

## camera
| Field | What it does |
|---|---|
| positionLag / directionLag | Smoothing rates (1/s). Lower = lazier camera. |
| profileBlendRate | How fast profile parameters cross-fade (1/s). |
| minSpeedForSwingMps | Below this the camera ignores velocity direction. |
| driftProfileEnterDeg / driftProfileExitDeg | Drift angle that switches to the drift profile and back (hysteresis). |

### camera.profiles.normal / drift / twoWheel
The two-wheel profile is active while lifting or balanced; the drift profile past the enter angle; normal otherwise.
| Field | What it does |
|---|---|
| distance / height / lookHeight | Where the camera sits and aims, metres. |
| lateralOffset | Sideways offset: toward the lifted side on two wheels (airborne wheels in frame), toward the outside of the slide in the drift profile. |
| driftSwing | 0 looks along the heading, 1 along the velocity direction. |
| baseFov / fovPerKmh / maxFov | Speed-widened field of view. |
| rollFollow | Fraction of the car's roll applied as horizon tilt. Two-wheel profile only, by default. |

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

## effects
Visual only; the physics never reads any of these. Client-side, for the car you are driving.

| Field | What it does |
|---|---|
| enabled | Master switch for smoke, marks and wheel spin-up. |
| smokeSlipStartDeg / smokeSlipFullDeg | Rear slip angle where smoke begins, and where it reaches full rate. Fronts only smoke when locked under braking. |
| smokeMaxRate | Particles per second per wheel at full rate. Lower on weak phones. |
| smokeMinSpeedMps | No smoke below this speed, so a parked car does not fume. |
| smokeLifetime / smokeSize | How long a puff lasts and how big it ends up. |
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
| engineAudio.crackleSoundId / crackleVolume / crackleVolumeRange / cracklePitch | The exhaust pop and its loudness; each pop picks a random pitch and volume from these ranges. Empty id = no crackle. |
| engineAudio.crackleMinRpm / crackleMinKmh / crackleLiftFrom / crackleBurstPops / crackleBurstSeconds | Lifting from above crackleLiftFrom throttle while over both crackleMinKmh and crackleMinRpm fires a burst of (min, max) pops over crackleBurstSeconds. Throttle back on cancels the rest. Raise the speed or rpm for rarer pops. |
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
| referenceAngleDeg / referenceSpeedKmh | What "one unit" of angle and speed means. Lower either one to make every slide pay more. |
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
| maxPlausibleSpeedKmh | A sample faster than this throws the slide away. Set it above anything the car can actually reach. |
| teleportToleranceM | Movement beyond `speed x dt` plus this counts as a teleport and throws the slide away. Too low and normal replication jitter will eat honest runs. |
| serverTolerance | How far a client's claim may exceed the server's own total before it is capped. It exists because the two sample at different rates; 1.25 means a cheat can gain at most 25% over an honest run of the same slide. |
| claimWindowSeconds | How long a submitted claim stays usable. Past it the server banks its own figure. |
| sampleHz | Server sampling rate per driven car. Raising it tightens validation and costs server time. |
| autosaveSeconds | Cash autosave interval. |

## hud
| Field | What it does |
|---|---|
| enabled | Show the driver HUD (speed, gear, live slide score, drift angle, spins, natl roll, cash, records) top centre. |
| driftHighlightDeg | The DRIFT readout turns orange from this angle. |
| scale | Overall HUD size. Raise it for a small phone screen. |
| flashSeconds | How long a banked or dropped slide stays on screen before the row clears. |

## debug
| Field | What it does |
|---|---|
| enabled | Master switch for the tuning panel. |
| showOnTouch | Show it on phones by default. Off: the DBG button toggles it. |
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
| doorZoneDepthM / exitSpot.* | The threshold box's depth; where a leaving player stands (outM outside the door) and the root height of that spot. |
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
| fovDeg / eyeHeightM / yawDeg / framingMargin / screenOffset | The one camera: 50 degree lens (the spec's 40 put the eye 10.3 m out, in the bay's front-left corner inside the tyre rack), eye 1.5 m, 30 degrees round from the nose toward the right (3/4 front right; 35 crowded the side wall), margin round the body's bounding sphere, and how far right of centre the car sits (0.18 of the width) so the panel does not cover it. The camera turns to put the car there; it does not slide. Distances by rig box: 7.0 m (hatch) to 8.4 m (cruiser), the eye at least 1.9 m off the side wall and 2 m inside the door. Lower fovDeg = longer lens, farther eye. |
| thresholdRangeM / fadeSeconds / noticeSeconds / exitCamera | The doorway is watched within 12 m (on foot the character's root; seated, the car's chassis, see driveIn); the fade is 0.2 s each way; a short notice (the car could not be shown) stays 3 s; on leaving the camera starts 4 m behind and 1.6 m above the character at ExitSpot. |
| spinDegPerSec / dragDegPerPixel / inertiaSeconds / resumeAfterSeconds / maxFlickDegPerSec | Turntable: 8 degrees a second (measured 7.6 in Play), 0.35 degrees per pixel of drag (a 200 px drag turned it 76 degrees, auto-spin included), flick decay over 1 s capped at 360 degrees a second, and 3 s before auto-spin resumes. |
| driveIn.maxKmh / serverSlack / zoneMarginM / outM / clearM / leaveRangeM / blockedText | Driving in (round 2 §3): driving your own car, the chassis's centre crossing DoorZone inward at or below maxKmh (20) opens the view with that car; faster does nothing and the walls stop the car. The server re-checks the replicated speed against maxKmh x serverSlack (1.25) and the chassis within zoneMarginM (3 m) of the zone's box, then parks the car outM (7 m) straight out from the zone's centre, facing out, anchored, prompt off; leaving seats the player back in it there. clearM (3 x 6 m) is the spot's footprint: any other car or player in it refuses the drive-in with blockedText. The parked ride height is the live chassis height over the floor, clamped between half the body's height and the bay's spawn height (half body + spawn.spawnHeightM). A drive-out is refused (walk-in exit instead) unless the character's root is within leaveRangeM (20 m) of DoorZone. Measured in Play 2026-09-28 (kamri07): drive-ins at 9.7 and ~15 km/h opened the view, parked at 7.00 m out, facing out (dot 1.00), 1.01 m chassis ride height kept; one at 74 km/h did nothing. Final pass (same day, after the ride-height clamp): parked chassis 1.007 m over the pad against 1.003 m for the car settled after a normal spawn, tyres on the pad. maxKmh up lets a quicker entry count; outM down parks nearer the door (below ~5.7 a 5 m car's tail reaches ExitSpot). |
| revPresent.turnDeg / easeSeconds / arriveDeg / holdSeconds | The EXHAUST tab's REV: the turntable first eases the car to a rear 3/4, turnDeg (15) off square-on to the camera, with a 0.25 s time constant (measured 1.1 s from 76 degrees away), fires the burst once within arriveDeg (1.5), holds 1.5 s, then spins on; a drag cancels it. At 35 the right-hand flame ran off the screen's right edge; at 15 both tips and flames are on screen, clear of the panel. Up for a more side-on view (longer-looking flames), down for more square-on. |
| previewLampsOn | The preview's headlights (and so its tails) are lit, so the Lights category shows. |
| aimHeightM | Spot lights aim at the turntable centre this high (the car's middle). |
| lights.key / fill / rim / under | The view's four lights: type, positionM, brightness, rangeM, angleDeg, color, sizeM (the fill's face), shadows (the key only; no effect under ShadowMap). The fill is a 3 m softbox 4.6 m over the car, brightness 1.5, angle 120, range 11 m (from a 1.2 m panel on the far side): the Glass finishes take their sheen from it. A white gloss car still does not bloom. Brightness: key 1, fill 1, rim 1.5, under 0.4 (from 3 / 1 / 2.5 / 0.8, because a white car passed the world bloom threshold and glowed). **The owner's feel knob is `lights.key.brightness`**: higher gives a hotter highlight and more bloom on white. Each light is scaled per sky option by 2^(default exposure - option exposure), so at night (+0.4 stops) they run at 0.76. Four lights with the pool suspended keeps the client under maxLiveLights (12). |
| bakedGlow / bakedGlowSkip | The interior's painted-on light per sky option: each panel's LightInfluence becomes 1 - (1 - built) * glow. Sunset 1 (as built), night 0.5. The sign (Fascia) is left alone. |

## CosmeticsConfig.render (how a garage look is drawn, shared)
`src/shared/CosmeticsConfig.luau`, read by `CarCosmetics` (client) and `CarLamps`. Each car's strip and tip spots are in `src/shared/CarCosmeticMounts.luau` (car frame, metres before scale, like `CarPlateMounts`).
| Field | What it does |
|---|---|
| brakeBrighten | A chosen tail colour's brake lamp is that colour this much brighter in HSV value (0.4): Deep Red tails #8A0508 brake at #C1070B (measured in Play). Smoked brakes dim (#670E11); raise this if braking gets lost. |
| stripThicknessM / stripPixelsPerM / stripDrawStuds | The windscreen strip card: 4 mm thick, canvas 400 px per metre, not drawn past 250 studs. |
| tipRadiusM / tipLengthM / boreRadiusM / boreColor / quadPairGapM | Exhaust tips: 0.09 m radius, 0.16 m long, a dark 0.065 m bore at the open end; quad tips are two pairs 0.2 m apart (at least one tip diameter, or they overlap). Before the car's scale (1.2 on every car now). |
| pipeRadiusM / pipeOverlapM / pipeColor | The pipe each tip sits on (0.04 m radius, dark metal), from 3 cm inside the tip forward for the car's `tips.pipeLengthM`, into the body or the car's own muffler, so no tip floats. Thinner than the bore, so it never shows through the mouth. |
| factoryPipeRadiusM / factoryBoreRadiusM / factoryPipeColor | The plain pipe built where a body has no pipe of its own (kamri, pickup, cruiser): 0.032 m radius, 0.022 m bore, running forward the stock outlet's own `pipeLengthM` (kamri 0.35, pickup 0.8, cruiser 0.4; defaults to the tips' run). It goes when tips go on. |
| CarCosmeticMounts windscreen | posM (strip centre), widthM (glass width at its top), heightM (0.12), tiltDeg (top leaned back with the rake). Behind see-through glass the strip sits ~1 cm inside; behind opaque glass it sits just outside (BEHAVIOURS.md). |
| CarCosmeticMounts exhaust | One shape on every car (garage round 2 §1): `stock` (the car's own pipe mouths: posM at the mouth's centre, optional `dir` the way the pipe points, `factory = true` where we build the pipe), `tips` (posM: between a twin pair at the tips' mouth; spreadM: twin tips at ±spreadM/2, a single on stock[1]'s side, quad as two pairs; pipeLengthM: the pipe run forward) and `bumperZ` (the body's rear face just above the tips), plus optional `quadOuterBumperZ` (that face over a quad's outer two tips where the bumper curves forward; krownvik and fleet). Every tip mouth sits 2-5 cm past the face above it (3 cm on every car), and over the car's own pipes where it can. `CarCosmeticMounts.spec` holds every car to it. |
| ExhaustOutlet attachments | `CarCosmetics.outlets(model)`: one Attachment per mouth of the exhaust fitted, at the mouth's centre, its LookVector (the attachment's -Z) out of the pipe. Stock: one per stock outlet. With tips: only the tips (they replace the whole exhaust); an own pipe left showing beside them (the hatch's centre pipes, the other pipe of a twin under a single tip) gets no outlet. The flame contract; switching the exhaust item rebuilds them. |

**Exhaust spots, measured 2026-09-28** (near-orthographic captures from behind, the side and below, calibrated at ~700 px/m; car metres before scale):

| Car | Stock mouth(s) (x, y, z) and what they are | Tips y / mouth z / spread | bumperZ | Parts: stock / single / twin / quad |
|---|---|---|---|---|
| kamri | factory pipe (-0.55, 0.33, 2.47): no pipe on the generated body | 0.30 / 2.48 / 1.1 | 2.45 | 3 / 4 / 7 / 13 |
| hatch | ExhaustL/R (-0.048 and 0.078, 0.444, 2.079), 23° up | 0.30 / 2.065 / 0.8 (either side of its pipes) | 2.035 | 1 / 4 / 7 / 13 |
| pickup | factory pipe (-0.6, 0.415, 2.83) through the bumper, top on the bed floor | 0.415 / 2.84 / 1.2 | 2.81 | 3 / 4 / 7 / 13 |
| cruiser | factory pipe (-0.6, 0.37, 2.84) under the bumper edge | 0.32 / 2.85 / 1.2 | 2.82 | 3 / 4 / 7 / 13 |
| krownvik | twin in Underbody (±0.715, 0.265, 2.655), 8° down | 0.265 / 2.78 / 1.43 (quad outer two at 2.745) | 2.75 (2.715 over the quad's outer tips) | 1 / 4 / 7 / 13 |
| krownvikfleet | twin in Underbody_6 (±0.715, 0.265, 2.665), 8° down | 0.265 / 2.79 / 1.43 (quad outer two at 2.755) | 2.76 (2.725 over the quad's outer tips) | 1 / 4 / 7 / 13 |
| lekzas | chrome tips Chrome_2 (±0.553, 0.325, 2.52), slightly down | 0.30 / 2.62 / 1.106 | 2.59 | 1 / 4 / 7 / 13 |
| kamri07 | slash-cut tips P50 off mufflers P31 (±0.565, 0.337, 2.31) | 0.31 / 2.43 / 1.13 | 2.40 | 1 / 4 / 7 / 13 |
| batrol | single in Trim (-0.666, 0.485, 2.395), 29° out to the left | 0.44 / 2.52 / 1.332 | 2.49 | 1 / 4 / 7 / 13 |
| kruzer80 | single in Chrome_13 (0.60, 0.643, 2.41), a little out and 8° down | 0.62 / 2.47 / 1.2 | 2.44 | 1 / 4 / 7 / 13 |

Parts per car are the `LookExhaust` folder: 1 invisible outlet holder, plus per tip a tip, bore and pipe (3), or per factory pipe a pipe and bore (2). All massless, non-colliding, unqueryable, welded. Outlets per item: stock 1-2 (one per stock outlet); with tips, exactly the tip count (1, 2 or 4) on every car.

**Finishes** (the FINISH items; retuned 2026-09-28 in the lit bay). Under ShadowMap the view's lights give no specular highlight, and Metal and Foil ignore Reflectance on these meshes. A red Lekzas at Metal with Reflectance 0.08, and again at 0.35, was the same flat red as SmoothPlastic. EnvironmentSpecularScale and EnvironmentDiffuseScale changed nothing indoors. Glass is the one material that picks up the view's lights, as a sheen. So the ladder is:

| Finish | Material and reflectance | Colour treatment | How it reads in the bay |
|---|---|---|---|
| factory | the car's own | none | flat |
| matte | SmoothPlastic | `darken` 0.2, `desaturate` 0.3 | dull, clearly flatter than factory (the old 8% darken could not be told from factory on red) |
| gloss | Glass, 0 | none | the colour, with a lit sheen on the bonnet, roof and flanks; gloss black reads as real gloss black |
| metallic | Glass, 0.05 | `darken` 0.25 | sheen over the whole panel: navy turns slate-silver, red turns a lighter pinkish red |
| chrome | Glass, 0.15 | none | pale silver tinted by the paint (0.3 with the colour lightened read as a plain white car) |

- **Rims:** chrome is Glass 0.15 (#B8BCC2) and gold is Glass 0.05 (#B8892E). Gold reads as bright gold with a sheen; chrome reads near white.
- **Round 2 additions** (2026-09-28, lit bay, kamri07 / lekzas / kruzer80 / krownvik / batrol / fleet): Candy Red rims (Glass 0, #A3161C) read as bright gloss red; Champagne (Glass 0.05, #C4AE84) as cream gold. The bay lifts and warms every paint, so the new paints were picked on the car, not the swatch: Najd Clay #6B4636 renders terracotta (#9A4B30 rendered as a second Sodium Orange), Oasis Teal #1E6B68 a bright teal, Gulf Blue #7A9BB5 a pale blue (it replaced a saffron that rendered as a second Sodium), Wadi Olive #474E36 a military olive (#5C5A3C read mustard beside Dune Gold). Decals: Natl (نطل, green on black) and White Strip (HAJWALA, black on white; the most readable strip from the view).
- **The knobs:** each finish item's `material`, `reflectance`, `darken` and `desaturate`. Glass reflectance is very steep: 0.04 already washes a colour.
- **Not reachable under ShadowMap:** a mirror chrome. Red chrome reads salmon.

Paint and finish only show on cars with `paint = true` body pieces. The pickup and cruiser are single textured shells with none, so `CarCosmetics.paintable(carId)` is false for them and the garage panel greys paint and finish out. **Owner follow-up:** split a paintable body piece out of those shells in CarCatalog.
Likewise a car with no windscreen or exhaust spot in `CarCosmeticMounts` would get its DECALS or EXHAUST items greyed out (`CarCosmetics.hasSpot(carId, "windscreen" | "exhaust")`); every catalog car has both today, and `CarCosmeticMounts.spec` fails if a new car ships without them.

**Window tint** (garage round 2 §4, 2026-09-28; the TINT items, a third row under PAINT). Each car lists its glass pieces in `CarCosmeticMounts` `windows`: `side` (door, quarter and rear windows), `screen` (the windscreen alone) and `whole` (one piece that is the windscreen and other windows together: the lekzas, batrol and kamri all-round glass, and the krownvik's windscreen-roof-rear piece). A film puts every listed piece on SmoothPlastic in its `glassColor`, at `glassTransparency` for side, `screenTransparency` for screen and halfway between for whole. Factory puts each piece's colour, material and transparency back exactly (checked on all ten cars: no body part differs after a full look and back to stock).

| Film | side | screen | whole | Read in the lit bay |
|---|---|---|---|---|
| Light | 0.5 | 0.7 | 0.6 | clear, cabin plainly visible; lighter than the kamri07's factory doors (0.2) |
| Dark | 0.3 | 0.62 | 0.46 | smoked sides, cabin still visible through the windscreen |
| Limo | 0.12 | 0.55 | 0.335 | near-black sides with a little depth; windscreen still shows the dash and the strip |

- SmoothPlastic whatever the factory glass was: the krownvik's glass is white Glass at 0.3 and reads clear, and a dark colour on Glass at the same transparency went pitch black, strip and all.
- Absolute, not relative to factory: a film limited to "never clearer than factory" did nothing at all on the kamri07, whose doors are already 0.2.
- The strip stays readable under every film (inside strips on the lekzas, krownvik and fleet were checked at Limo; the lekzas's all-round glass was also checked at 0.2).
- The hatch (opaque black glass mesh), pickup and cruiser (glass painted into the shell) have no `windows`; TINT greys out with "This car's windows can't be tinted yet". `CarCosmeticMounts.spec` fails if any other car ships without windows, or lists a piece its body does not have.
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
| `items[].text` / `textColor` / `stripColor` / `stripColor2` | Decal: the windscreen strip's text and colours; a second strip colour makes it a gradient | |
| `items[].tips` / `tipColor` / `tipMaterial` | Exhaust: how many tips (0, 1, 2 or 4) and their look | |
| `items[].glassColor` / `glassTransparency` / `screenTransparency` | Tint: the film's colour, and the transparency it gives side windows and the windscreen (an all-round piece takes halfway). Light 0.5 / 0.7, Dark 0.3 / 0.62, Limo 0.12 / 0.55 | Down for darker. Keep screen at least 0.5 and above side (window tint table above) |
| `items[].engineVolume` / `crackleChance` | Exhaust: multiplies the engine sound's volume and the chance of pops (1.1 to 1.35, 1.3 to 2.5); crackleChance is also the flame profile's pop multiplier, since every pop is a flame | Down if a tip is too loud; crackle scaling is not yet checked by ear |
| `items[].flameSize` / `flameCore` / `flameColor` | Exhaust: the flame profile. flameSize scales every flame length and size (factory 0.9, single 1.2, twin 1.25, quad 1.4, titanium 1.5); flameCore is the hot core's colour at the mouth (factory #6C8CFF pale blue, sport #3A6BFF, quad #2E62FF, titanium #6A3CFF blue-violet); flameColor the tongue's body (#FF6A1A to #FF8A24) | Keep cores saturated: pale blues read white under bloom |

### `flames` (exhaust flames, `ExhaustFlames`)

One pop is a layered burst at every `ExhaustOutlet` (CarCosmetics), all `Emit`, no Light. Built in Edit and Play on 2026-09-28 by freezing the effect at set ages (BEHAVIOURS, "Freeze a particle effect"), judged from the side, a drift 3/4, the chase cam at 100 km/h, at sunset and night, and on the garage turntable. Lengths are metres before the car's scale, times the item's flameSize.

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
| `trailFullKmh` / `trailGain` | At speed the car-locked layers reach further back: speed times 1 + trailGain x (kmh / trailFullKmh, capped at 1). 160 / 1.2 | Up for longer flames at speed |
| `inheritVelocity` | Sparks and smoke keep this much of the car's velocity when born (0.8), so they fall back rather than drop at the tip | |
| `glowColor` / `glowAmount` / `glowSeconds` | A built tip (or factory pipe) is pulled this far toward this orange at each pop and eases back (0.6 over 0.45 s) | Down if the tips flash too much |
| `soundPool` / `burstSeconds` | Pops heard with relayed and preview flames: a pool of 3 crackle Sounds per car; a multi-pop burst (the garage REV) spreads over 0.5 s like the driver's | |
| `revPops` | The garage REV button: 3-5 pops times the exhaust's crackleChance | |
| `relayPopsPerSecond` / `maxPopsPerBurst` | Server relay (CarControls): the driver's client sends each pop as it plays; the server relays at most 10 pops a second per player, counted in pops, and no message over 8 | Down if relays cost too much; keep at least maxPopsPerBurst |
| `relayMinGapSeconds` | A receiving client drops a relayed pop within 0.04 s of that car's last (a relayed multi-pop burst blocks for burstSeconds) | Only thins a flood |
| `timeScale` | Studio inspection only: particle time for a harness to slow and freeze a pop. Must stay 1 (spec) | |
| `layers.*` | Each layer's texture (built-in `rbxasset://textures/particles/...` only, each checked to load), count, jetSeconds (let out over this long), lifetime, speed, spread, drag, riseMps2, size / transparency / squash keyframes, colours, lightEmission, brightness, locked (rides with the car), alongMotion (VelocityParallel), zOffsetM | Keep Brightness at or near 1 on coloured layers (BEHAVIOURS, "Colour past 1 goes white") |

**The owner's feel knobs for the flames:** the items' `flameSize` (bigger or smaller flames per exhaust), `trailGain` (how far flames reach at speed), `layers.tongue.speed` (flame length at rest), and `crackleShiftChance` / `crackleLimiterPerSecond` (upshift and limiter pops; 0, off, by default per the owner's 2026-09-22 ruling).

**The owner's feel knobs for the garage:** `GarageConfig.lights.key.brightness` (hotter highlight, more bloom on white), `GarageConfig.fovDeg` (longer lens, farther eye; the wall limits it), the finish items' `material` / `reflectance` / `darken` / `desaturate` (the finish ladder above), and `GarageConfig.bakedGlow` (how much painted-on light the interior keeps per sky option).
