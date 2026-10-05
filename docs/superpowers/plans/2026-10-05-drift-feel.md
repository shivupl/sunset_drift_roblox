# Drift Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real front-, rear- and all-wheel drive in the car sim, seven pickable drift styles (two or three per drivetrain), a throttle feather that keeps a drift alive, and a fluttering exhaust when the driver feathers mid-drift.

**Architecture:** `Drivetrain` gains pure axle shares and a launch cap; `VehicleSim.step` drives each wheel by its axle's share (RWD bit-identical). The gas-hold logic moves out of `VehicleSim.step` into a pure `VehicleSim/DriftControl` with new knobs (`CarConfig.drift`), feeding the throw controller an `angleRateDeg`. `DriftStyles` (shared config) names presets deep-merged over a car's config; the client picks one per drivetrain (Settings tab, Studio O). Exhaust styles gain a dense `flutter` pattern, fired instead of the lift burst when the lift happens sideways, relayed as a new kind.

**Tech Stack:** Roblox strict Luau, Rojo 7.7, Studio MCP (execute_luau specs in Edit, harness drives in Play).

**Spec:** `docs/superpowers/specs/2026-10-05-drift-feel-design.md`

## Global Constraints

- `--!strict` on every file; no invented or deprecated APIs.
- Tunables live in config modules (`CarConfig`, `DriftStyles`, `ExhaustStyles`), never inline; comment the why and the owner's request beside each number.
- RWD must stay bit-identical: same code path with axle shares (0, 1); the Kamri-as-RWD trick numbers must match the baseline.
- Nothing in `drift` acts while the lever is in (spec ruling 5).
- A style may only set keys no catalog car tunes (spec §4).
- Limiter pops stay off (owner, 2026-09-22).
- Stage specific files only; never commit the owner's uncommitted rig files (RIG_SPEC.md, RigBuilder, CarCatalog's other lines, VehicleRig, VehicleRig.spec, tools/carbody, assets/cars/kruzer100). CarCatalog lines of ours go in with the hash-object routine (CLAUDE.md).
- Commits end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Specs: run with the Shared clone-swap from CLAUDE.md; the baseline is 14 VehicleRig.spec failures.
- Type check: `bash scripts/analyze.sh`; only new errors in touched files matter.
- Measure in Play with the input-override harness (open-loop timed inputs), never a closed-loop scripted driver.

## Review Focus

