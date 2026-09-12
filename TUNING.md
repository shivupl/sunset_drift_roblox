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
| longitudinalGrip | Drive grip as a multiple of the lateral peak: the friction circle becomes an ellipse. Above 1 the axle puts more throttle down before it spins and nothing sideways changes, so every drift number is untouched. Rear 1.55 with the TC floor at 0.7: 0-30 in 1.05 s, 0-70 in 2.65, 0-100 in 3.9 (1.4 / 0.6 was 3.0 and 4.35; the original round circle was 3.8 to 60 and 6.3 to 100). Power-over under full lock at 40-60 km/h still peaks at 1-3 degrees. Front stays 1. | — | — | — |
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
| laneCount | Lanes per carriageway (6 now, on request; 4.7 m each in a 64 m corridor). Dividers are laneCount-1, and tyre tracks are two per lane, so this drives part count as well as looks. |
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

There are no barriers at the road. Running wide costs speed and dignity, not
the run; the edge of the world is the berm, 170 m out on the driving side and
200 m on the sunset side, and it is part of the terrain (see `relief.berm`).

## relief
The near desert and the berm, as one terrain surface either side of the road.
Everything in metres from the road centreline.

| Field | What it does |
|---|---|
| innerGapM / featherM | Where the strip starts past the asphalt, and how far both its edges blend down under the plane so it has no rim. |
| liftM / shellM | Floor height above the plane (so the plane never shows through) and how thick the solid sand shell is. Thicker costs terrain cells for something nobody sees. |
| swellWavelengthM / swellAmplitudeM / rippleWavelengthM / rippleAmplitudeM | Two octaves of undulation over the whole strip, berm included. math.noise spans about -0.5..0.5, so amplitude is twice the swing. |
| hummocks.* | Small mounds per km per side on the floor only, radius and height range, and the chance of a scrub tuft on top. |
| gravel.* | A second terrain material where a slow noise is above threshold. |
| sandColor / gravelColor | Terrain tints. One step darker than `ground.color` because terrain renders brighter for the same tint. |
| chunkStuds | Voxel write chunk. 128 is 32 columns; bigger chunks mean fewer, larger writes. |

### relief.berm
The hill the car drives up, out of the same height function as the floor.

| Field | What it does |
|---|---|
| endM | Where the berm stops along the road; the start-line end is open. |
| wallHeightM / wallRunCapM | The invisible stop standing on the crest, and how long each piece of it is (keep under 573 m). A car off the crest at 200 km/h carries 150 m of climb, so keep it tall. |
| wanderWavelengthM / footJitterM / heightVariation | How far and how fast the foot and the crest height wander along the road. This is what makes the crest a dune line instead of a ramp; zero them and you get an extrusion. |
| sun.* / other.* | Per-side profile: footM, riseWidthM, crestHeightM, backWidthM. **Steepest slope is 1.5 x crestHeightM / riseWidthM** — that one number decides whether the car climbs it or bounces off. Lower and farther on the sun side keeps the sunset and the far dunes in view. |

## lamps
| Field | What it does |
|---|---|
| spacingM | Distance between lamps. Drives both the rhythm of light and the part count. |
| bothSides | False alternates the outer sides and halves that part count. |
| medianLamps / medianSpacingM | Double-arm posts down the reservation at their own spacing (22 m, twice the outer density), offset half a spacing so the rows interleave. |
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
| rings | One far ring of tall blocks and towers at 2.7 km, the separate skyline seen from a distance. Each entry is { distanceM, depthM, count, size and height ranges, towerChance }; keep the minimum height up or a ring reads as scattered small buildings, which is why the old near ring of low blocks is gone. Anything inside the city grid is skipped. |
| downtown | A dense cluster of slim towers in a sector sectorOffsetDeg round from the road's direction of travel (0 = straight ahead, behind the city grid): half-angle, distance range, count, size and height ranges, plus one wide dim Neon slab along its base (the sodium haze). Anything that would land inside the city grid is skipped. |
| landmarks | Kingdom-Centre style (slab, two pillars, sky bridge: the arch) and Faisaliah style (four corner wedges as a pyramid, a globe near the tip), both in the downtown sector. Height, footprint, angle offset and distance each. |
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
| scrub.* | Low bushes on the verges and, at `medianChance`, between the median palms. |
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
| originM / blocksX / blocksZ / blockM | Where the north-west roundabout sits (world metres) and how many 420 m blocks the grid grows east and south. With the highway on x = 0 ending at 2,000 m, origin (-840, -2022) and four blocks wide puts the central boulevard on the highway axis. |
| gateway.i / gateway.widthM | Which first-row boulevard the highway feeds and the width of that square, so the whole road lands on asphalt. |
| boulevard.widthM / medianWidthM / laneCount / parkingLaneM | The cross-section: 44 m kerb to kerb, an 8 m palm median, three lanes and a parking lane each way. |
| sideStreet.widthM | 16 m, one lane each way plus parking. |
| roundabout.islandRadiusM / islandHeightM / palmsOnIsland | Every boulevard crossing. The island is the one raised thing in the city that collides. |
| ramp.offRamp / onRamp / widthM | Waypoint lists { x, z, width } in world metres; empty now that the highway ends in the grid. For a side entry, start them just outside the highway kerb (35.4 m from the centreline) as a narrow taper. |
| surface.* | Slab thickness, run cap (streaming), colours, tone jitter, kerb dust, marking sizes, tyre tracks, pavement width. |
| districts | One row per block row, one entry per block: commercial, towers, plaza, residential, lot. |
| buildings.palette / accentPalette / accentChance / tone | Sand, cream and warm grey, the odd colour, per-part jitter. |
| buildings.commercial.* | Shop row sizes, storeys, gap chance, setback, awning, fascia colours, sign chance. |
| buildings.residential.* | Lot size, wall height, gate, villa size and storeys, tier and dish chance. |
| buildings.towers.* | Podium size and storeys, tower storeys and width, glass and frame colours, setback chance, crown colour. |
| buildings.plaza.* | Bay geometry for the few painted rows. |
| furniture.* | Palm, lamp, bin, bench, parked-car and signal densities. A parked car is five parts; parkedCarChance is the first thing to cut on a slow phone. |
| shadows.* | Which city things cast: buildings and palms yes, compound walls, lamps and furniture no. |

## technology / fogEnabled / debug
| Field | What it does |
|---|---|
| technology | The intended `Lighting.Technology`. A script can neither write nor read it, so this is a record and a reminder; set it by hand. `ShadowMap` is what the shadows are tuned for, `Voxel` is the mobile fallback and makes them blobby. |
| fogEnabled | Legacy distance fog. Off: Atmosphere does the fade, and fog thick enough to sell distance hides the road edge. |
| debug.report | Prints the per-system part and triangle report at build. |
