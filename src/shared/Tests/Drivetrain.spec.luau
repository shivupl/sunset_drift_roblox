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
	}
	local kick = { multiplier = 2.5, duration = 0.3 }
	local r = 0.33
	local dt = 1 / 60

	-- Standstill, full throttle, gear 1: rpm idle, torque from curve at idle
	local st = Drivetrain.new(cfg)
	local out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 0, false)
	t.eq(out.gear, 1, "starts in gear 1")
	t.near(out.rpm, 900, 1e-9, "idle rpm at standstill")
	local torqueAtIdle = 200 -- curve clamps below 1000
	t.near(out.torque, torqueAtIdle, 1e-9, "torque from curve")
	t.near(out.drivePerRearWheel, torqueAtIdle * 3.5 * 3.9 * 0.9 / r / 2, 1e-6, "drive force per wheel")

	-- 20 m/s in gear 1: rpm from wheels ~7900 -> clamps to redline, upshifts
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 20, false)
	t.eq(out.gear, 2, "upshifts above upshiftRpm")
	t.near(out.torque, 0, 1e-9, "torque cut during shift")

	-- Clutch kick edge multiplies torque for its duration
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, true, 5, false)
	local base = Drivetrain.step(Drivetrain.new(cfg), cfg, kick, r, dt, 1, 0, false, 5, false)
	t.near(out.torque, base.torque * 2.5, 1e-6, "kick multiplies torque")
	out = Drivetrain.step(st, cfg, kick, r, 0.31, 1, 0, true, 5, false) -- held, timer expires
	t.near(out.torque, base.torque, 1e-6, "kick expires and does not retrigger while held")

	-- Engine brake on lift
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 0, false, 10, false)
	t.ok(out.engineBrakePerRearWheel > 0, "engine brake when lifted")
	t.near(out.drivePerRearWheel, 0, 1e-9, "no drive when lifted")

	-- Brakes split by bias
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 1, false, 10, false)
	t.near(out.brakePerFrontWheel, 14000 * 0.65 / 2, 1e-9, "front brake")
	t.near(out.brakePerRearWheel, 14000 * 0.35 / 2, 1e-9, "rear brake")

	-- Reverse: brake held at standstill with no throttle engages reverse, drive is negative
	st = Drivetrain.new(cfg)
	out = Drivetrain.step(st, cfg, kick, r, dt, 0, 1, false, 0, false)
	t.eq(out.gear, -1, "enters reverse")
	t.ok(out.drivePerRearWheel < 0, "reverse drive is negative")
	t.near(out.brakePerRearWheel, 0, 1e-9, "brake pedal drives in reverse")
	out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, -0.2, false)
	t.eq(out.gear, 1, "throttle from near-standstill leaves reverse")

	-- Wheelspin: rpm floats up toward redline
	st = Drivetrain.new(cfg)
	for _ = 1, 30 do
		out = Drivetrain.step(st, cfg, kick, r, dt, 1, 0, false, 5, true)
	end
	t.ok(out.rpm > 3000, "rpm climbs while spinning")
	t.eq(out.gear, 1, "spin does not upshift")
end
