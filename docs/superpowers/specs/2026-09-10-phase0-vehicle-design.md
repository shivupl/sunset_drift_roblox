# Phase 0 Vehicle Design — Hajwala

Date: 2026-09-10
Status: approved in brainstorming, pending written review
Scope: Phase 0 only. One car, one flat test road, drift + two-wheel physics,
touch controls, debug panel. No UI beyond debug, no scoring, no economy.

## 1. Goal and acceptance

Build one rear-wheel-drive ~1600 kg sedan whose driving matches real hajwala
clips: initiate a slide on demand from highway speed, hold 60–90° for 10 s+
on a straight with small corrections, transition left to right with a lift
and flick, spin honestly on too much throttle, straighten on too little, and
hold a two-wheel ("natl") stance with active balance input.

Acceptance test: the owner drives on a phone for 20 minutes and can initiate,
hold, and transition a slide at highway speed without thinking about controls.

## 2. Decisions made

| Decision | Choice | Why |
|---|---|---|
| Toolchain | Rokit pins Rojo; git repo; Rojo Studio plugin installed by owner | Reproducible, no global installs |
| Car visual | Placeholder box sedan built from code | Zero collision surprises, whole car lives in repo |
| Spawn flow | Server parks one car per player at road start; player walks to the VehicleSeat | Proves seat/ownership handoff explicitly |
| Suspension | Raycast per corner, one rigid body, wheels visual only | Full control of grip curve; weight transfer from four independent spring loads; cheap on mobile; two-wheel falls out naturally |
| Tire model | Custom slip-angle curve with friction circle | Roblox friction is near on/off; peaked curve is what makes drift controllable |
| Gravity | workspace.Gravity stays 196.2. Sim uses CarConfig.gravity (9.81 m/s²) and applies an upward counter-force of mass × (196.2 − g/metersPerStud) | Keeps the correction local to the car; global gravity change would break characters and every future on-foot system |
| Units | Config in SI (kg, m, N, Nm, m/s). 1 stud = 0.28 m. Mass in Roblox units equals kg | Real-world tuning numbers; convert once at the boundary |
| Force application | Sim sums forces and torques about centre of mass, writes one VectorForce (ApplyAtCenterOfMass) and one Torque on the chassis | Every "where the force acts" decision is explicit in code |
| Debug panel order | Built right after tire model, before input | Tuning needs numbers before it needs feel |

## 3. Repo layout

```
default.project.json
rokit.toml
README.md            rojo serve, plugin connect, how to play test
DESIGN.md            suspension and tire choices in plain language
TUNING.md            every CarConfig field, what it does, which way to move it
src/shared/CarConfig.luau        all tunables
src/shared/Types.luau            shared types (InputState, WheelState, VehicleState)
src/shared/Curve.luau            piecewise-linear lookup for tables
src/shared/Units.luau            metersPerStud conversions
src/shared/VehicleSim/init.luau  step(car, config, input, dt) -> writes forces
src/shared/VehicleSim/Suspension.luau
src/shared/VehicleSim/Tire.luau
src/shared/VehicleSim/Drivetrain.luau
src/shared/VehicleSim/TwoWheel.luau
src/server/init.server.luau
src/server/CarBuilder.luau       builds model from CarConfig dimensions
src/server/CarSpawner.luau       per-player car, seat events, ownership, reset, anchoring
src/server/RoadBuilder.luau      2 km road + curve + ground plane + parking bay
src/client/init.client.luau
src/client/Input/init.luau       InputState aggregation + debug override
src/client/Input/Keyboard.luau
src/client/Input/Gamepad.luau
src/client/Input/Touch.luau
src/client/VehicleController.luau  runs VehicleSim on the owned car each PreSimulation
src/client/CameraRig.luau
src/client/DebugPanel.luau
docs/superpowers/specs/          this file
```

Rojo mapping: src/server → ServerScriptService/Server, src/client →
StarterPlayer/StarterPlayerScripts/Client, src/shared → ReplicatedStorage/Shared.
Every file starts with `--!strict`. No Wally packages.

