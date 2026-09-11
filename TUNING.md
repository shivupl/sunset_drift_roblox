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
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| massKg | Total mass. More mass = more momentum in a slide, slower transitions. | — | ↓ | — |
| bodySize | Box dimensions. Height changes roll inertia. | — | — | — |
| centerOfMassOffset | Lower CoM = less roll, higher tip angle. Forward CoM = more front load = more rear slide, and more natural yaw toward the grounded side on two wheels. | forward ↑ | forward ↑ | lower (more negative Y) ↑ |
| wheelbase | Longer = more stable, slower rotation. | ↓ | ↓ | — |
| trackWidth | Wider = higher two-wheel tip angle, less roll. | — | — | ↑ |
| wheelRadius | Bigger = taller gearing, less drive force. | — | ↓ | — |
| shellMassFraction | Share of mass in the shell vs ballast. Only affects where the ballast sits. | — | — | — |
| dragCoefficient / frontalArea / airDensity | Top speed and how fast a slide bleeds speed. | — | — | — |
| rollingResistance | Coast-down drag. | — | — | — |

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
the throw impulse and the lever's grip cut, not by softening the rear.

| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| grip | Peak friction. Rear lower than front = oversteer. | rear ↓ / front ↑ | rear ↓ | — |
| peakSlipDeg | Slip angle at peak. Lower rear = rear breaks away sooner. The rear is set later than the front so the front reaches its limit first. Moving it also moves that axle's stiffness, so change riseShape with it (see below). | rear ↓ | rear ↓ | — |
| riseShape | How the tire builds grip up to the peak. 1 is a straight line whose slope is 1/peakSlipDeg, so raising the peak on its own quietly softens the axle everywhere below it and the rear starts stepping out under power at cruise. Below 1 the curve is concave: full bite near zero slip, rounding over into the peak. Lower it to firm an axle up without moving where it lets go. | rear ↑ | rear ↑ | — |
| slideSlipDeg | Where the fade ends. Wider gap to peak = gentler fade = more progressive slide. | rear ↓ | rear ↓ | — |
| falloffShape | How the tire gives up grip past the peak. 1 is a straight line to the floor. Above 1 the first degrees past peak cost almost nothing and the loss steepens further out, which is the warning before the rear goes. Lower it toward 1 if you want the limit to arrive without notice. | rear ↓ | rear ↓ | — |
| slideGripRatio | Grip floor while sliding. Lower rear = bigger angles, harder to catch; higher = holds and recovers easier. Also sets how hard a handbrake pull can rotate the car, since a saturated tire sits at this value. | rear ↓ | rear ↓ | — |
| deepSlideSlipDeg / deepSlideGripRatio | Past deepSlideSlipDeg the floor eases toward the deep ratio by 90° of slip. This is the 360 (Ta'geed) knob and it never touches the 10 to 35° region a held drift lives in. Rear deep ratio low = the car keeps rotating and carries speed through a spin. Front deep ratio should stay high: the fronts drive the rotation in a throw, and easing them slows the spin. Measured at 160 km/h: no 360 in 4 s with the deep ratio equal to the first floor, 3.4 s with rear 0.45. | rear ↓ | — | — |
| speedFadeMps | Speed below which lateral force fades. Only for parking jitter. | — | — | — |

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
| shiftTime | Torque cut per shift. | — | — | — |
| spinRpmRate | How fast rpm climbs while spinning. Cosmetic. | — | — | — |
| engineBrakeTorque | Weight shift forward on lift. More = sharper lift-off rotation and easier transitions. Raised from 40 to 90 because 40 was too little to feel at the wheelbase and mass of this car. | ↑ | ↑ | — |
| brakeForce / brakeBias | Pedal strength and split. More rear bias = brake-induced rotation. | bias ↓ | bias ↓ | — |
| brakeFadeMps | Anti-jitter at rest. | — | — | — |
| reverseEngageMps | Speed under which the car counts as stopped for selecting reverse. | — | — | — |
| topSpeedKmh / topSpeedFadeKmh | The ceiling, as a limiter: drive fades to nothing over the last fade band so the car sits at the top instead of hitting a wall. 210 because the 400 m curve is at the grip limit at 220 and the straight takes 34 s. Raise for a faster map, lower for a tighter one. |
| tractionControlBelowKmh / tractionControlMaxDriftDeg / tractionControlMin / tractionControlCutRate / tractionControlRecoverRate | Traction control, a loop that winds throttle down while the rear spins and back up while it grips. Active under the speed and only while the drift angle is under the max and the lever is out, so it never touches a slide. Measured: 0-100 went 7.3 s (fixed cap) to 6.3 s (loop through the midrange). The grip ceiling for this mass is about 5.3 s; past that you need more rear grip or less car. |
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
| throwYawImpulse / throwImpulseSeconds / flickImpulseScale | Yaw kick at the start of a pull or flick, in the direction of the wheel. This is the initiation-speed knob: 6,500 for 0.22 s gives 20 degrees in 0.43 s from 95 km/h. 15,000 gave 0.29 s and a car that spun every time it was let go, which is the "on ice" feel. Flicks get the scale on top. | — | ↑ | — |
| slideYawDamping / throwYawDampingFraction | Yaw damping, Nm per deg/s. A slip-angle tyre model has no yaw stiffness once both axles slide, so a released slide kept rotating at 110 deg/s to 180 with full counter-steer on. This stands in for the rear's self-aligning. Full value when the driver is not throwing; the fraction of it under the lever or in a flick. Raise slideYawDamping for a car that settles faster after a slide; raise the fraction and a held Ta'geed slows down. | ↓ | ↓ | — |
| driftAssistHandsOff / driftAssistHandsOffBelow | When the wheel is centred (|steer| under the threshold) and the lever is out, the assist rises to this and does not fade with angle: lift and straighten means "bring it back". Hands on, the driver's authority is untouched. | — | — | — |

## handbrake
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| rearGripMultiplier (0.45) | Rear grip while pulled. Lower = snaps out faster. This is the knob that pays for a softer rear falloff: the gentler the falloff, the deeper this has to cut to initiate in the same time. | ↓ | ↓ | — |
| brakeForce | Rear drag while pulled. Too high scrubs speed. | — | ↑ | — |
| releaseSeconds | How long the grip takes to come back after the lever is let go. 0 snaps it back in one step, which jolts the car straight; longer hands the slide off to the throttle more gently. Note a tapped handbrake never completes a 360 at any value (the rears roll again once the car is backwards and their grip stops the rotation); hold it through the spin. | ↑ | — | — |

## twoWheel
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| liftTorque | Roll torque while lifting. 12000 reaches the target in about a second at 70 km/h. | — | — | ↓ (gentler arrival) |
| gravityCancel | Fraction of gravity's restoring torque cancelled while balanced. 1 = neutral pendulum. | — | — | ↓ |
| targetRollDeg | Angle where lifting hands over to balancing. Keep below atan(tire grip) ≈ 45° or the base slides out. | — | — | ↓ |
| leanTorque | Constant outward push while balanced. Keep it small: throttle already pushes the car outward (only the grounded rear drives, so gas yaws the car away from the low side). At 400 the car leaned in at 12°/s under 0.4 throttle and a tap was erased in half a second; at 150 it wobbles slowly (from 40° up to 50° and back to 28° over 2 s with no input) and three E taps hold it at 40°. | — | — | ↓ |
| instability | Extra outward push per degree above targetRollDeg. | — | — | ↓ |
| rollDamping | Resists roll rate while balanced. Kills the lift-in overshoot. | — | — | ↑ |
| leanInTorque | Gain of a fresh press toward the lifted side. With the tap envelope it lands all at once and decays, so this sets how much one tap climbs. | — | — | ↓ |
| leanOutTorque | Gain of a fresh press toward the grounded side. This is the catch. It competes with throttle, which yaws the car away from the low side (only the grounded rear drives) and holds it up; measured, a 1.5 s hold-out at 4000 brings the car from 45° to 8°. | — | — | ↑ |
| tipRollDeg | Where the controller lets go. Set past the static tip (≈56°) so a tip is a real fall. | — | — | ↑ |
| rimGripStartDeg / rimGripBoost | Roll where rim dig-in starts and how much grip it adds. Without it the base slides out at ~45° and a tip is impossible. | — | — | ↓ boost |
| landingDamping | Softens the drop back to four wheels. | — | — | ↑ |
| suspensionBias | Loaded-side spring multiplier while lifted. | — | — | ↑ |
| minLiftSpeedKmh / fullLiftSpeedKmh | Nothing lifts below the first; lift torque scales up to full at the second. Real sidewall skiing starts at speed, off a ramp or a sharp turn, not from a standstill. | — | — | ↑ min (harder to start) |
| holdFadeSpeedKmh | The balance controller's authority fades to nothing at this speed, so a car that has slowed to a crawl settles back onto four wheels by itself. You cannot balance a car that is barely moving. | — | — | ↓ |
| leanHoldDecaySeconds / leanHoldFloor | Tap envelope. A fresh press lands the whole lean gain at once, then decays to the floor over the decay time while held. Stabilise by tapping against the lean; a long hold is a weak steady push. Floor 1 turns taps back into levers. | — | — | ↑ floor |
| steerScale | Steering lock while lifted. Steering is the strongest balance lever on two wheels (toward the low side drops the car, away lifts it) and at full lock a short tap flips it. Measured at 80 km/h with 0.22 and steerAwayScale 0.5: a 0.5 tap toward drops 10°, the same tap away leans 20° and is still catchable, a full-lock tap away tips. Raise for a twitchier, more expert car. | — | — | ↓ |
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
| bayLengthM | Parking bay behind the start line. |
| groundTileM | Sand ground tile size; the plane covers the straight, the curve and 500 m of run-off. |

## spawn
| Field | What it does |
|---|---|
| spawnHeightM | Cars spawn this far above rest and settle on their springs. |
| slotStartM / slotSpacingM | Bay slot layout, one per player. |
| settleSpeedMps / settleSeconds | A driverless car below this speed for this long is anchored. |
| fallBelowM | A car this far under the road is re-parked in its bay (self-healing). A destroyed chassis respawns the car. |

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
| screechSoundId / screechMaxVolume | Looped tire screech, volume and pitch follow rear slip. Empty id = silent. Paste an asset id you own. |
| engineSoundId / engineMaxVolume / engineMinPitch / engineMaxPitch | Looped engine sample, playback speed from idle pitch at idle to max pitch at redline, volume with throttle. Empty id = silent. |

## scoring
A slide opens when the drift angle passes minAngleDeg while above minSpeedKmh, and accrues
`pointsPerSecond x (angle / referenceAngleDeg) x (speed / referenceSpeedKmh) x multiplier`
every second. Going straight for graceSeconds banks it. There is no separate bonus for a 360:
at high angles the angle factor is already at its ceiling, so a Ta'geed pays the top rate for
as long as it takes to come round.

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
| spinSlipDeg / spinResetDeg | The SPINS counter accumulates yaw while the drift angle is above spinSlipDeg and clears once it is back under spinResetDeg. Display only. |

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
| laneCount | Lanes across the road. Dividers are laneCount-1, and tyre tracks are two per lane, so this drives part count as well as looks. |
| shoulderWidthM / kerbWidthM / kerbHeightM | The strip outside the paint, and the lip beyond it. |
| asphaltColor / padColor / shoulderColor / kerbColor / paintColor / bayColor | Surface tones. |

### road.wear
Surface realism. None of it is geometry the car can feel.
| Field | What it does |
|---|---|
| slabTone | Per-slab colour jitter. 0 gives one flat colour over 2 km, which is the thing that reads as a prop. |
| tyreTracksEnabled / tyreTrackWidthM / tyreTrackGapM / tyreTrackDarken | Polished strips where wheels actually run, two per lane. Darken too far and they read as paint. |
| seamsEnabled / seamWidthM / seamDarken | A darker line across the road at each slab joint. |
| patchesEnabled / patchSpacingM / patchChance / patchMinLengthM / patchMaxLengthM / patchTone | Repair patches in a different shade. |
| markingWear | How far each dash's colour is pulled toward the road. 0 is crisp white, which no real road has. |
| markingFadeMax | Most transparent a worn dash gets. |

## ground
| Field | What it does |
|---|---|
| tileM / marginM | Sand tile size and how far the desert reaches past the road. **tileM must stay under 573 m**: a Part axis caps at 2,048 studs and a bigger tile silently shrinks and leaves holes. |
| dunes.* | Low wedge ridges beyond the shoulder band: spacing, edge distances, size range. Non-collidable. |
| thicknessM / dropM | Slab thickness and how far the sand sits below the road. |
| nearColor / farColor / farStartM | Two tones split by distance from the road, so the desert is not one colour sheet. |

## road (dual carriageway)
| Field | What it does |
|---|---|
| medianWidthM | Width of the central reservation, taken out of the preset's total. Wider = more room for palms and a bigger gap to cross when you run wide on the inside. |
| medianColor / medianMaterial / medianDropM | The strip between carriageways. It is ground, so it collides. |
| kerbWidthM / kerbHeightM | A visual lip only; collision is off. |

There are no barriers. Running wide costs speed and dignity, not the run.

## lamps
| Field | What it does |
|---|---|
| spacingM | Distance between lamps. Drives both the rhythm of light and the part count. |
| bothSides | False alternates the outer sides and halves that part count. |
| medianLamps | Double-arm posts down the reservation, offset half a spacing so the three rows interleave. |
| setbackM | From the kerb to the pole. Nothing here collides, so this is purely where it looks right. |
| poleHeightM / poleWidthM | Pole size. Square section on purpose: a box is 12 triangles, a cylinder ~100. |
| armLengthM | Boom reach. It has to clear the shoulder and kerb before it is over any asphalt; shorter and every pool of light lands on the shoulder. |
| headSizeM / poleColor / bulbColor / headOffColor | Housing size and colours. `headOffColor` is used at hours where lamps are not lit, so a bulb never glows in daylight. |
| jitterSeed / yawJitterDeg / heightJitter | Per-lamp variation. Zero makes a row read as a copied object. |
| lightColor | Colour of the pooled PointLights. |
| maxLiveLights | **Hard cap on Light instances in the whole client.** The pool is this size, so the cap cannot be violated. Raising it past about 16 is where Roblox starts to hurt. |
| lightUpdateInterval | How often the client re-picks which lamps are lit. Lower = tighter following, more CPU. Never per frame. |

## timeOfDay / timesOfDay
`timeOfDay` picks one of `dusk`, `goldenHour`, `blueHour`, `night`. Each preset:
| Field | What it does |
|---|---|
| clockTime | Sun height. At latitude 60: 17.4 = 7° up, 17.55 = 5°, 17.75 = 3°, 17.88 = 1.5°. Lower = longer shadows and a darker sky. |
| geographicLatitude | **This is the sun azimuth control**, because Roblox has no other. 24.7 (real Riyadh) puts the evening sun 90° off the road, out of the driving view; 60 puts it 127°, ahead-left, in the windscreen with shadows diagonal across the asphalt. 80 is 147°, nearly dead ahead. |
| ambient / outdoorAmbient | Fill light. This is the readability knob: too low and the car disappears between lamps. |
| brightness | Sun strength. |
| exposureCompensation | Overall exposure. |
| colorShiftTop / colorShiftBottom | Tint on lit and unlit faces. What stops asphalt reading as grey plastic. |
| globalShadows | Master shadow switch for the hour. |
| atmosphere.density | Distance fade. The biggest "sells distance" knob, and the biggest risk: too high and the road edge vanishes, which is worse than the mood is good. |
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

## shadows
Per-type switch. Shadow cost scales with the **number** of casters, not size.
| Field | What it does |
|---|---|
| lamps / signage / palms | On. Sparse, tall, and their long raking shadows across the road are most of the realism. |
| rocks / cityscape | Off. Too small and too far to pay for themselves. |

## signage
| Field | What it does |
|---|---|
| gantrySpacingM / gantryFirstM | How often an overhead gantry appears. |
| gantryHeightM / gantryPostWidthM / gantryBeamDepthM | Structure size. |
| panelWidthM / panelHeightM / panelColor / postColor / textColor | Sign face. |
| gantryTexts | `{ arabic, english, shield }` rows. **Placeholders** — replace with real Riyadh route names. |
| roadsideEnabled / roadsideSpacingM / roadsideWidthM / roadsideHeightM / roadsidePostHeightM | Small signs between gantries. |

## cityscape
| Field | What it does |
|---|---|
| seed | Fixed, so every server draws the same city. |
| distanceM / bandDepthM | Radius to the near edge of the ring and how far back buildings scatter. It is a ring, not a band: bands parallel to the road are invisible from the road. |
| count | Buildings. |
| minWidthM / maxWidthM / minHeightM / maxHeightM | The ordinary blocks. |
| towerChance / towerMinHeightM / towerMaxHeightM | Occasional slim towers. Uniform heights read as a bar chart. |
| color / colorVariation | A warm mid tone; the haze tints it to the hour. A near-black silhouette stays near-black at golden hour, which is the wrong read. |
| windowBandsMin / windowBandsMax / windowColor / windowHeightM / windowInsetM | Emissive floor bands, cheaper than a texture and needing no asset. |
| beaconChance / beaconColor | Red aircraft warning lights. |

## scatter
| Field | What it does |
|---|---|
| seed | Fixed, so the desert is identical on every server. |
| useMeshes | Real meshes from AssetRegistry. Off, or a mesh that fails to load, gives the primitive stand-in. |
| palm.medianEnabled / medianClumpSpacingM / medianJitterM / medianMarginM | The signature planting down the reservation: a clump every spacing, jittered along and across, never inside the margin of a kerb. |
| palm.varietyFraction | Fraction of palms that use the second mesh. |
| palm.minScale / maxScale | Height range. Uniform height is the thing that reads as copied. |
| scrub.* | Low bushes on the verges and, at `medianChance`, between the median palms. |
| falloffStartM / falloffEndM | Density falls off with distance from the road, so the near shoulder reads as maintained and the far desert as empty. |
| palm.clumpSpacingM / clumpJitterM / minPerClump / maxPerClump / spreadM | Palms go in loose clumps. Evenly spaced trees read as generated; clumps read as planted. |
| palm.minEdgeM / maxEdgeM | Band either side of the road they can occupy, measured from the kerb. |
| palm.trunkHeightM / trunkWidthM / frondCount / frondLengthM / frondWidthM | The primitive stand-in's proportions, used until a mesh is approved. |
| palm.leanMaxRad | Palms lean. A vertical pole reads as a lamp post. |
| rock.* / debris.* | Same spacing, jitter and edge-distance rules at lower density. |

## streaming
| Field | What it does |
|---|---|
| enabled | Records intent. `Workspace.StreamingEnabled` is a place setting; a runtime script cannot write it. |
| targetRadius / minRadius | Also place settings, and not exposed to Lua at all — set them in the Studio Properties panel. |
| roadPersistent | Keeps the road replicated always. **Leave this on.** The client owns vehicle physics, so a car that outruns the streamer finds no road under it and falls out of the world. |
| palmsPersistent | Keeps every palm replicated. Off, the median is bare ahead of the car at speed because the streamer cannot keep up. ~650 mesh pieces. |
| cityscapePersistent | Stops the horizon popping. ~300 small boxes. |

## technology / fogEnabled / debug
| Field | What it does |
|---|---|
| technology | The intended `Lighting.Technology`. A script can neither write nor read it, so this is a record and a reminder; set it by hand. `ShadowMap` is what the shadows are tuned for, `Voxel` is the mobile fallback and makes them blobby. |
| fogEnabled | Legacy distance fog. Off: Atmosphere does the fade, and fog thick enough to sell distance hides the road edge. |
| debug.report | Prints the per-system part and triangle report at build. |
