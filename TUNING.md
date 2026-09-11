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
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| grip | Peak friction. Rear lower than front = oversteer. | rear ↓ / front ↑ | rear ↓ | — |
| peakSlipDeg | Slip angle at peak. Lower rear = rear breaks away sooner. The rear is set later than the front so the front reaches its limit first. Moving it also moves that axle's stiffness, so change riseShape with it (see below). | rear ↓ | rear ↓ | — |
| riseShape | How the tire builds grip up to the peak. 1 is a straight line whose slope is 1/peakSlipDeg, so raising the peak on its own quietly softens the axle everywhere below it and the rear starts stepping out under power at cruise. Below 1 the curve is concave: full bite near zero slip, rounding over into the peak. Lower it to firm an axle up without moving where it lets go. | rear ↑ | rear ↑ | — |
| slideSlipDeg | Where the fade ends. Wider gap to peak = gentler fade = more progressive slide. | rear ↓ | rear ↓ | — |
| falloffShape | How the tire gives up grip past the peak. 1 is a straight line to the floor. Above 1 the first degrees past peak cost almost nothing and the loss steepens further out, which is the warning before the rear goes. Lower it toward 1 if you want the limit to arrive without notice. | rear ↓ | rear ↓ | — |
| slideGripRatio | Grip floor while sliding. Lower rear = bigger angles, harder to catch; higher = holds and recovers easier. Also sets how hard a handbrake pull or clutch kick can rotate the car, since a saturated tire sits at this value. | rear ↓ | rear ↓ | — |
| speedFadeMps | Speed below which lateral force fades. Only for parking jitter. | — | — | — |

## drivetrain
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| torqueCurve | Engine torque by rpm. More torque = more power-over. | ↑ | ↑ | — |
| gearRatios / finalDrive | Shorter (bigger numbers) = more drive force at speed = easier to break traction with throttle. | ↑ | ↑ | — |
| reverseRatio | Reverse gearing. | — | — | — |
| drivelineEfficiency | Scales all drive force. | ↑ | ↑ | — |
| idleRpm / redlineRpm | Rev range. | — | — | — |
| upshiftRpm / downshiftRpm | Shift points. Later upshift keeps the engine in the fat part of the curve for kicks. | — | ↑ upshift | — |
| shiftTime | Torque cut per shift. | — | — | — |
| spinRpmRate | How fast rpm climbs while spinning. Cosmetic. | — | — | — |
| engineBrakeTorque | Weight shift forward on lift. More = sharper lift-off rotation and easier transitions. Raised from 40 to 90 because 40 was too little to feel at the wheelbase and mass of this car. | ↑ | ↑ | — |
| brakeForce / brakeBias | Pedal strength and split. More rear bias = brake-induced rotation. | bias ↓ | bias ↓ | — |
| brakeFadeMps | Anti-jitter at rest. | — | — | — |
| reverseEngageMps | Below this speed, brake with no throttle selects reverse; throttle leaves it. | — | — | — |

## steering
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| maxSteerDeg | Lock. Must exceed the drift angles you want to hold minus assist. | ↑ | ↑ | — |
| steerSpeedDegPerSec | How fast the wheels turn in. Higher = snappier initiation, twitchier hold. | — | ↑ | — |
| steerReturnDegPerSec | How fast they return. | — | — | — |
| driftAssist | Automatic counter-steer fraction. Higher = easier hold, less skill. Keep low. Off on two wheels. | ↓ | — | — |
| speedLockCurve | Speed-sensitive lock, km/h to fraction of maxSteerDeg. Full lock for parking, tapering at highway speed so turning alone cannot pitch the car sideways. Raise the high-speed end if the car feels unresponsive at speed, lower it if a flick still breaks the rear loose. | ↑ high end | ↑ high end | — |
| counterSteerReliefDeg | Slip angle at which the taper is fully lifted, so a correction always gets the whole wheel. Lower = the full wheel comes back sooner in a slide. | — | — | — |
| counterSteerRelief | How much of the taper a correction lifts. 1 gives the whole wheel back, 0 disables the exception and the taper applies to counter-steer too, which makes big angles uncatchable at speed. | — | — | — |

## handbrake
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| rearGripMultiplier | Rear grip while pulled. Lower = snaps out faster. This is the knob that pays for a softer rear falloff: the gentler the falloff, the deeper this has to cut to initiate in the same time. | ↓ | ↓ | — |
| brakeForce | Rear drag while pulled. Too high scrubs speed. | — | ↑ | — |
| releaseSeconds | How long the grip takes to come back after the lever is let go. 0 snaps it back in one step, which jolts the car straight; longer hands the slide off to the throttle more gently. | ↑ | — | — |

## clutchKick
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| multiplier | Torque spike. Only bites while the rear is still inside its friction circle. Past that the tire is clamped to its sliding value and raising this does nothing at all, which is why it is not the knob for a kick that stopped working. | ↑ | ↑ | — |
| rearGripMultiplier | Rear grip during the kick window. This is what actually breaks the rear loose, the same mechanism as the handbrake. Reach for this one when kicks stop initiating. | ↓ | ↓ | — |
| duration | Spike length, and how long the grip cut lasts. | — | ↑ | — |

## twoWheel
| Field | What it does | OS | INIT | 2W |
|---|---|---|---|---|
| liftTorque | Roll torque while lifting. 12000 reaches the target in about a second at 70 km/h. | — | — | ↓ (gentler arrival) |
| gravityCancel | Fraction of gravity's restoring torque cancelled while balanced. 1 = neutral pendulum. | — | — | ↓ |
| targetRollDeg | Angle where lifting hands over to balancing. Keep below atan(tire grip) ≈ 45° or the base slides out. | — | — | ↓ |
| leanTorque | Constant outward push while balanced. Below ~600 Nm the car's own front-heavy yaw wins and it settles back onto four wheels if ignored (Phase 0 choice); above, it tips. | — | — | ↓ |
| instability | Extra outward push per degree above targetRollDeg. | — | — | ↓ |
| rollDamping | Resists roll rate while balanced. Kills the lift-in overshoot. | — | — | ↑ |
| leanInTorque | Lean toward the lifted side (the key you are holding). Divide by rollDamping for roughly the degrees per second you climb while holding it. Too high and holding the key flips the car before you can catch it. | — | — | ↓ |
| leanOutTorque | Lean toward the grounded side (the opposite key). Same rule of thumb for how fast it comes back down. This is the catch, so it wants to be several times leanInTorque. | — | — | ↑ |
| tipRollDeg | Where the controller lets go. Set past the static tip (≈56°) so a tip is a real fall. | — | — | ↑ |
| rimGripStartDeg / rimGripBoost | Roll where rim dig-in starts and how much grip it adds. Without it the base slides out at ~45° and a tip is impossible. | — | — | ↓ boost |
| landingDamping | Softens the drop back to four wheels. | — | — | ↑ |
| suspensionBias | Loaded-side spring multiplier while lifted. | — | — | ↑ |
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
| touchSteerRampPerSec / touchSteerReturnPerSec | Same for touch buttons, slower. |
| touchSteerCurve | Exponent on the ramped touch steer. Above 1 = finer control near centre. |
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

## debug
| Field | What it does |
|---|---|
| enabled | Show the panel. |
| updateHz | Panel refresh rate. |