## 4. Network model and lifecycle

1. Server builds the road and, on PlayerAdded, builds one car and parks it in
   the bay. Car removed on PlayerRemoving.
2. Server runs VehicleSim with zero input for any car with no driver (so it
   sits on its springs). Once a driverless car has been under 0.5 m/s for
   1 s the server anchors it. Unanchored when a player sits.
3. On VehicleSeat.Occupant → player: server sets chassis network owner to
   that player and fires `Remotes.DriveStart(carModel)` to them.
4. Client VehicleController runs VehicleSim on that car in
   RunService.PreSimulation with the live InputState. Forces are recomputed
   every step from the four raycasts, never accumulated.
5. On leaving the seat: server resets ownership and resumes its zero-input sim.
6. `Remotes.ResetCar` (R key / touch button): server re-parks the car upright
   at the nearest road point with zero velocity.
7. `Remotes.ReloadConfig` (L key): client and server both clone the CarConfig
   ModuleScript and require the clone, which re-evaluates its current Source.
   Rojo may or may not sync into a running play session; verified in step 1
   and documented in README. Editing the module in Studio's script editor
   during play always works with this path.

Deprecated body movers are not used. Only VectorForce, Torque, raycasts,
and Weld.

## 5. Car model

Built by CarBuilder from CarConfig:

- `Chassis` (PrimaryPart): box, `bodySize` metres, CanCollide true,
  CustomPhysicalProperties density = massKg × shellMassFraction / volume.
- `Ballast`: small hidden box, CanCollide false, positioned so the assembly
  centre of mass equals `centerOfMassOffset` from the box centre. Density
  chosen from the remaining mass (Roblox max density is 100, size adjusted
  to fit).
- Four `Wheel_FL/FR/RL/RR` cylinders: Massless, CanCollide false, welded to
  chassis, repositioned every frame by the sim to the ray hit and rolled by
  wheel speed.
- Four corner Attachments at hardpoints (wheelbase / track from config).
- `VehicleSeat` welded at driver position; server listens to Occupant.
- `VectorForce` (ApplyAtCenterOfMass, RelativeTo World) and `Torque`
  (RelativeTo World) on chassis, written by the sim.
- `Humanoid`-less. Model has attribute `OwnerUserId`.

## 6. Physics model

All math in SI inside the sim; positions and velocities read from Roblox are
converted with Units at entry, forces converted at exit.

### 6.1 Suspension (per corner, Suspension.luau)

- Ray from hardpoint along −body up, length `restLength + travel + wheelRadius`.
- Compression `x = restLength − (hitDistance − wheelRadius)`, clamped to
  `[0, travel]`. No hit → wheel unloaded, no forces.
- Compression rate from the change in `x` per step.
- Force along body up = `stiffness × x + damping × dx/dt`, clamped ≥ 0.
- Anti-roll: per axle, add `antiRoll × (xLeft − xRight)` to the left corner
  and subtract from the right.
- Applied at the hardpoint; torque about centre of mass computed by the sim.
- Normal load `Fz` for the tire = this corner force.

Defaults target ~1.4 Hz natural frequency and ~0.35 damping ratio for a
1600 kg car (stiffness ~35 kN/m, damping ~2.6 kNs/m, travel 0.2 m).

### 6.2 Tires (Tire.luau)

Per grounded wheel:

- Contact point = ray hit. Velocity = linear + angular × (contact − CoM),
  projected onto the ground plane.
- Wheel heading = body forward rotated by steer angle (front only) about
  body up, projected onto ground. Lateral = up × heading.
- `vLong`, `vLat` = velocity components. Slip angle
  `α = atan2(vLat, |vLong|)`.
- Grip curve `G(|α|)`: rises linearly to 1 at `peakSlipDeg`, then decays
  linearly to `slideGripRatio` at `slideSlipDeg`, flat after. Front and
  rear each have `grip`, `peakSlipDeg`, `slideSlipDeg`, `slideGripRatio`.
