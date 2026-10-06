--!strict
local Drivetrain = require(script.Parent.Parent.VehicleSim.Drivetrain)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = {
		torqueCurve = { { 1000, 200 }, { 4000, 300 }, { 7000, 0 } },
		gearRatios = { 3.5, 2.1, 1.4 },
		reverseRatio = 3.2,
		finalDrive = 3.9,
		drivelineEfficiency = 0.9,
		idleRpm = 900,
		redlineRpm = 6800,
		upshiftRpm = 6400,
		downshiftRpm = 3000,
		shiftTime = 0.15,
		spinRpmRate = 6000,
		engineBrakeTorque = 40,
		brakeForce = 14000,
		brakeBias = 0.65,
		brakeFadeMps = 0.5,
		reverseEngageMps = 0.5,
		reverseHoldSeconds = 0.4,
		-- Inside this three-gear box's range: gear 3 hits the rev limiter
		-- near 160, which would mask the limiter this tests.
		topSpeedKmh = 140,
		topSpeedFadeKmh = 20,
		tractionControlBelowKmh = 120,
		tractionControlMaxDriftDeg = 8,
		tractionControlMin = 0.35,
		tractionControlCutRate = 5,
		tractionControlRecoverRate = 1.2,
		slideShift = false,
	}
	local r = 0.33
	local dt = 1 / 60

	-- Standstill, full throttle, gear 1: rpm idle, torque from curve at idle
	local st = Drivetrain.new(cfg)
	local out = Drivetrain.step(st, cfg, r, dt, 1, 0, 0, false, true)
	t.eq(out.gear, 1, "starts in gear 1")
	t.near(out.rpm, 900, 1e-9, "idle rpm at standstill")
	local torqueAtIdle = 200 -- curve clamps below 1000
	t.near(out.torque, torqueAtIdle, 1e-9, "torque from curve")
	t.near(out.drivePerRearWheel, torqueAtIdle * 3.5 * 3.9 * 0.9 / r / 2, 1e-6, "drive force per wheel")

	-- 20 m/s in gear 1: rpm from wheels ~7900 -> clamps to redline, upshifts
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 20, false, true)
	t.eq(out.gear, 2, "upshifts above upshiftRpm")
	t.near(out.torque, 0, 1e-9, "torque cut during shift")

	-- Engine brake on lift
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 0, 0, 10, false, true)
	t.ok(out.engineBrakePerRearWheel > 0, "engine brake when lifted")
	t.near(out.drivePerRearWheel, 0, 1e-9, "no drive when lifted")

	-- Brakes split by bias
	out = Drivetrain.step(st, cfg, r, dt, 0, 1, 10, false, true)
	t.near(out.brakePerFrontWheel, 14000 * 0.65 / 2, 1e-9, "front brake")
	t.near(out.brakePerRearWheel, 14000 * 0.35 / 2, 1e-9, "rear brake")

	-- Reverse needs the brake held at a standstill for reverseHoldSeconds, so
	-- that stopping on the brakes stays in drive.
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false, true)
	t.eq(out.gear, 1, "one frame of brake does not select reverse")
	local elapsed, guard = dt, 0
	while out.gear ~= -1 and guard < 600 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false, true)
		elapsed += dt
		guard += 1
	end
	t.eq(out.gear, -1, "the brake held at a standstill selects reverse")
	t.near(elapsed, cfg.reverseHoldSeconds, dt * 1.5, "after about reverseHoldSeconds")
	t.ok(out.drivePerRearWheel < 0, "reverse drive is negative")
	t.near(out.brakePerRearWheel, 0, 1e-9, "brake pedal drives in reverse")
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, -0.2, false, true)
	t.eq(out.gear, 1, "throttle from near-standstill leaves reverse")

	-- Braking to a stop from speed stays in drive: the hold only counts once
	-- the car is actually stopped, and letting off resets it.
	st = Drivetrain.new(cfg)
	for _ = 1, 60 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 5, false, true) -- still rolling
	end
	t.eq(out.gear, 1, "braking while moving never selects reverse")
	for _ = 1, 10 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false, true)
	end
	out = Drivetrain.step(st, cfg, r, dt, 0, 0, 0, false, true) -- let off before the hold completes
	for _ = 1, 10 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false, true)
	end
	t.eq(out.gear, 1, "releasing the brake restarts the hold")

	-- Top speed limiter: full drive well under it, fading to none at it.
	-- The box needs a few steps to shift up to the right gear at each speed.
	local function settled(mps: number)
		local state = Drivetrain.new(cfg)
		local o
		for _ = 1, 60 do
			o = Drivetrain.step(state, cfg, r, dt, 1, 0, mps, false, true)
		end
		return o
	end
	local under = settled(100 / 3.6)
	local mid = settled(130 / 3.6)
	local at = settled(140 / 3.6)
	t.ok(under.drivePerRearWheel > 0, "drive under the fade band")
	t.ok(mid.drivePerRearWheel > 0 and mid.drivePerRearWheel < under.drivePerRearWheel, "drive fades inside the band")
	t.near(at.drivePerRearWheel, 0, 1e-6, "no drive at the ceiling")

	-- Wheelspin: rpm floats up toward redline
	st = Drivetrain.new(cfg)
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg, r, dt, 1, 0, 5, true, true)
	end
	t.ok(out.rpm > 3000, "rpm climbs while spinning")
	t.eq(out.gear, 1, "spin does not upshift")

	-- In a slide the box goes by the engine's own rpm, spin included, and
	-- only upward: 2nd at 16 m/s is about 3900 by road speed, but the rears
	-- spin the engine to 6600. Driving straight the same spin stays put.
	local function inSecond(): Drivetrain.State
		local state = Drivetrain.new(cfg)
		state.gear = 2
		return state
	end
	local spinMps = 6600 / (2.1 * 3.9 * 60 / (2 * math.pi)) * r -- wheel surface speed for 6600 in 2nd
	cfg.slideShift = true
	st = inSecond()
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 16, true, false, spinMps, true)
	t.eq(out.gear, 3, "sliding: spin to the upshift rpm shifts up")
	st = inSecond()
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 16, true, false, spinMps, false)
	t.eq(out.gear, 2, "straight: the same spin does not shift")
	-- 2nd at 5 m/s is about 1200 by road speed, under downshiftRpm.
	st = inSecond()
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 5, false, false, 5, true)
	t.eq(out.gear, 2, "sliding: never shifts down")
	-- One upshift per slide: once in 3rd, spin to the upshift rpm in 3rd
	-- does not take it to 4th. Ending the slide re-arms it.
	st = inSecond()
	Drivetrain.step(st, cfg, r, dt, 1, 0, 16, true, false, spinMps, true)
	local spin3 = 6600 / (1.4 * 3.9 * 60 / (2 * math.pi)) * r
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg, r, dt, 1, 0, 16, true, false, spin3, true)
	end
	t.eq(out.gear, 3, "sliding: one upshift per slide")
	-- This box has three gears; a four-gear copy shows a new slide re-arms.
	local cfg4 = table.clone(cfg)
	cfg4.gearRatios = { 3.5, 2.1, 1.4, 1.0 }
	out = Drivetrain.step(st, cfg4, r, dt, 1, 0, 30, false, false, 30, false)
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg4, r, dt, 1, 0, 30, true, false, spin3 * 1.1, true)
	end
	t.eq(out.gear, 4, "a new slide may shift up once more")
	cfg.slideShift = false
	st = inSecond()
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 16, true, false, spinMps, true)
	t.eq(out.gear, 2, "slideShift off: the old box")

	-- Axle shares by layout
	local function shares(over: { [string]: any }): (number, number)
		local c = table.clone(cfg) :: any
		for k, v in over do
			c[k] = v
		end
		return Drivetrain.axleShares(c)
	end
	local f, rr = shares({})
	t.eq(f, 0, "no layout is rear drive: nothing to the front")
	t.eq(rr, 1, "no layout is rear drive: everything to the rear")
	f, rr = shares({ layout = "FWD", frontShare = 0.3 })
	t.eq(f, 1, "front drive sends everything to the front, whatever frontShare says")
	t.eq(rr, 0, "front drive sends nothing to the rear")
	f, rr = shares({ layout = "AWD", frontShare = 0.3 })
	t.near(f, 0.3, 1e-12, "all-wheel drive splits by frontShare")
	t.near(rr, 0.7, 1e-12, "the rest to the rear")
	f, rr = shares({ layout = "AWD", frontShare = 1.4 })
	t.eq(f, 1, "frontShare clamps to 1")
	f, rr = shares({ layout = "RWD", frontShare = 0.5 })
	t.eq(f, 0, "rear drive ignores frontShare")

	-- Launch cap: on rear drive it is exactly the formula VehicleSim used inline
	local args = {
		mass = 1600,
		use = 1.0,
		wheelInertia = 1.4,
		engineInertia = 0.15,
		overall = 3.5 * 3.9,
		efficiency = 0.9,
		radius = 0.33,
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

	-- powerScale multiplies the engine's torque (speed-feel, 2026-10-05: the
	-- owner wanted the driving "at least 50% faster")
	local function torqueAt(c: any): number
		local s0 = Drivetrain.new(c)
		return Drivetrain.step(s0, c, r, dt, 1, 0, 10, false, false).torque
	end
	local base = torqueAt(cfg)
	local scaled = table.clone(cfg) :: any
	scaled.powerScale = 1.5
	t.near(torqueAt(scaled), base * 1.5, 1e-9, "powerScale 1.5: half again the torque")
	t.near(Drivetrain.torqueAt(scaled, 4000), 450, 1e-9, "torqueAt is the curve times powerScale")
	t.near(Drivetrain.torqueAt(cfg, 4000), 300, 1e-9, "no powerScale: the curve")

	-- launchGrip: the driven tyres' drive grip off the line, pointing
	-- straight, fading to nothing between launchGripFullKmh and launchGripEndKmh
	local lg = table.clone(cfg) :: any
	lg.launchGrip = 1.4
	lg.launchGripFullKmh = 60
	lg.launchGripEndKmh = 140
	t.near(Drivetrain.launchGrip(lg, 30, true), 1.4, 1e-9, "off the line: the whole boost")
	t.near(Drivetrain.launchGrip(lg, 100, true), 1.2, 1e-9, "halfway through the fade: half")
	t.near(Drivetrain.launchGrip(lg, 150, true), 1, 1e-9, "past the fade: none")
	t.near(Drivetrain.launchGrip(lg, 30, false), 1, 1e-9, "sideways, the lever in or on two wheels: none (drifts untouched)")
	t.near(Drivetrain.launchGrip(cfg, 30, true), 1, 1e-9, "no launchGrip: none")
end