1. A reset (R key, respawn) mid-feather or mid-kick: the next run must start with no stale timers (DriftControl.reset on the sim's reset detection; spec'd).
2. The two-wheel natl on FWD and AWD cars: drive now reaches a grounded front wheel; the tap/hold numbers must stay close to RWD (measured in Task 6).
3. A stale or wrong-layout style attribute (older build, a removed style id): resolves to the layout's default (DriftStyles.resolve, spec'd).
4. A config reload (L) while a style is applied: the sim must pick up the reloaded car config with the style still on (cache cleared; checked in Play).
5. Fast feathering on a keyboard: flutter + cut each time must not exceed the relay budget (12/s) at 4 feathers a second (spec'd arithmetic; checked in Play).

---

### Task 1: Drive layouts in the sim

**Files:**
- Modify: `src/shared/VehicleSim/Drivetrain.luau` (Config type; new `axleShares`, `launchCap`)
- Modify: `src/shared/CarConfig.luau` (`drivetrain.layout`, `frontShare`, `frontDiffLock`)
- Modify: `src/shared/VehicleSim/init.luau` (launch cap, gearbox speed, engine spin, per-wheel drive, engine braking, inertia, traction control, visual spin)
- Test: `src/shared/Tests/Drivetrain.spec.luau`

**Interfaces:**
- Produces: `Drivetrain.axleShares(cfg: Drivetrain.Config): (number, number)` (front, rear); `Drivetrain.launchCap(a: Drivetrain.LaunchArgs): number` (crank torque cap, Nm); `Drivetrain.LaunchAxle = { cap: number, share: number }`; config keys `drivetrain.layout: string`, `drivetrain.frontShare: number`, `drivetrain.frontDiffLock: number`.

- [ ] **Step 1: Write the failing tests** (append to `Drivetrain.spec.luau`, inside the returned function)

```lua
	-- Axle shares by layout
	local function shares(over: { [string]: any }): (number, number)
		local c = table.clone(cfg) :: any
		for k, v in over do
			c[k] = v
		end
		return Drivetrain.axleShares(c)
	end
	local f, r = shares({})
	t.eq(f, 0, "no layout is rear drive: nothing to the front")
	t.eq(r, 1, "no layout is rear drive: everything to the rear")
	f, r = shares({ layout = "FWD", frontShare = 0.3 })
	t.eq(f, 1, "front drive sends everything to the front, whatever frontShare says")
	t.eq(r, 0, "front drive sends nothing to the rear")
	f, r = shares({ layout = "AWD", frontShare = 0.3 })
	t.near(f, 0.3, 1e-12, "all-wheel drive splits by frontShare")
	t.near(r, 0.7, 1e-12, "the rest to the rear")
	f, r = shares({ layout = "AWD", frontShare = 1.4 })
	t.eq(f, 1, "frontShare clamps to 1")
	f, r = shares({ layout = "RWD", frontShare = 0.5 })
	t.eq(f, 0, "rear drive ignores frontShare")

	-- Launch cap: on rear drive it is exactly the formula VehicleSim used inline
	local args = {
		mass = 1600, use = 1.0, wheelInertia = 1.4, engineInertia = 0.15,
		overall = 3.5 * 3.9, efficiency = 0.9, radius = 0.33,
		axles = { { cap = 0, share = 0 }, { cap = 7000, share = 1 } },
	}
	local tyreForce = 7000 * 1.0
	local wheelInertia = 1.4 + 0.5 * 0.15 * (3.5 * 3.9) ^ 2
	local carAccel = 2 * tyreForce / 1600
	local wheelTorque = tyreForce * 0.33 + wheelInertia * carAccel / 0.33
	local old = wheelTorque * 2 / (3.5 * 3.9 * 0.9)
	t.near(Drivetrain.launchCap(args), old, 1e-9, "RWD launch cap equals the old inline formula")
	-- Front drive: the same axle numbers moved to the front give the same cap
	args.axles = { { cap = 7000, share = 1 }, { cap = 0, share = 0 } }
	t.near(Drivetrain.launchCap(args), old, 1e-9, "FWD with the same tyre cap gives the same crank cap")
	-- All-wheel drive: two axles share the work, so the crank may give more
	args.axles = { { cap = 7000, share = 0.5 }, { cap = 7000, share = 0.5 } }
	t.ok(Drivetrain.launchCap(args) > old, "AWD puts more torque down than one axle")
	-- The weaker axle limits: halving the front's grip lowers the cap
	local even = Drivetrain.launchCap(args)
	args.axles = { { cap = 3500, share = 0.5 }, { cap = 7000, share = 0.5 } }
	t.ok(Drivetrain.launchCap(args) < even, "the axle that runs out first sets the cap")
	-- No driven axle (a bad config) never caps
	args.axles = { { cap = 7000, share = 0 }, { cap = 7000, share = 0 } }
	t.eq(Drivetrain.launchCap(args), math.huge, "no driven axle: no cap")
```

- [ ] **Step 2: Run the specs to verify they fail**

Run (execute_luau, Edit): the clone-swap one-liner from CLAUDE.md.
Expected: Drivetrain.spec errors on `axleShares` being nil (a spec error counts as a failure line).

- [ ] **Step 3: Implement in `Drivetrain.luau`**

Add to `Config`:

```lua
	-- Which wheels the engine drives: "RWD" (nil), "FWD" or "AWD", and
	-- under AWD the share of torque the front axle takes (a fixed-split
	-- centre diff). The front axle's own diff blends like diffLock.
	layout: string?,
	frontShare: number?,
	frontDiffLock: number?,
```

Add after `Drivetrain.new`:

```lua
-- The share of drive torque each axle gets, (front, rear). Rear drive is
-- the default, so a config without a layout drives as every car always has.
function Drivetrain.axleShares(cfg: Config): (number, number)
	if cfg.layout == "FWD" then
		return 1, 0
	elseif cfg.layout == "AWD" then
		local f = math.clamp(cfg.frontShare or 0.5, 0, 1)
		return f, 1 - f
	end
	return 0, 1
end

export type LaunchAxle = {
	cap: number, -- N: the drive one wheel of this axle can put down now (the lesser of the two)
	share: number, -- this axle's share of the crank torque
}

export type LaunchArgs = {
	axles: { LaunchAxle },
	use: number, -- slipModel.launchGripUse
	mass: number,
	wheelInertia: number,
	engineInertia: number,
	overall: number, -- gear ratio x final drive
	efficiency: number,
	radius: number,
}

-- Launch control's crank torque cap: what the driven tyres can put down at
-- their peak slip, plus what it takes to spin the wheels and the engine up
-- with the car (leaving that out capped the launch 18% short). The axle
-- that runs out first sets it. On rear drive this is exactly the formula
-- VehicleSim used inline before drive layouts.
function Drivetrain.launchCap(a: LaunchArgs): number
	local carAccel = 0
	for _, axle in a.axles do
		if axle.share > 0 then
			carAccel += 2 * axle.cap * a.use / a.mass
		end
	end
	local crank = math.huge
	for _, axle in a.axles do
		if axle.share > 0 then
			local tyreForce = axle.cap * a.use
			local inertia = a.wheelInertia + 0.5 * a.engineInertia * a.overall * a.overall * axle.share
			local wheelTorque = tyreForce * a.radius + inertia * carAccel / a.radius
			crank = math.min(crank, wheelTorque * 2 / (a.overall * a.efficiency * axle.share))
		end
	end
	return crank
end
```

Rename nothing in `Output`: `drivePerRearWheel` and `engineBrakePerRearWheel` keep their meaning (half the total), documented as "per wheel at a full axle share".

- [ ] **Step 4: Add the config keys** (`CarConfig.drivetrain`, after `diffLock`)

```lua
		-- Which wheels drive (DESIGN.md, Drivetrains). "RWD" is every car
		-- until the catalog says otherwise (the owner, 2026-10-05: "the drift
		-- style to differ slightly depending on the drivestyle of the vehicle
		-- (awd,rwd,fwd,etc)"). FWD drives the fronts; AWD splits by
		-- frontShare through a fixed centre diff. Drift styles set the split.
		layout = "RWD",
		frontShare = 0.5,
		-- The front axle's diff under FWD/AWD, like diffLock for the rear:
		-- open enough that a lifted wheel on two wheels does not yaw the car.
		frontDiffLock = 0.25,
```

- [ ] **Step 5: Drive by axle share in `VehicleSim/init.luau`**

5a. After `local slipModel = ...` compute the shares and the driven-wheel speeds, replacing `rearWheelSpeed`, `rearSpinning`, `rearSpinSpeed`:

```lua
	local frontShare, rearShare = Drivetrain.axleShares(cfg.drivetrain)
	-- Road speed and spin of the driven wheels, weighted by share: the
	-- gearbox goes by the first, the engine turns with the second.
	local drivenWheelSpeed = frontShare * (contacts[1].vLong + contacts[2].vLong) / 2
		+ rearShare * (contacts[3].vLong + contacts[4].vLong) / 2
	local drivenSpinning = (frontShare > 0 and (self.wheels[1].state.saturated or self.wheels[2].state.saturated))
		or (rearShare > 0 and (self.wheels[3].state.saturated or self.wheels[4].state.saturated))
	local drivenSpinSpeed: number? = if slipModel
		then (frontShare * (self.wheels[1].omega + self.wheels[2].omega) / 2 + rearShare * (self.wheels[3].omega + self.wheels[4].omega) / 2) * cfg.body.wheelRadius
		else nil
```

and pass `drivenWheelSpeed, drivenSpinning, ..., drivenSpinSpeed` to `Drivetrain.step` in place of the rear ones.

5b. Launch control: replace the block from `local wheelCap = math.huge` to `local crankCap = ...` with

```lua
			local axles: { Drivetrain.LaunchAxle } = {}
			for _, ax in { { 1, 2, frontShare, cfg.tires.front }, { 3, 4, rearShare, cfg.tires.rear } } do
				local i, j, share, tyre = ax[1] :: number, ax[2] :: number, ax[3] :: number, ax[4] :: Tire.AxleConfig
				local cap = math.huge
				for _, k in { i, j } do
					local load = contacts[k].susp.force
					cap = math.min(cap, load * tyre.grip * Wheel.loadFactor(sc, load, staticLoad) * (tyre.longitudinalGrip or 1))
				end
				table.insert(axles, { cap = cap, share = share })
			end
			local crankCap = Drivetrain.launchCap({
				axles = axles,
				use = sc.launchGripUse,
				mass = mass,
				wheelInertia = sc.wheelInertia,
				engineInertia = sc.engineInertia,
				overall = overall,
				efficiency = cfg.drivetrain.drivelineEfficiency,
				radius = cfg.body.wheelRadius,
			})
```

(keep the comments about the inertia; drop `rearAxle`, `wheelCap`, `tyreForce`, `wheelInertia`, `carAccel`, `wheelTorque` locals).

5c. The legacy tyre branch (`fxDemand`), per wheel:

```lua
		local share = if w.front then frontShare else rearShare
		local axleLock = if w.front then cfg.drivetrain.frontDiffLock else cfg.drivetrain.diffLock
		local brakeN = if w.front then drive.brakePerFrontWheel else drive.brakePerRearWheel
		local diffShare = 1
		if share > 0 then
			-- Differential: an open diff can only push this wheel as hard as
			-- the other wheel on its axle can react, so drive here scales with
			-- that wheel's load. The axle's lock blends toward a welded split.
			local other = contacts[if w.front then (if w.left then 2 else 1) else (if w.left then 4 else 3)]
			local ratio = if c.susp.force > 1e-3 then math.clamp(other.susp.force / c.susp.force, 0, 1) else 1
			diffShare = axleLock + (1 - axleLock) * ratio
		end
		local fxDemand = drive.drivePerRearWheel * share * diffShare
			+ brakeDir * (brakeN + drive.engineBrakePerRearWheel * share) * brakeFade
		local gripMult = rimGrip
		if not w.front then
			gripMult *= flickCut
			if hbLevel > 0 then
				gripMult *= 1 + (cfg.handbrake.rearGripMultiplier - 1) * hbLevel
				fxDemand += brakeDir * cfg.handbrake.brakeForce / 2 * brakeFade * hbLevel
			end
		end
```

5d. The slip-model branch, per wheel:

```lua
				local driveTorque = 0
				local brakeTorque = (brakeN + drive.engineBrakePerRearWheel * share) * r
				local inertia = sc.wheelInertia
				local wheelGrip = rimGrip
				if share > 0 then
					driveTorque = drive.drivePerRearWheel * share * diffShare * r
					local gearRatio = if drive.gear == -1 then cfg.drivetrain.reverseRatio else cfg.drivetrain.gearRatios[drive.gear]
					local overall = gearRatio * cfg.drivetrain.finalDrive
					-- The crank's inertia, reflected through the gearing, shared
					-- between the driven axles as the torque is.
					inertia += 0.5 * sc.engineInertia * overall * overall * share
				end
				if not w.front then
					brakeTorque += sc.handbrakeTorque * hbLevel
					if self.flickTimer > 0 then
						wheelGrip *= sc.flickRearGripMultiplier
					end
					if hbLevel > 0 then
						wheelGrip *= 1 + (sc.handbrakeGripCut - 1) * hbLevel
					end
				end
```

(`share`, `diffShare`, `brakeN` come from 5c, computed once above both branches.)

5e. Traction control's spinning flag: `rearSpinning` is gone; `drivenSpinning` goes to `Drivetrain.step`. The visual spin-up for the legacy tyre: `elseif out.saturated and not w.front then` becomes `elseif out.saturated and (if w.front then frontShare else rearShare) > 0 then`.

- [ ] **Step 6: Run the specs**

Expected: Drivetrain.spec passes; total failures = the 14 VehicleRig baseline.

- [ ] **Step 7: Type check**

Run: `bash scripts/analyze.sh 2>&1 | grep -E "VehicleSim|Drivetrain|CarConfig" | head`
Expected: no lines.

- [ ] **Step 8: RWD regression in Play** (harness `_G.H` suite: launch, handbrake, held, 360, catch on kamri07)

Expected: within run-to-run noise of `baseline.md` (launch 1.05/1.95/3.65/6.84; 360 2.45 s at 84).

- [ ] **Step 9: Commit**

```bash
git add src/shared/VehicleSim/Drivetrain.luau src/shared/VehicleSim/init.luau src/shared/CarConfig.luau src/shared/Tests/Drivetrain.spec.luau
git commit -m "Drive layouts: front, rear and all-wheel drive in the sim (RWD unchanged)"
```

---

### Task 2: The feather, the kick and the style knobs (`DriftControl`)

**Files:**
- Create: `src/shared/VehicleSim/DriftControl.luau`
- Create: `src/shared/Tests/DriftControl.spec.luau`
- Modify: `src/shared/VehicleSim/Throw.luau` (Input `angleRateDeg?`, `dt?`)
- Modify: `src/shared/Tests/Throw.spec.luau`
- Modify: `src/shared/CarConfig.luau` (new `drift` section)
- Modify: `src/shared/VehicleSim/init.luau` (use DriftControl in place of the inline gas hold)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `DriftControl.new(): State`, `DriftControl.reset(s: State)`, `DriftControl.step(s: State, cfg: Config, steering: SteeringGates, inp: Input, dt: number): Output` with `Output = { gasHold: boolean, feathering: boolean, angleRateDeg: number, liftThrow: number, liftRearGrip: number, tractionAside: boolean }`; `CarConfig.drift` keys listed in Step 3; `Throw.Input.angleRateDeg: number?`, `Throw.Input.dt: number?`.

- [ ] **Step 1: Write the failing DriftControl spec** (`src/shared/Tests/DriftControl.spec.luau`)

```lua
--!strict
local DriftControl = require(script.Parent.Parent.VehicleSim.DriftControl)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local gates = {
		throwThrottleHold = 0.8,
		throwThrottleHoldFromDeg = 20,
		throwThrottleHoldGraceSeconds = 0.5,
		throwThrottleHoldKeepDeg = 10,
	}
	local function cfgWith(over: { [string]: any }): DriftControl.Config
		local c: DriftControl.Config = {
			featherSeconds = 0.3,
			featherDegPerSec = 25,
			kickDeg = 5,
			kickSeconds = 0.2,
			holdDecayDegPerSec = 0,
			holdMinDeg = 0,
			holdMaxDeg = 180,
			holdEaseDegPerSec = 30,
			liftThrow = 0,
			liftThrowSeconds = 0.5,
			liftThrowMinKmh = 60,
			liftThrowSteer = 0.5,
			liftThrowRearGrip = 1,
			powerOverSteer = 2,
			gasHoldFromScale = 1,
			slideReliefScale = 1,
		}
		for k, v in over do
			(c :: any)[k] = v
		end
		return c
	end
	local function inp(over: { [string]: any }): DriftControl.Input
		local i: DriftControl.Input = { throttle = 1, steer = 0, driftAngleDeg = 30, speedKmh = 100, lever = 0, twoWheel = false }
		for k, v in over do
			(i :: any)[k] = v
		end
		return i
	end
	local dt = 1 / 60
	local function run(s: DriftControl.State, c: DriftControl.Config, i: DriftControl.Input, seconds: number): DriftControl.Output
		local out
		for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do
			out = DriftControl.step(s, c, gates, i, dt)
		end
		return out
	end

	-- The gas hold as it was: gas past the gate and sideways arms it
	local c = cfgWith({})
	local s = DriftControl.new()
	local o = run(s, c, inp({}), 0.1)
	t.eq(o.gasHold, true, "gas and sideways arm the hold")
	t.eq(o.angleRateDeg, 0, "a plain hold moves nothing")
	o = run(s, c, inp({ throttle = 0.5 }), dt)
	t.eq(o.feathering, true, "a lift under the gate starts a feather")
	t.eq(o.gasHold, true, "the hold survives the start of a feather")
	t.near(o.angleRateDeg, 25, 1e-9, "a feather moves the angle at featherDegPerSec")
	-- a short lift then the gas back: kick
	run(s, c, inp({ throttle = 0 }), 0.2)
	o = run(s, c, inp({}), dt)
	t.eq(o.gasHold, true, "the gas back inside the feather keeps the hold")
	t.eq(o.feathering, false, "and ends the feather")
	t.near(o.angleRateDeg, -5 / 0.2, 1e-9, "the stab kicks: kickDeg over kickSeconds, away from straight")
	o = run(s, c, inp({}), 0.25)
	t.eq(o.angleRateDeg, 0, "the kick is over after kickSeconds")

	-- A long lift drops the hold, as before
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ throttle = 0 }), 0.35)
	t.eq(o.gasHold, false, "a lift longer than featherSeconds drops the hold")
	t.eq(o.feathering, false, "and is no longer a feather")
	o = run(s, c, inp({}), dt)
	t.eq(o.angleRateDeg, 0, "gas after a dropped hold is not a kick")

	-- featherSeconds 0 is the old car: any lift drops it at once
	s = DriftControl.new()
	local old = cfgWith({ featherSeconds = 0 })
	run(s, old, inp({}), 0.1)
	o = run(s, old, inp({ throttle = 0 }), dt)
	t.eq(o.gasHold, false, "featherSeconds 0: the first lifted step drops the hold")

	-- A feather only exists while a hold does
	s = DriftControl.new()
	o = run(s, c, inp({ throttle = 0, driftAngleDeg = 5 }), 0.1)
	t.eq(o.feathering, false, "no hold, no feather")

	-- Nothing moves the angle under the lever
	s = DriftControl.new()
	run(s, c, inp({ lever = 1 }), 0.1)
	o = run(s, c, inp({ throttle = 0, lever = 1 }), dt)
	t.eq(o.angleRateDeg, 0, "under the lever a feather moves nothing")
	local decay = cfgWith({ holdDecayDegPerSec = 4 })
	s = DriftControl.new()
	o = run(s, decay, inp({ lever = 1 }), 0.1)
	t.eq(o.angleRateDeg, 0, "under the lever the hold does not decay")
	o = run(s, decay, inp({}), dt)
	t.near(o.angleRateDeg, 4, 1e-9, "on the gas alone it decays at holdDecayDegPerSec")

	-- The band: under holdMinDeg it grows, over holdMaxDeg it comes back
	local band = cfgWith({ holdMinDeg = 40, holdMaxDeg = 60, holdEaseDegPerSec = 35 })
	s = DriftControl.new()
	o = run(s, band, inp({ driftAngleDeg = 30 }), 0.1)
	t.near(o.angleRateDeg, -35, 1e-9, "under holdMinDeg the held angle grows at holdEaseDegPerSec")
	o = run(s, band, inp({ driftAngleDeg = 70 }), dt)
	t.near(o.angleRateDeg, 35, 1e-9, "over holdMaxDeg it comes back")
	o = run(s, band, inp({ driftAngleDeg = 50 }), dt)
	t.eq(o.angleRateDeg, 0, "inside the band it is left alone")
	o = run(s, band, inp({ driftAngleDeg = -30 }), dt)
	t.near(o.angleRateDeg, -35, 1e-9, "the band works the same way on either side (rate is toward straight)")

	-- The lift throw: a fast lift with the wheel turned at speed, before the slide
	local lift = cfgWith({ liftThrow = 0.6, liftThrowRearGrip = 0.7, liftThrowSeconds = 0.5 })
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.near(o.liftThrow, 0.6, 1e-9, "a lift with the wheel turned throws the car")
	t.near(o.liftRearGrip, 0.7, 1e-9, "and cuts the rear's grip")
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), 0.55)
	t.eq(o.liftThrow, 0, "the throw lasts liftThrowSeconds")
	t.eq(o.liftRearGrip, 1, "and so does the grip cut")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.2, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.2, driftAngleDeg = 2 }), dt)
	t.eq(o.liftThrow, 0, "a lift with the wheel straight is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, speedKmh = 40 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, speedKmh = 40 }), dt)
	t.eq(o.liftThrow, 0, "under liftThrowMinKmh a lift is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 0.5, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.liftThrow, 0, "a lift from part throttle is not a throw")
	s = DriftControl.new()
	run(s, lift, inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2, lever = 1 }), 0.1)
	o = run(s, lift, inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2, lever = 1 }), dt)
	t.eq(o.liftThrow, 0, "under the lever a lift is not a throw")
	s = DriftControl.new()
	run(s, cfgWith({}), inp({ throttle = 1, steer = 0.8, driftAngleDeg = 2 }), 0.1)
	o = run(s, cfgWith({}), inp({ throttle = 0, steer = 0.8, driftAngleDeg = 2 }), dt)
	t.eq(o.liftThrow, 0, "liftThrow 0 is off")

	-- Power-over: traction control steps aside with the wheel turned past powerOverSteer
	o = DriftControl.step(DriftControl.new(), cfgWith({ powerOverSteer = 0.7 }), gates, inp({ steer = 0.8, driftAngleDeg = 0 }), dt)
	t.eq(o.tractionAside, true, "past powerOverSteer the launch and traction control step aside")
	o = DriftControl.step(DriftControl.new(), cfgWith({}), gates, inp({ steer = 1, driftAngleDeg = 0 }), dt)
	t.eq(o.tractionAside, false, "powerOverSteer above 1 never steps aside")
	-- ...and the gas hold arms lower
	s = DriftControl.new()
	o = run(s, cfgWith({ gasHoldFromScale = 0.5 }), inp({ driftAngleDeg = 12 }), dt)
	t.eq(o.gasHold, true, "gasHoldFromScale 0.5 arms the hold at half the angle")
	s = DriftControl.new()
	o = run(s, cfgWith({}), inp({ driftAngleDeg = 12 }), dt)
	t.eq(o.gasHold, false, "at scale 1 twelve degrees is under the gate")

	-- Two wheels: no gas hold, no feather
	s = DriftControl.new()
	o = run(s, c, inp({ twoWheel = true }), 0.1)
	t.eq(o.gasHold, false, "no gas hold on two wheels")

	-- Reset clears everything mid-feather and mid-kick
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	run(s, c, inp({ throttle = 0 }), 0.1)
	DriftControl.reset(s)
	o = run(s, c, inp({ driftAngleDeg = 5 }), dt)
	t.eq(o.gasHold, false, "a reset drops the hold")
	t.eq(o.angleRateDeg, 0, "and no kick comes after it")

	-- The grace: the hold survives the straight moment of a transition
	s = DriftControl.new()
	run(s, c, inp({}), 0.1)
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, true, "under the gate for less than the grace, still held")
	o = run(s, c, inp({ driftAngleDeg = 2 }), 0.3)
	t.eq(o.gasHold, false, "past the grace with the wheel centred it lets go")
end
```

- [ ] **Step 2: Add Throw spec cases** (append to `Throw.spec.luau`)

```lua
	-- angleRateDeg moves the latched hold: + toward straight
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 30, yawRateDeg = 0 }))
	t.eq(st.holdLatched, true, "settled: latched at 30")
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 30, angleRateDeg = 60, dt = 0.5 }))
	t.near(st.holdAngleDeg, 0 + 30 - 30, 1e-9, "60 deg/s toward straight for 0.5 s takes 30 off the hold")
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = -30 }))
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = -30, angleRateDeg = -20, dt = 0.5 }))
	t.near(st.holdAngleDeg, -40, 1e-9, "a negative rate grows the hold, on the left side too")
	st = Throw.new()
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 10 }))
	Throw.step(st, cfg, inp({ permission = 1, driftAngleDeg = 10, angleRateDeg = 100, dt = 0.5 }))
	t.eq(st.holdAngleDeg, 0, "toward straight never crosses through it")
	-- with the wheel turned it rides on the rate target
	st = Throw.new()
	local plain = Throw.step(st, cfg, inp({ permission = 1, steer = 0.5, driftAngleDeg = 30, yawRateDeg = 75 }))
	local pushed = Throw.step(st, cfg, inp({ permission = 1, steer = 0.5, driftAngleDeg = 30, yawRateDeg = 75, angleRateDeg = 10 }))
	t.near(pushed - plain, 600 * 10, 1e-6, "with the wheel turned, the rate adds to the target (drift + side)")
	local pushedL = Throw.step(st, cfg, inp({ permission = 1, steer = -0.5, driftAngleDeg = -30, yawRateDeg = -75, angleRateDeg = 10 }))
	t.near(pushedL, -6000, 1e-6, "mirrored on the left")
	-- absent fields are today's controller
	st = Throw.new()
	t.near(Throw.step(st, cfg, inp({ permission = 1, steer = 1 })), 16000, 1e-9, "no angleRateDeg: unchanged")
```

- [ ] **Step 3: Run the specs to verify they fail**

Expected: DriftControl.spec errors (module missing); Throw.spec fails the hold-moving cases.

- [ ] **Step 4: Write `DriftControl.luau`**

```lua
--!strict
-- The pedals in a slide. Pure: no Roblox instances.
--
-- The throttle is the throw controller's second permission (Throw.luau): gas
-- past throwThrottleHold with the car past throwThrottleHoldFromDeg keeps a
-- slide held with the lever out, through the straight moment of a
-- transition, until the gas is lifted. That logic lived inline in
-- VehicleSim.step; it is here now with what the drift styles add on top
-- (DriftStyles, the owner on 2026-10-05: "the drift style to differ
-- slightly depending on the drivestyle of the vehicle"):
--
--   * The feather. A lift shorter than featherSeconds keeps the hold, and
--     the held angle moves at featherDegPerSec meanwhile (+ toward
--     straight: rear drive regains grip; - away: front drive's lift-off
--     oversteer). The gas back on inside it kicks: kickDeg more angle over
--     kickSeconds (- pulls it in: the fronts pull straight). Before this a
--     0.25 s lift took a 30-degree slide to 1 degree a second later, so
--     the exhaust could not be set off mid-drift without losing the drift.
--   * The hold's drift: while the gas (not the lever) holds a slide, the
--     angle eases toward straight at holdDecayDegPerSec and is kept inside
--     holdMinDeg..holdMaxDeg at holdEaseDegPerSec.
--   * The lift throw: a fast lift with the wheel turned at speed, before the
--     car is sideways, throws it like a gentle flick (liftThrow is its
--     permission, liftThrowRearGrip the rear's grip meanwhile).
--   * Power-over: with the wheel past powerOverSteer, launch and traction
--     control step aside, and the gas hold arms from
--     throwThrottleHoldFromDeg x gasHoldFromScale.
--
-- None of it acts while the lever is in: the lever's 360, hold and catch
-- are the same on every style.
--
-- angleRateDeg is + toward straight, whichever side the car is sideways
-- on; Throw.step applies it to its latched hold angle or its rate target.
local DriftControl = {}

export type Config = {
	featherSeconds: number,
	featherDegPerSec: number,
	kickDeg: number,
	kickSeconds: number,
	holdDecayDegPerSec: number,
	holdMinDeg: number,
	holdMaxDeg: number,
	holdEaseDegPerSec: number,
	liftThrow: number,
	liftThrowSeconds: number,
	liftThrowMinKmh: number,
	liftThrowSteer: number,
	liftThrowRearGrip: number,
	powerOverSteer: number,
	gasHoldFromScale: number,
	slideReliefScale: number,
}

-- The steering section's gas-hold gates (Steering.Config has them all).
export type SteeringGates = {
	throwThrottleHold: number,
	throwThrottleHoldFromDeg: number,
	throwThrottleHoldGraceSeconds: number,
	throwThrottleHoldKeepDeg: number,
}

export type State = {
	holdOn: boolean, -- the gas is holding a slide
	straight: number, -- seconds under the keep gate with the wheel centred
	feather: number, -- seconds into a feather, -1 for none
	kick: number, -- seconds of kick left
	liftTimer: number, -- seconds of lift throw left
	lastThrottle: number,
}

export type Input = {
	throttle: number,
	steer: number,
	driftAngleDeg: number,
	speedKmh: number,
	lever: number, -- the handbrake's level, 0..1
	twoWheel: boolean,
}

export type Output = {
	gasHold: boolean,
	feathering: boolean,
	angleRateDeg: number, -- + toward straight; 0 under the lever
	liftThrow: number, -- 0..1 permission from a lift throw
	liftRearGrip: number, -- rear grip multiplier from a lift throw, 1 for none
	tractionAside: boolean,
}

-- Lifting from at least this much throttle to under LIFT_TO is a lift.
local LIFT_FROM = 0.6
local LIFT_TO = 0.1

function DriftControl.new(): State
	return { holdOn = false, straight = 0, feather = -1, kick = 0, liftTimer = 0, lastThrottle = 0 }
end

function DriftControl.reset(s: State)
	s.holdOn = false
	s.straight = 0
	s.feather = -1
	s.kick = 0
	s.liftTimer = 0
	s.lastThrottle = 0
end

function DriftControl.step(s: State, cfg: Config, g: SteeringGates, inp: Input, dt: number): Output
	local a = math.abs(inp.driftAngleDeg)
	local gasOn = not inp.twoWheel and inp.throttle >= g.throwThrottleHold
	local sidewaysNow = a >= g.throwThrottleHoldFromDeg * cfg.gasHoldFromScale
	local keepNow = a >= g.throwThrottleHoldKeepDeg
	if keepNow or math.abs(inp.steer) > 0.05 then
		s.straight = 0
	else
		s.straight += dt
	end

	-- The lift throw, read off the lift edge before the hold logic.
	local liftEdge = s.lastThrottle >= LIFT_FROM and inp.throttle < LIFT_TO
	if
		cfg.liftThrow > 0
		and liftEdge
		and not inp.twoWheel
		and inp.lever <= 0
		and inp.speedKmh >= cfg.liftThrowMinKmh
		and math.abs(inp.steer) >= cfg.liftThrowSteer
		and not sidewaysNow
	then
		s.liftTimer = cfg.liftThrowSeconds
	end

	if not gasOn then
		-- A lift. Inside featherSeconds of a held slide it is a feather.
		if s.holdOn and not inp.twoWheel then
			s.feather = (if s.feather < 0 then 0 else s.feather) + dt
			if s.feather > cfg.featherSeconds then
				s.holdOn = false
				s.feather = -1
			end
		else
			s.holdOn = false
			s.feather = -1
		end
	else
		if s.feather >= 0 and s.holdOn then
			-- The gas back inside a feather: the stab.
			s.kick = cfg.kickSeconds
		end
		s.feather = -1
		if sidewaysNow or inp.lever > 0 then
			s.holdOn = true
		elseif s.straight >= g.throwThrottleHoldGraceSeconds then
			s.holdOn = false
		end
	end
	local feathering = s.feather >= 0

	local rate = 0
	if s.holdOn and inp.lever <= 0 then
		if feathering then
			rate += cfg.featherDegPerSec
		end
		if s.kick > 0 and cfg.kickSeconds > 0 then
			rate -= cfg.kickDeg / cfg.kickSeconds
		end
		rate += cfg.holdDecayDegPerSec
		if keepNow and a < cfg.holdMinDeg then
			rate = math.min(rate, -cfg.holdEaseDegPerSec)
		elseif a > cfg.holdMaxDeg then
			rate = math.max(rate, cfg.holdEaseDegPerSec)
		end
	end
	s.kick = math.max(0, s.kick - dt)

	local throwing = s.liftTimer > 0
	s.liftTimer = math.max(0, s.liftTimer - dt)
	s.lastThrottle = inp.throttle
	return {
		gasHold = s.holdOn,
		feathering = feathering,
		angleRateDeg = rate,
		liftThrow = if throwing then cfg.liftThrow else 0,
		liftRearGrip = if throwing then cfg.liftThrowRearGrip else 1,
		tractionAside = math.abs(inp.steer) >= cfg.powerOverSteer,
	}
end

return DriftControl
```

Note the spec's "a short lift then the gas back: kick" case: the kick rate is read on the step the gas returns (s.kick set before the rate is computed, decremented after).

- [ ] **Step 5: `Throw.luau`**: add to `Input`

```lua
	-- Moves the held angle (DriftControl): + toward straight, deg/s. With
	-- the wheel turned it adds to the rate target instead. Optional; nil is 0.
	angleRateDeg: number?,
	dt: number?, -- the step, for moving the held angle
```

In the latched branch, before the error is taken:

```lua
			local rate = inp.angleRateDeg or 0
			local h = state.holdAngleDeg
			if rate ~= 0 and h ~= 0 then
				local mag = math.max(0, math.abs(h) - rate * (inp.dt or 0))
				state.holdAngleDeg = math.sign(h) * math.min(mag, 179)
			end
```

and in the wheel-turned branch: `driftRate = inp.steer * cfg.throwYawRateDegPerSec + math.sign(inp.driftAngleDeg) * (inp.angleRateDeg or 0)`.

- [ ] **Step 6: `CarConfig.drift`** (new section after `handbrake`, values = the Classic style)

```lua
	-- How the pedals work a slide (VehicleSim/DriftControl.luau). These
	-- are the Classic style's numbers; DriftStyles sets them per style.
	drift = {
		-- The feather: a lift this short keeps a gas-held slide (it used to
		-- drop at once: a 0.25 s lift took 30 degrees to 1 a second later,
		-- 2026-10-05), with the angle moving this fast toward straight
		-- meanwhile (- grows it). The gas back on inside it kicks kickDeg
		-- more angle over kickSeconds (- pulls it in).
		featherSeconds = 0.3,
		featherDegPerSec = 25,
		kickDeg = 5,
		kickSeconds = 0.2,
		-- A gas-held slide's angle eases toward straight this fast, and is
		-- kept between holdMinDeg and holdMaxDeg at holdEaseDegPerSec.
		holdDecayDegPerSec = 0,
		holdMinDeg = 0,
		holdMaxDeg = 180,
		holdEaseDegPerSec = 30,
		-- The lift throw (0 off): lifting fast with the wheel past
		-- liftThrowSteer at liftThrowMinKmh or more throws the car with
		-- this permission, the rear's grip times liftThrowRearGrip, for
		-- liftThrowSeconds.
		liftThrow = 0,
		liftThrowSeconds = 0.5,
		liftThrowMinKmh = 60,
		liftThrowSteer = 0.5,
		liftThrowRearGrip = 1,
		-- Power-over: past this much steer launch and traction control step
		-- aside (above 1: never), and the gas hold arms from
		-- throwThrottleHoldFromDeg times gasHoldFromScale.
		powerOverSteer = 2,
		gasHoldFromScale = 1,
		-- Times the car's slide momentum relief (slipModel.slideRelief).
		slideReliefScale = 1,
	},
```

- [ ] **Step 7: Wire it in `VehicleSim/init.luau`**

- `require(script.DriftControl)`; `driftControl: DriftControl.State` in the Sim type, `DriftControl.new()` in `new`.
- In the reset detection (`if moved > couldMove then`), also `DriftControl.reset(self.driftControl)`.
- Replace the block from `local gasOn = ...` to `local throttleHold = self.throttleHoldOn` with:

```lua
	local dc = DriftControl.step(self.driftControl, cfg.drift, cfg.steering, {
		throttle = input.throttle,
		steer = input.steer,
		driftAngleDeg = driftAngleDeg,
		speedKmh = Units.mpsToKmh(speed),
		lever = self.handbrakeLevel,
		twoWheel = twoWheelActive,
	}, dt)
	local throttleHold = dc.gasHold
```

  (keep the long comment above it; drop the `throttleHoldStraight`/`throttleHoldOn` fields.)
- `local throwNow = math.max(self.handbrakeLevel, if throttleHold then 1 else 0, dc.liftThrow)`.
- `tractionAllowed` gains `and not dc.tractionAside`.
- Rear grip: in the slip branch `wheelGrip *= dc.liftRearGrip` for rear wheels; in the legacy branch `gripMult *= dc.liftRearGrip`.
- Slide momentum: `momentum.slideRelief = sc.slideRelief * cfg.drift.slideReliefScale` (slip) and, for the legacy tyre, clone and scale `slideRelief` the same way.
- `Throw.step` input gains `angleRateDeg = dc.angleRateDeg, dt = dt`.

- [ ] **Step 8: Run specs** — Expected: DriftControl.spec and Throw.spec pass; 14 failures total.

- [ ] **Step 9: Type check** — Expected: no new errors in touched files.

- [ ] **Step 10: Play: the feather on Classic** (`_G.H.T.held(true)`, plus the catch and the chain)

Expected: a 0.25 s lift keeps the slide (angle a second later within ~10 degrees of before); catch under 5 within ~0.85 s; chain like the baseline.

- [ ] **Step 11: Commit**

```bash
git add src/shared/VehicleSim/DriftControl.luau src/shared/Tests/DriftControl.spec.luau src/shared/VehicleSim/Throw.luau src/shared/Tests/Throw.spec.luau src/shared/CarConfig.luau src/shared/VehicleSim/init.luau
git commit -m "The feather: a short lift keeps a drift; drift style knobs (DriftControl)"
```

---

### Task 3: The drift styles and each car's drivetrain

**Files:**
- Create: `src/shared/DriftStyles.luau`
- Create: `src/shared/Tests/DriftStyles.spec.luau`
- Modify: `src/shared/CarCatalog.luau` (our lines only: `tuning.drivetrain.layout` on kamri07 and hatch "FWD", batrol and kruzer80 "AWD")

**Interfaces:**
- Consumes: `CarConfig.drift` (Task 2), `drivetrain.layout/frontShare/frontDiffLock` (Task 1).
- Produces: `DriftStyles.styles: { [string]: Style }`, `DriftStyles.order: { string }`, `DriftStyles.layouts = { "RWD", "FWD", "AWD" }`, `DriftStyles.layoutName: { [string]: string }`, `DriftStyles.forLayout(layout: string): { string }`, `DriftStyles.default(layout: string): string`, `DriftStyles.layoutOf(cfg: any): string`, `DriftStyles.resolve(layout: string, id: any): string`, `DriftStyles.apply(base: CarConfig.Config, id: string): CarConfig.Config`; `Style = { name: string, layout: string, blurb: string, tuning: { [string]: any } }`.

- [ ] **Step 1: Write the failing spec** (`DriftStyles.spec.luau`)

```lua
--!strict
local Shared = script.Parent.Parent
local DriftStyles = require(Shared.DriftStyles)
local CarConfig = require(Shared.CarConfig)
local CarCatalog = require(Shared.CarCatalog)
local Tests = require(script.Parent)
type T = Tests.T

-- Every leaf path of a nested table ("tires.front.grip"); arrays are leaves.
local function paths(tbl: { [string]: any }, prefix: string, out: { [string]: boolean })
	for k, v in tbl do
		local p = if prefix == "" then tostring(k) else prefix .. "." .. tostring(k)
		if type(v) == "table" and type(k) == "string" and #v == 0 and next(v) ~= nil and typeof(next(v)) == "string" then
			paths(v, p, out)
		else
			out[p] = true
		end
	end
end

local function at(tbl: any, path: string): any
	local v = tbl
	for part in string.gmatch(path, "[^%.]+") do
		if type(v) ~= "table" then
			return nil
		end
		v = v[part]
	end
	return v
end

return function(t: T)
	-- Every layout has styles, its first is its default, and the order lists every style once
	local seen: { [string]: boolean } = {}
	for _, id in DriftStyles.order do
		t.ok(DriftStyles.styles[id] ~= nil, `order names a style: {id}`)
		t.ok(not seen[id], `listed once: {id}`)
		seen[id] = true
	end
	for id in DriftStyles.styles do
		t.ok(seen[id], `every style is in the order: {id}`)
	end
	for _, layout in DriftStyles.layouts do
		local ids = DriftStyles.forLayout(layout)
		t.ok(#ids >= 2, `{layout} has at least two styles`)
		t.eq(DriftStyles.default(layout), ids[1], `{layout}'s default is its first`)
		t.ok(DriftStyles.layoutName[layout] ~= nil, `{layout} has a name`)
		for _, id in ids do
			t.eq(DriftStyles.styles[id].layout, layout, `forLayout only lists its own: {id}`)
		end
	end

	-- A style sets only keys CarConfig has, and none a catalog car tunes
	local carKeys: { [string]: string } = {}
	for carId, entry in CarCatalog.cars do
		if entry.tuning then
			local p: { [string]: boolean } = {}
			paths(entry.tuning, "", p)
			for k in p do
				carKeys[k] = carId
			end
		end
	end
	for id, style in DriftStyles.styles do
		t.ok(#style.name > 0 and #style.blurb > 0, `{id} has a name and a blurb`)
		local p: { [string]: boolean } = {}
		paths(style.tuning, "", p)
		for k in p do
			t.ok(at(CarConfig, k) ~= nil, `{id}: {k} is a CarConfig key`)
			if k ~= "drivetrain.layout" then
				t.ok(carKeys[k] == nil, `{id}: {k} is not tuned by a car ({carKeys[k] or ""})`)
			end
		end
	end

	-- apply: the style's numbers over a copy of the car's config, the layout set
	local base = CarConfig
	for id, style in DriftStyles.styles do
		local cfg = DriftStyles.apply(base, id)
		t.eq(cfg.drivetrain.layout, style.layout, `apply sets the layout: {id}`)
		t.ok(cfg ~= base and cfg.drift ~= base.drift and cfg.tires ~= base.tires, `apply copies: {id}`)
		local p: { [string]: boolean } = {}
		paths(style.tuning, "", p)
		for k in p do
			t.eq(at(cfg, k), at(style.tuning, k), `apply sets {k}: {id}`)
		end
		-- ranges
		local d = cfg.drift
		t.ok(d.featherSeconds >= 0 and d.featherSeconds <= 0.6, `{id}: feather 0..0.6 s`)
		t.ok(math.abs(d.kickDeg) <= 20, `{id}: kick within 20 degrees`)
		t.ok(d.holdMinDeg < d.holdMaxDeg, `{id}: a band with room in it`)
		t.ok(d.liftThrow >= 0 and d.liftThrow <= 1, `{id}: liftThrow 0..1`)
		t.ok(cfg.drivetrain.frontShare >= 0 and cfg.drivetrain.frontShare <= 1, `{id}: frontShare 0..1`)
	end
	t.eq(CarConfig.drivetrain.layout, "RWD", "apply leaves the shared config alone")

	-- resolve: the id if it fits the layout, else the layout's default
	t.eq(DriftStyles.resolve("RWD", "power"), "power", "a rear-drive style on a rear-drive car")
	t.eq(DriftStyles.resolve("FWD", "power"), DriftStyles.default("FWD"), "a style of another layout falls back")
	t.eq(DriftStyles.resolve("RWD", "gone"), DriftStyles.default("RWD"), "an unknown id falls back")
	t.eq(DriftStyles.resolve("RWD", 7), DriftStyles.default("RWD"), "a non-string falls back")
	t.eq(DriftStyles.layoutOf({ drivetrain = { layout = "AWD" } }), "AWD", "layoutOf reads the config")
	t.eq(DriftStyles.layoutOf({ drivetrain = {} }), "RWD", "no layout is rear drive")
	t.eq(DriftStyles.layoutOf({ drivetrain = { layout = "4WD" } }), "RWD", "an unknown layout is rear drive")

	-- The cars' real drivetrains
	local function layoutOfCar(id: string): string
		local e = CarCatalog.cars[id]
		local tun = e and e.tuning
		return DriftStyles.layoutOf({ drivetrain = (tun and tun.drivetrain) or {} })
	end
	t.eq(layoutOfCar("kamri07"), "FWD", "the Kamri (a Camry) is front drive")
	t.eq(layoutOfCar("hatch"), "FWD", "the Hatch is front drive")
	t.eq(layoutOfCar("batrol"), "AWD", "the Batrol (a Patrol) is four-wheel drive")
	t.eq(layoutOfCar("kruzer80"), "AWD", "the Kruzer 80 (a Land Cruiser) is four-wheel drive")
	for _, id in { "pickup", "cruiser", "krownvik", "krownvikfleet", "lekzas" } do
		t.eq(layoutOfCar(id), "RWD", `{id} is rear drive`)
	end
end
```

- [ ] **Step 2: Run the specs to verify they fail** — Expected: DriftStyles.spec errors (module missing).

- [ ] **Step 3: Write `DriftStyles.luau`** (first-guess numbers; Task 6 tunes them)

```lua
--!strict
-- Drift styles (the owner, 2026-10-05: "I want the drift style to differ
-- slightly depending on the drivestyle of the vehicle (awd,rwd,fwd,etc) ...
-- implement a couple different styles (multiple for each) that i can test
-- and try out in game"). Research in docs/superpowers/specs/
-- 2026-10-05-drift-feel-research.md.
--
-- A car's catalog entry says which wheels it drives (drivetrain.layout);
-- the styles of that layout are offered in the menu's Settings tab, its
-- first is the default, and in Studio O cycles them (client DriftStyle).
-- A style is a partial CarConfig deep-merged over the car's own config: the
-- torque split and the pedal knobs (CarConfig.drift, DriftControl), never a
-- key a catalog car tunes (DriftStyles.spec), so each car keeps its own
-- character. Nothing here acts while the lever is in: the lever's 360s,
-- holds and catches are the same on every style.
local DriftStyles = {}

export type Style = {
	name: string,
	layout: string, -- "RWD" | "FWD" | "AWD"
	blurb: string, -- one line for the Settings tab
	tuning: { [string]: any },
}

DriftStyles.layouts = { "RWD", "FWD", "AWD" }
DriftStyles.layoutName = {
	RWD = "Rear-wheel drive",
	FWD = "Front-wheel drive",
	AWD = "All-wheel drive",
}

-- Front-drive and all-wheel styles give the front tyres the rear's drive
-- grip (tires.rear.longitudinalGrip, 1.9): without it the fronts spin on
-- the launch the rear puts down cleanly.
local FRONT_DRIVE_GRIP = 1.9

DriftStyles.styles = {
	-- REAR DRIVE.
	classic = {
		name = "Classic",
		layout = "RWD",
		blurb = "The car as you know it. A quick lift tightens it, the gas back kicks it out.",
		tuning = { drivetrain = { layout = "RWD" } },
	},
	power = {
		name = "Power Over",
		layout = "RWD",
		blurb = "Gas and full lock break the rear loose. Every stab of the gas kicks it wider.",
		tuning = {
			drivetrain = { layout = "RWD" },
			drift = { powerOverSteer = 0.7, gasHoldFromScale = 0.5, featherDegPerSec = 35, kickDeg = 14, kickSeconds = 0.25 },
		},
	},
	angle = {
		name = "High Angle",
		layout = "RWD",
		blurb = "Slides settle deep, 40 to 60 degrees, and carry their speed. All smoke.",
		tuning = {
			drivetrain = { layout = "RWD" },
			drift = { holdMinDeg = 40, holdMaxDeg = 60, holdEaseDegPerSec = 35, kickDeg = 8, slideReliefScale = 1.3 },
		},
	},
	-- FRONT DRIVE.
	handbrake = {
		name = "Handbrake",
		layout = "FWD",
		blurb = "The tafheet saloon. Throw it on the lever; the gas pulls it straighter, a lift swings the tail.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = { featherDegPerSec = -15, kickDeg = -6, holdDecayDegPerSec = 3 },
		},
	},
	liftoff = {
		name = "Lift-Off",
		layout = "FWD",
		blurb = "No lever needed: lift with the wheel turned and the tail comes round. Gas pulls it out.",
		tuning = {
			drivetrain = { layout = "FWD" },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = {
				liftThrow = 0.6, liftThrowSeconds = 0.6, liftThrowRearGrip = 0.6,
				featherDegPerSec = -25, kickDeg = -8, holdDecayDegPerSec = 2,
			},
		},
	},
	-- ALL-WHEEL DRIVE.
	rally = {
		name = "Rally",
		layout = "AWD",
		blurb = "A four-wheel power slide: shallow, driving forward. Flick it in.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.45 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP }, slipModel = { flickRearGripMultiplier = 0.55 } },
			drift = {
				holdMaxDeg = 35, holdEaseDegPerSec = 25, featherDegPerSec = 10, kickDeg = -3,
				slideReliefScale = 1.25, liftThrow = 0.4, liftThrowRearGrip = 0.75,
			},
		},
	},
	driftmode = {
		name = "Drift Mode",
		layout = "AWD",
		blurb = "The factory drift mode: most of the drive to the rear. Holds like rear drive, catches sooner.",
		tuning = {
			drivetrain = { layout = "AWD", frontShare = 0.15 },
			tires = { front = { longitudinalGrip = FRONT_DRIVE_GRIP } },
			drift = { kickDeg = 8, featherDegPerSec = 20 },
		},
	},
} :: { [string]: Style }

-- The order the menu shows and Studio's Shift+O cycles; within a layout,
-- the first is its default.
DriftStyles.order = { "classic", "power", "angle", "handbrake", "liftoff", "rally", "driftmode" }

-- A config's layout: "RWD" unless it says FWD or AWD.
function DriftStyles.layoutOf(cfg: any): string
	local d = type(cfg) == "table" and cfg.drivetrain
	local l = type(d) == "table" and d.layout
	if l == "FWD" or l == "AWD" then
		return l
	end
	return "RWD"
end

function DriftStyles.forLayout(layout: string): { string }
	local out = {}
	for _, id in DriftStyles.order do
		if DriftStyles.styles[id].layout == layout then
			table.insert(out, id)
		end
	end
	return out
end

function DriftStyles.default(layout: string): string
	return DriftStyles.forLayout(layout)[1] or "classic"
end

-- The id if it names a style of this layout, else the layout's default (a
-- stale attribute, a style since removed).
function DriftStyles.resolve(layout: string, id: any): string
	if type(id) == "string" and DriftStyles.styles[id] and DriftStyles.styles[id].layout == layout then
		return id
	end
	return DriftStyles.default(layout)
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function deepMerge(into: { [string]: any }, from: { [string]: any })
	for k, v in from do
		if type(v) == "table" and type(into[k]) == "table" and #v == 0 then
			deepMerge(into[k], v)
		else
			into[k] = deepCopy(v)
		end
	end