- Lateral demand `Fy = −sign(α) × Fz × grip × G`.
- Longitudinal demand `Fx` from Drivetrain (drive, brake, handbrake,
  engine brake).
- Friction circle: `Fmax = Fz × grip`. If `|Fx| > Fmax` the wheel is
  spinning/locked: `Fx = sign × Fmax × slideGripRatio`, and `Fy` is scaled by
  `slideGripRatio`. Otherwise `Fy` is clamped to `sqrt(Fmax² − Fx²)`.
  Longitudinal has priority because it is driver-commanded; this is the
  "too much throttle spins" mechanism.
- Speed fade: total tire force scaled by `min(|v| / 1 m/s, 1)`.
- Handbrake: rear `grip` multiplied by `handbrakeRearGripMultiplier`, rear
  `Fx` = capped brake force.
- Forces applied at the contact point (ground level), so lateral force ×
  suspension height produces real roll ("jacking").

### 6.3 Drivetrain (Drivetrain.luau)

- Rear wheel speed = mean of rear `vLong` / wheelRadius, plus spin.
- `rpm = wheelAngular × gearRatio × finalDrive × 60 / 2π`, clamped to
  `[idleRpm, redlineRpm]`. While a rear wheel is spinning, rpm floats toward
  redline at `spinRpmRate` × throttle.
- Engine torque = `Curve.lookup(torqueCurve, rpm) × throttle`, zero above
  redline (rev limiter).
- Drive force per rear wheel
  `= torque × gear × finalDrive × drivelineEfficiency / wheelRadius / 2`.
- Clutch kick: for `clutchKickDuration` after a tap, drive force ×
  `clutchKickMultiplier`.
- Engine brake: throttle < 0.05 → rear `Fx −= engineBrakeTorque × gear ×
  finalDrive / wheelRadius × (rpm / redline)`.
- Brake: `brakeForce × brakeInput`, split by `brakeBias` (front fraction).
- Automatic gearbox: upshift above `upshiftRpm`, downshift below
  `downshiftRpm`, `shiftTime` torque cut. Sequential through `gearRatios`.
- Aero drag at CoM: `0.5 × airDensity × dragCoefficient × frontalArea × v²`
  opposing velocity. Rolling resistance: `rollingResistance × mass × g`.

### 6.4 Steering

- Target = `steerInput × maxSteerDeg`.
- Approach target at `steerSpeedDegPerSec`; return toward centre at
  `steerReturnDegPerSec`.
- Drift assist: `steer += driftAssist × vehicleSlipAngle` (clamped to max
  steer), where vehicle slip angle is the angle between velocity and
  heading. Default 0.15.

### 6.5 Gravity correction

Each step add `+up × mass × (workspace.Gravity − gravity / metersPerStud)`
to the total force. With `gravity = 9.81` this makes the car fall at 35
studs/s². Setting `gravity = 54.9` zeroes the correction for A/B testing.

### 6.6 Two-wheel (TwoWheel.luau)

State: `idle | lifting | balanced | landing`.

- Press: side = sign of steer input at press time (default left).
  Enter `lifting`: torque about body forward axis = `liftTorque` toward side.
- Wheels on the lifted side lose ray contact and stop producing force; the
  two grounded tires carry double load and the friction circle shrinks
  honestly.
- When roll ≥ `targetRollDeg − 5`: enter `balanced`. Torque =
  `holdTorque + instability × (roll − targetRollDeg) − rollDamping × rollRate
  + balanceTorque × steerInput × side`. `holdTorque` approximately cancels
  gravity torque at target roll. `instability` > 0 makes the equilibrium
  slightly unstable (time constant ≈ 1.5 s) so ignoring it tips further;
  steer input recovers it.
- Roll ≥ `tipRollDeg` (65°): mode auto-releases, car falls over honestly.
- Release: `landing`, torque removed, `rollDamping` applied until all four
  wheels have contact, then `idle`.
- Suspension bias: while not idle, grounded-side stiffness ×
  `suspensionBias`.

### 6.7 Body properties

