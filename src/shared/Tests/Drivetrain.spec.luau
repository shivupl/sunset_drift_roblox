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
	}
	local r = 0.33
	local dt = 1 / 60

	-- Standstill, full throttle, gear 1: rpm idle, torque from curve at idle
	local st = Drivetrain.new(cfg)
	local out = Drivetrain.step(st, cfg, r, dt, 1, 0, 0, false)
	t.eq(out.gear, 1, "starts in gear 1")
	t.near(out.rpm, 900, 1e-9, "idle rpm at standstill")
	local torqueAtIdle = 200 -- curve clamps below 1000
	t.near(out.torque, torqueAtIdle, 1e-9, "torque from curve")
	t.near(out.drivePerRearWheel, torqueAtIdle * 3.5 * 3.9 * 0.9 / r / 2, 1e-6, "drive force per wheel")

	-- 20 m/s in gear 1: rpm from wheels ~7900 -> clamps to redline, upshifts
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, 20, false)
	t.eq(out.gear, 2, "upshifts above upshiftRpm")
	t.near(out.torque, 0, 1e-9, "torque cut during shift")

	-- Engine brake on lift
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 0, 0, 10, false)
	t.ok(out.engineBrakePerRearWheel > 0, "engine brake when lifted")
	t.near(out.drivePerRearWheel, 0, 1e-9, "no drive when lifted")

	-- Brakes split by bias
	out = Drivetrain.step(st, cfg, r, dt, 0, 1, 10, false)
	t.near(out.brakePerFrontWheel, 14000 * 0.65 / 2, 1e-9, "front brake")
	t.near(out.brakePerRearWheel, 14000 * 0.35 / 2, 1e-9, "rear brake")

	-- Reverse needs the brake held at a standstill for reverseHoldSeconds, so
	-- that stopping on the brakes stays in drive.
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false)
	t.eq(out.gear, 1, "one frame of brake does not select reverse")
	local elapsed, guard = dt, 0
	while out.gear ~= -1 and guard < 600 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false)
		elapsed += dt
		guard += 1
	end
	t.eq(out.gear, -1, "the brake held at a standstill selects reverse")
	t.near(elapsed, cfg.reverseHoldSeconds, dt * 1.5, "after about reverseHoldSeconds")
	t.ok(out.drivePerRearWheel < 0, "reverse drive is negative")
	t.near(out.brakePerRearWheel, 0, 1e-9, "brake pedal drives in reverse")
	out = Drivetrain.step(st, cfg, r, dt, 1, 0, -0.2, false)
	t.eq(out.gear, 1, "throttle from near-standstill leaves reverse")

	-- Braking to a stop from speed stays in drive: the hold only counts once
	-- the car is actually stopped, and letting off resets it.
	st = Drivetrain.new(cfg)
	for _ = 1, 60 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 5, false) -- still rolling
	end
	t.eq(out.gear, 1, "braking while moving never selects reverse")
	for _ = 1, 10 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false)
	end
	out = Drivetrain.step(st, cfg, r, dt, 0, 0, 0, false) -- let off before the hold completes
	for _ = 1, 10 do
		out = Drivetrain.step(st, cfg, r, dt, 0, 1, 0, false)
	end
	t.eq(out.gear, 1, "releasing the brake restarts the hold")

	-- Wheelspin: rpm floats up toward redline
	st = Drivetrain.new(cfg)
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg, r, dt, 1, 0, 5, true)
	end
	t.ok(out.rpm > 3000, "rpm climbs while spinning")
	t.eq(out.gear, 1, "spin does not upshift")
end