end

-- A car's config with a style on it: a copy, never the car's own table.
function DriftStyles.apply(base: any, id: string): any
	local cfg = deepCopy(base)
	local style = DriftStyles.styles[id]
	if style then
		deepMerge(cfg, style.tuning)
		cfg.drivetrain.layout = style.layout
	end
	return cfg
end

return DriftStyles
```

(Return type `any` keeps strict mode out of the deep copy; callers annotate `CarConfig.Config`.)

- [ ] **Step 4: CarCatalog lines** (our lines, the hash-object routine). In `kamri07.tuning` and `hatch.tuning` add (at the top of `tuning`):

```lua
			-- Front-wheel drive, as the real car (drift styles: DriftStyles).
			drivetrain = { layout = "FWD" },
```

`hatch.tuning` may already have keys; merge into its existing `drivetrain` table if one exists. In `batrol.tuning` and `kruzer80.tuning`:

```lua
			-- Four-wheel drive, as the real truck; the split is the drift
			-- style's (DriftStyles).
			drivetrain = { layout = "AWD" },
```

Commit routine: back up the working copy, build the staged file from HEAD with only these blocks added (script it with Python: read HEAD's text, insert the same lines at the same anchors), `git hash-object -w`, `git update-index --cacheinfo 100644,<sha>,src/shared/CarCatalog.luau`; then apply the same insertions to the working copy; `git diff --stat src/shared/CarCatalog.luau` shows only the owner's lines unstaged.

- [ ] **Step 5: Run specs** — Expected: DriftStyles.spec passes; 14 failures total.

- [ ] **Step 6: Commit**

```bash
git add src/shared/DriftStyles.luau src/shared/Tests/DriftStyles.spec.luau   # CarCatalog already staged by cacheinfo
git commit -m "Drift styles: seven presets over three drivetrains; the cars' real drivetrains"
```

---

### Task 4: Picking a style in game

**Files:**
- Create: `src/client/DriftStyle.luau`
- Modify: `src/client/VehicleController.luau`
- Modify: `src/client/SettingsPanel.luau`
- Modify: `src/client/init.client.luau` (start it)

**Interfaces:**
- Consumes: `DriftStyles.*` (Task 3), `ConfigLoader.forCar(carId)`.
- Produces: `DriftStyle.current(layout: string): string`, `DriftStyle.set(id: string)`, `DriftStyle.forCar(carId: string?): string`, `DriftStyle.configFor(carId: string?): CarConfig.Config`, `DriftStyle.clearCache()`, `DriftStyle.setCar(carId: string?)`, `DriftStyle.carLayout(): string`, `DriftStyle.changed: (() -> ())?`, `DriftStyle.panelChanged: (() -> ())?`, `DriftStyle.start()`.

- [ ] **Step 1: Write `DriftStyle.luau`**

```lua
--!strict
-- Which drift style this player drives (DriftStyles). One choice per
-- drivetrain, kept as LocalPlayer attributes (DriftStyle_RWD, _FWD, _AWD)
-- for the session, so swapping cars keeps it; not saved to the profile
-- until the owner picks the styles to keep (2026-10-05).
--
-- The menu's Settings tab sets it (SettingsPanel). In Studio only, O
-- cycles the current car's styles and Shift+O every style (for comparing
-- drivetrains on one car: the DriftStyleAny attribute; O clears it), with
-- the choice shown at the top of the screen for a moment.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigLoader = require(Shared:WaitForChild("ConfigLoader"))
local DriftStyles = require(Shared:WaitForChild("DriftStyles"))
local UITheme = require(Shared:WaitForChild("UITheme"))