Centre of mass low and slightly forward via ballast. Yaw inertia comes from
the box shape (for the default dimensions ≈ 3600 kg·m², close to a real
sedan). No inertia override in Phase 0.

## 7. Input

`InputState`: `throttle 0..1, brake 0..1, steer −1..1, handbrake bool,
clutchKick bool (edge), twoWheel bool, reset bool (edge), reload bool (edge)`.

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle | W | RT | button, right side |
| Brake | S | LT | button, right side |
| Steer | A / D | left stick X | left/right buttons, left side |
| Handbrake | Space | B | button |
| Clutch kick | Shift (tap) | X | button |
| Two-wheel | F (hold) | Y (hold) | button (hold) |
| Reset car | R | Back | small button |
| Reload config | L | — | small button |

- All bound through ContextActionService. Touch buttons are created by the
  Touch module only when `UserInputService.TouchEnabled and not
  KeyboardEnabled`.
- Touch steer: target ramps at `touchSteerRampPerSec` with an ease-in curve
  (`touchSteerCurve` exponent). Keyboard steer ramps at
  `keyboardSteerRampPerSec`. Gamepad is raw with `gamepadDeadzone`.
- Steer input doubles as two-wheel balance input on every platform.
- `Input.override: InputState?` lets a test harness (the MCP) drive the car.

## 8. Camera

Scriptable camera. Each RenderStepped:

- Desired look direction = slerp(heading, velocityDir, `driftSwing`) when
  speed > 3 m/s, else heading.
- Smoothed direction lerps toward desired at rate `directionLag`.
- Position = carPos − smoothedDir × `distance` + up × `height`, smoothed at
  `positionLag`.
- FOV = `baseFov + fovPerKmh × speedKmh`, clamped to `maxFov`.
- Look at carPos + up × `lookHeight`.

## 9. Debug panel

ScreenGui, monospace TextLabel top-left, updated 10 Hz from the sim's
`VehicleState`:

```
SPD 132 km/h   GEAR 3   RPM 5400   THR 1.00 BRK 0.00 STR -0.42 (-18.3°)
DRIFT 71°   YAW 48°/s   MODE two-wheel  ROLL 41° (margin 24°)
FL slip  4.1° load 3.9kN        FR slip  3.8° load 5.2kN
RL slip 62.0° load 2.7kN SPIN   RR slip 60.4° load 4.1kN SPIN
HB off  KICK off  ASSIST 0.15
```

## 10. Test road

RoadBuilder at server start:

- Ground plane: 2600 × 600 m sand-coloured part at y = −0.1 m, anchored.
- Straight: 2000 m × 60 m asphalt, four 500 m parts (max part size 2048
  studs), top at y = 0.
- Centerline: 0.3 m wide, 6 m dashes with 6 m gaps, white/yellow, 0.01 m
  above the surface.
- Curve: radius 400 m, sweep 30°, 24 flat segments overlapping slightly,
  centerline continued.
- Parking bay: 40 × 60 m off the start, cars spawn on a grid.
- SpawnLocation next to the bay.

## 11. CarConfig fields (defaults)

Sections: `units`, `body`, `suspension`, `tires`, `drivetrain`, `steering`,
`handbrake`, `clutchKick`, `twoWheel`, `input`, `camera`, `debug`.