local DriftStyle = {}

-- The sim swaps its config when the choice changes (VehicleController);
-- the Settings tab repaints.
DriftStyle.changed = nil :: (() -> ())?
DriftStyle.panelChanged = nil :: (() -> ())?

local ANY = "DriftStyleAny"
local LABEL_SECONDS = 1.5

local car: string? = nil
local cache: { [string]: ConfigLoader.Config } = {}

local function attr(layout: string): string
	return "DriftStyle_" .. layout
end

local function player(): Player
	return Players.LocalPlayer
end

-- The layout of the car this client drives, or of the last one (RWD before any).
function DriftStyle.carLayout(): string
	return DriftStyles.layoutOf(ConfigLoader.forCar(car))
end

function DriftStyle.current(layout: string): string
	return DriftStyles.resolve(layout, player():GetAttribute(attr(layout)))
end

-- The style a car drives on: Studio's any-layout pick if one is set, else
-- this player's choice for the car's layout.
function DriftStyle.forCar(carId: string?): string
	local any = player():GetAttribute(ANY)
	if RunService:IsStudio() and type(any) == "string" and DriftStyles.styles[any] then
		return any
	end
	return DriftStyle.current(DriftStyles.layoutOf(ConfigLoader.forCar(carId)))
end

function DriftStyle.configFor(carId: string?): ConfigLoader.Config
	local id = ConfigLoader.resolveCarId(carId)
	local styleId = DriftStyle.forCar(id)
	local key = id .. "|" .. styleId
	local cfg = cache[key]
	if not cfg then
		cfg = DriftStyles.apply(ConfigLoader.forCar(id), styleId) :: ConfigLoader.Config
		cache[key] = cfg
	end
	return cfg
end

-- After a config reload: the styled configs are rebuilt from the new ones.
function DriftStyle.clearCache()
	table.clear(cache)
end

function DriftStyle.setCar(carId: string?)
	if carId then
		car = carId
	end
	if DriftStyle.panelChanged then
		DriftStyle.panelChanged()
	end
end

local function notify()
	if DriftStyle.changed then
		DriftStyle.changed()
	end
	if DriftStyle.panelChanged then
		DriftStyle.panelChanged()
	end
end

-- Pick a style (for its own layout); clears Studio's any-layout pick.
function DriftStyle.set(id: string)
	local style = DriftStyles.styles[id]
	if not style then
		return
	end
	player():SetAttribute(ANY, nil)
	player():SetAttribute(attr(style.layout), id)
	notify()
end

-- The label, top centre for a moment (Studio switch).
local labelToken = 0
local function showLabel(id: string)
	local style = DriftStyles.styles[id]
	local gui = player():WaitForChild("PlayerGui") :: PlayerGui
	local screen = gui:FindFirstChild("DriftStyleLabel") :: ScreenGui?
	if not screen then
		local s = Instance.new("ScreenGui")
		s.Name = "DriftStyleLabel"
		s.ResetOnSpawn = false
		s.DisplayOrder = 50
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, 64)
		l.Size = UDim2.new(0, 520, 0, 34)
		l.BackgroundTransparency = 1
		l.FontFace = UITheme.font("title")
		l.TextColor3 = UITheme.color.paint
		l.TextSize = UITheme.textSize("title", false)
		l.Parent = s
		s.Parent = gui
		screen = s
	end
	local label = (screen :: ScreenGui):FindFirstChild("Text") :: TextLabel
	label.Text = `DRIFT: {string.upper(style.name)} ({style.layout})`
	label.Visible = true
	labelToken += 1
	local mine = labelToken
	task.delay(LABEL_SECONDS, function()
		if labelToken == mine then
			label.Visible = false
		end
	end)