```
units.metersPerStud            0.28
units.gravity                  9.81      m/s² effective on the car
body.massKg                    1600
body.bodySize                  {4.9, 1.3, 1.8} m (L, H, W)
body.centerOfMassOffset        {0, -0.15, 0.2} m from box centre (lateral, up, forward)
body.wheelbase                 2.8 m
body.trackWidth                1.55 m
body.wheelRadius               0.33 m
body.wheelWidth                0.22 m
body.shellMassFraction         0.35
body.dragCoefficient           0.32
body.frontalArea               2.2 m²
body.airDensity                1.2
body.rollingResistance         0.015
suspension.restLength          0.35 m
suspension.travel              0.2 m
suspension.stiffness           35000 N/m
suspension.damping             2600 Ns/m
suspension.antiRollFront       8000 N/m
suspension.antiRollRear        4000 N/m
tires.front.grip               1.05
tires.front.peakSlipDeg        8
tires.front.slideSlipDeg       25
tires.front.slideGripRatio     0.75
tires.rear.grip                1.0
tires.rear.peakSlipDeg         7
tires.rear.slideSlipDeg        22
tires.rear.slideGripRatio      0.7
tires.speedFadeMps             1.0
drivetrain.torqueCurve         {{1000,180},{2500,260},{4000,300},{5500,290},{6500,240},{7000,0}}
drivetrain.gearRatios          {3.5, 2.1, 1.4, 1.0, 0.8}
drivetrain.finalDrive          3.9
drivetrain.drivelineEfficiency 0.9
drivetrain.idleRpm             900
drivetrain.redlineRpm          6800
drivetrain.upshiftRpm          6400
drivetrain.downshiftRpm        3000
drivetrain.shiftTime           0.15 s
drivetrain.spinRpmRate         6000 rpm/s
drivetrain.engineBrakeTorque   40 Nm
drivetrain.brakeForce          14000 N total
drivetrain.brakeBias           0.65 front
steering.maxSteerDeg           38
steering.steerSpeedDegPerSec   180
steering.steerReturnDegPerSec  360
steering.driftAssist           0.15
handbrake.rearGripMultiplier   0.35
handbrake.brakeForce           6000 N
clutchKick.multiplier          2.5
clutchKick.duration            0.3 s
twoWheel.liftTorque            9000 Nm
twoWheel.holdTorque            6000 Nm
twoWheel.targetRollDeg         42
twoWheel.instability           120 Nm/deg
twoWheel.rollDamping           400 Nm/(deg/s)
twoWheel.balanceTorque         5000 Nm
twoWheel.tipRollDeg            65
twoWheel.suspensionBias        1.4
input.keyboardSteerRampPerSec  4
input.touchSteerRampPerSec     3
input.touchSteerCurve          1.5
input.gamepadDeadzone          0.12
camera.distance                7.5 m
camera.height                  2.6 m
camera.lookHeight              0.8 m
camera.positionLag             8
camera.directionLag            4
camera.driftSwing              0.6
camera.baseFov                 70
camera.fovPerKmh               0.08
camera.maxFov                  85
debug.enabled                  true
debug.updateHz                 10
```

Defaults are starting points; the tuning loop adjusts them. TUNING.md
explains each field and its direction for more/less oversteer, easier/harder
initiation, more/less two-wheel stability.

## 12. Build order and per-step test

1. Repo, Rokit, Rojo project, README, git. Verify sync into Studio and the
   reload-during-play question.
2. Road + car model + suspension (server sim only, car sits on springs).
   Test: car settles without bouncing forever, rocks when pushed.
3. Tire model + drivetrain + client control via debug override.
   Test: drives straight, corners with grip, rear steps out on handbrake.
4. Debug panel. Test: numbers match what the car does.
5. Input (keyboard, gamepad, touch). Test: phone-sized viewport in Studio.
6. Camera. Test: swings out in a slide, doesn't snap.
7. Two-wheel. Test: lifts, holds with balance input, tips if ignored,
   lands without launching.
8. Tuning pass against the seven criteria in the goal, using the debug numbers.

Each step ends with a note: what to test in Studio and what to look for.

## 13. Testing approach

- I drive from the MCP: start play, set `Input.override` through
  execute_luau in the Client datamodel, read `VehicleState`, screen capture.
- Owner tests on keyboard, then on a phone-sized viewport, then on a phone.
- No automated unit tests for physics; Curve.luau and Units.luau get small
  self-check asserts run once at startup in Studio.

## 14. Out of scope (later phases)

Scoring, HUD, cash, plates, wraps, multiple cars, real Riyadh road, night
lighting, sessions, ranks, cases, Arabic, sound, particles, tire marks.

## 15. Open items to verify during build

- Rojo sync into a running play session (affects README reload notes).
- Roblox max density 100 with the ballast size (adjust size, not mass).
- `RunService.PreSimulation` cadence in Studio on this machine.