end

local function cycle(all: boolean)
	local current = DriftStyle.forCar(car)
	local list = if all then DriftStyles.order else DriftStyles.forLayout(DriftStyle.carLayout())
	local i = table.find(list, current) or 0
	local nextId = list[i % #list + 1]
	if all then
		player():SetAttribute(ANY, nextId)
		notify()
	else
		DriftStyle.set(nextId)
	end
	showLabel(nextId)
end

function DriftStyle.start()
	if RunService:IsStudio() then
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or input.KeyCode ~= Enum.KeyCode.O then
				return
			end
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			cycle(shift)
		end)
	end
end

return DriftStyle
```

(Check `UITheme.font`, `UITheme.color.paint`, `UITheme.textSize` names against `ExhaustPops`' label before writing; use exactly what it uses.)

- [ ] **Step 2: `VehicleController`**: require `DriftStyle`; in `start`, `DriftStyle.setCar(carId)` and build the sim with `DriftStyle.configFor(carId)`; set `DriftStyle.changed = function() if sim then sim:setConfig(DriftStyle.configFor(carId)) end end`; in `setConfig`, `DriftStyle.clearCache()` then `sim:setConfig(DriftStyle.configFor(carId))`; `AutoFlip.step` keeps `ConfigLoader.forCar(carId)`.

- [ ] **Step 3: `init.client.luau`**: `local DriftStyle = require(script.DriftStyle)` and `DriftStyle.start()` beside `ExhaustPops.start(remotes)`.

- [ ] **Step 4: `SettingsPanel`**: a second section under the time of day:
  - heading text `DRIFT STYLE · <LAYOUT NAME uppercase>` (title role, paint), LayoutOrder 4;
  - a row (LayoutOrder 5) of `UIKit.chip` buttons, one per `DriftStyles.forLayout(DriftStyle.carLayout())`, rebuilt when the layout changes (`DriftStyle.panelChanged`), `Activated` → `DriftStyle.set(id)`;
  - a caption (LayoutOrder 6, caption role, sandDim): the chosen style's blurb, wrapping (`TextWrapped = true`), two lines tall;
  - `paint()` also marks the chosen drift chip with `UIKit.setSelected`;
  - `SettingsPanel.height` adds `headH + rowH + 2 * noteH + 8 * 3`; `fit` sizes the new rows like the sky ones.

- [ ] **Step 5: Type check**, then **Play**: open the menu (M), Settings tab: the section shows the car's drivetrain and its styles; pick one, drive, the label/chip follows; O and Shift+O in Studio; L reload keeps the style (the reloaded config still has the style's `drift` numbers: check by reading the sim's behaviour, e.g. the High Angle hold).

- [ ] **Step 6: Screenshots** of the Settings section on the Kamri (FWD) and the Krown Vik (RWD).

- [ ] **Step 7: Commit**

```bash
git add src/client/DriftStyle.luau src/client/VehicleController.luau src/client/SettingsPanel.luau src/client/init.client.luau
git commit -m "Drift styles in game: the Settings tab, Studio O / Shift+O"
```

---

### Task 5: The drift flutter

**Files:**
- Modify: `src/shared/ExhaustStyles.luau` (`Style.flutter: Pattern`, a pattern per style, `KIND.flutter = 4`, `relayPerSecond = 12`, `validRelay`)
- Modify: `src/shared/Tests/ExhaustStyles.spec.luau`
- Modify: `src/client/ExhaustPops.luau` (`flutter(model)`, `burst(..., flutter)`, the relay)
- Modify: `src/client/EngineAudio.luau` (`onFlutter`)
- Modify: `src/shared/CarConfig.luau` (`engineAudio.driftFlutterFromDeg`, `driftFlutterMinKmh`)
- Modify: `src/client/init.client.luau` (wire `onFlutter`)

**Interfaces:**
- Produces: `ExhaustStyles.KIND.flutter == 4`; `ExhaustPops.flutter(model: Model)`; `EngineAudio.onFlutter: ((model: Model) -> ())?`.

- [ ] **Step 1: Failing spec cases** (append to `ExhaustStyles.spec.luau`)

```lua
	-- The drift flutter: every style has one, dense at the start, ending in its window
	for _, id in ExhaustStyles.order do
		local style = ExhaustStyles.styles[id]
		local p = style.flutter
		t.ok(p ~= nil, `{id} has a flutter`)
		if p then
			local worstFirstGap = 0
			for seed = 1, 40 do
				local pops = ExhaustSputter.generate(p, seed, 1)
				t.ok(pops[#pops].t <= p.maxSeconds + 1e-9, `{id} flutter ends inside maxSeconds (seed {seed})`)
				if #pops >= 3 then
					worstFirstGap = math.max(worstFirstGap, (pops[3].t - pops[1].t) / 2)
				end
				t.ok(#pops >= 3, `{id} flutter has at least three pops (seed {seed})`)
			end
			t.ok(worstFirstGap <= 0.09, `{id} flutter's first pops come 90 ms apart or closer (worst {worstFirstGap})`)
		end
	end
	t.eq(ExhaustStyles.KIND.flutter, 4, "the flutter is relay kind 4")
	t.ok(ExhaustStyles.validRelay(4, 1, 123, 1), "a flutter relays like a burst")
	t.ok(not ExhaustStyles.validRelay(4, 0, 123, 1), "a flutter names a style")
	t.ok(not ExhaustStyles.validRelay(5, 1, 123, 1), "kind 5 does not exist")
	-- Feathering four times a second sends a flutter and a cut each time
	t.ok(ExhaustStyles.relayPerSecond >= 4 * 2 + 2, "the budget covers four feathers a second with room")
```

(`ExhaustSputter` is already required in that spec; if not, add `local ExhaustSputter = require(Shared.ExhaustSputter)`.) For Classic's uniform flutter the "first pops" check uses its `spanSeconds`; Classic's flutter is a burble too (below), so it holds.

- [ ] **Step 2: Run — Expected: FAIL** (no `flutter`, no kind 4).

- [ ] **Step 3: ExhaustStyles**: `Style` gains

```lua
	-- The drift flutter (the owner, 2026-10-05: "kick off the exhaust during
	-- a drift where the flames would also flutter like in drifting videos"):
	-- what a lift fires when the car is sideways. Dense, mostly small pops,
	-- so their flames overlap into a flickering tongue; the gas back on cuts
	-- it, so feathering flutters the flames in time with the driver's foot.
	flutter: Pattern,
```

and each style its pattern:

```lua
-- crackle
		flutter = {
			kind = "burble", count = { 8, 12 }, maxPops = 18, minGap = 0.012, maxSeconds = 1.0,
			first = "mid",
			weightsStart = { small = 0.55, mid = 0.4, big = 0.05 },
			weightsEnd = { small = 0.85, mid = 0.15, big = 0 },
			fade = 0.5, levelJitter = 0.45,
			gapStart = { 0.03, 0.05 }, gapEnd = { 0.08, 0.14 }, jitter = 0.4,
			doubleChance = 0.25, doubleGap = { 0.015, 0.03 },
		},
-- blue
		flutter = {
			kind = "burble", count = { 6, 10 }, maxPops = 14, minGap = 0.02, maxSeconds = 0.8,
			first = "mid",
			weightsStart = { small = 0.35, mid = 0.6, big = 0.05 },
			weightsEnd = { small = 0.6, mid = 0.4, big = 0 },
			fade = 0.6, levelJitter = 0.3,
			gapStart = { 0.04, 0.05 }, gapEnd = { 0.06, 0.08 }, jitter = 0.2,
		},
-- twostep
		flutter = {
			kind = "burble", count = { 6, 10 }, maxPops = 14, minGap = 0.04, maxSeconds = 0.9,
			first = "mid",
			weightsStart = { small = 0.2, mid = 0.8, big = 0 },
			weightsEnd = { small = 0.2, mid = 0.8, big = 0 },
			fade = 0.8, levelJitter = 0.1,
			gapStart = { 0.06, 0.06 }, gapEnd = { 0.06, 0.06 }, jitter = 0.06,
		},
-- classic
		flutter = {
			kind = "burble", count = { 3, 5 }, maxPops = 8, minGap = 0.04, maxSeconds = 0.6,
			weightsStart = { small = 0, mid = 1, big = 0 },
			weightsEnd = { small = 0, mid = 1, big = 0 },
			fade = 0.8, levelJitter = 0.45,
			gapStart = { 0.04, 0.05 }, gapEnd = { 0.05, 0.07 }, jitter = 0.2,
		},
```

`KIND = { burst = 1, single = 2, cut = 3, flutter = 4 }`; `relayPerSecond = 12` with the comment updated (a fast feather is a flutter and a cut each time, 8 at four feathers a second); `validRelay` accepts `K.flutter` alongside burst and single.

- [ ] **Step 4: ExhaustPops**: `burst(model, styleId, seed, scale, item, flutter: boolean?)` generates from `if flutter then style.flutter else style.pattern`; new

```lua
-- The driver lifted while sideways: the style's flutter instead of its
-- burst, sent on as a flutter so every client rebuilds the same one.
function ExhaustPops.flutter(model: Model)
	local styleId = ExhaustPops.styleId()
	local style = ExhaustStyles.styles[styleId]
	local scale = ExhaustStyles.scaleFor(style, exhaustItem(model).crackleChance or 1, 1)
	local seed = rng:NextInteger(1, 2 ^ 31 - 1)
	burst(model, styleId, seed, scale, nil, true)
	send(KIND.flutter, ExhaustStyles.index(styleId) or 1, seed, scale)
end
```

and in `OnClientEvent`: `burst(model, styleId, seed, scale, nil, kind == KIND.flutter)`. Header comment: the driver's lift in a slide flutters.

- [ ] **Step 5: CarConfig `engineAudio`** (beside `crackleLiftFrom`):

```lua
			-- The drift flutter: a lift with the car this far sideways, this
			-- fast, fires the exhaust style's flutter instead of its burst
			-- (ExhaustStyles), at any revs. Feathering mid-drift flutters the
			-- flames (the owner, 2026-10-05); the drift carries on (drift.feather).
			driftFlutterFromDeg = 12,
			driftFlutterMinKmh = 40,
```

- [ ] **Step 6: EngineAudio**: `EngineAudio.onFlutter = nil :: ((model: Model) -> ())?`; replace the lift branch with

```lua
		local lifted = lastLoad >= audio.crackleLiftFrom and throttle < 0.1
		local sideways = math.abs(state.driftAngleDeg) >= audio.driftFlutterFromDeg
			and math.abs(state.speedKmh) >= audio.driftFlutterMinKmh
		if lifted and sideways and EngineAudio.onFlutter then
			EngineAudio.onFlutter(model)
		elseif lifted and fast and EngineAudio.onLift then
			EngineAudio.onLift(model, ExhaustStyles.revFactor(simRpm, audio.crackleMinRpm, drive.redlineRpm, audio.crackleRevFloor))
		end
```

- [ ] **Step 7: init.client**: `EngineAudio.onFlutter = function(model: Model) ExhaustPops.flutter(model) end`.

- [ ] **Step 8: Specs, type check.** Expected: pass; 14 failures.

- [ ] **Step 9: Play**: hold a slide, feather three times; read the console for errors; count the chassis's ExhaustPop sounds playing and the emitters' emission per feather; a screenshot mid-flutter from the chase camera (freeze with TimeScale per BEHAVIOURS) on two styles.

- [ ] **Step 10: Commit**

```bash
git add src/shared/ExhaustStyles.luau src/shared/Tests/ExhaustStyles.spec.luau src/client/ExhaustPops.luau src/client/EngineAudio.luau src/shared/CarConfig.luau src/client/init.client.luau
git commit -m "Drift flutter: a lift mid-drift flutters the exhaust; relayed as its own kind"
```

---

### Task 6: Tune and measure every style in Play

**Files:**
- Modify: `src/shared/DriftStyles.luau` (numbers only), `src/shared/CarConfig.luau` (`drift` defaults if Classic moves)

- [ ] **Step 1:** For each style on a car of its layout (RWD: kamri07 forced with Shift+O and a Krown Vik; FWD: kamri07; AWD: batrol), run the harness suite: launch, handbrake, held (and its 4 s speed), feather, flick, power-over, 360, catch, chain; plus the natl tap at 105 (0.2 s lean tap, peak roll and time down) on the FWD Kamri and the AWD Batrol against RWD.
- [ ] **Step 2:** Default styles (Classic, Handbrake, Rally) must keep: handbrake to 20 within 0.05 s of baseline; lever 360 within 0.3 s and 8 km/h; catch within 0.35 s; chain angles within the baseline's spread; natl tap peak within 8 degrees and time down within 1 s. Move a style's numbers when one misses; record each change and why.
- [ ] **Step 3:** The other styles must each show their trait in numbers: Power Over a power-over drift at 50 km/h past 20 degrees and a kick of 10+ degrees; High Angle a held angle of 40-60; Lift-Off a slide from a lift alone past 20 degrees; Drift Mode a held slide like Classic's; Rally a held angle at or under ~35 and less speed lost than Classic.
- [ ] **Step 4:** Commit the tuned numbers with the measurements in the message.

```bash
git add src/shared/DriftStyles.luau src/shared/CarConfig.luau
git commit -m "Drift styles tuned in Play"
```

---

### Task 7: Docs and the final pass

**Files:**
- Modify: `TUNING.md` (drivetrain layout rows, a `drift` section, a DriftStyles section with the measured table, engineAudio driftFlutter rows, ExhaustStyles flutter + relay budget)
- Modify: `DESIGN.md` (a "Drivetrains and drift styles" section: why real layouts, why the lever is untouched, the feather; the measured table)
- Modify: `BRANCH_STATUS.md` (the `drift-feel` branch)
- Modify: `BEHAVIOURS.md` (any engine lesson met on the way)

- [ ] **Step 1:** Write the docs from the Task 6 measurements.
- [ ] **Step 2:** Full specs, type check.
- [ ] **Step 3:** Commit.

```bash
git add TUNING.md DESIGN.md BRANCH_STATUS.md BEHAVIOURS.md
git commit -m "Drift feel: docs"
```
