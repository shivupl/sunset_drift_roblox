--!strict
local Wheel = require(script.Parent.Parent.VehicleSim.Wheel)
local Tire = require(script.Parent.Parent.VehicleSim.Tire)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local axle = {
		grip = 1.0, peakSlipDeg = 8, riseShape = 1, slideSlipDeg = 24, slideGripRatio = 0.7, falloffShape = 1,
		deepSlideSlipDeg = 90, deepSlideGripRatio = 0.7, longitudinalGrip = 1.5,
	}
	local cfg = {
		enabled = true, peakSlipRatio = 0.1, lowSpeedMps = 3, loadSensitivity = 0.1, loadFactorMin = 0.5, loadFactorMax = 1.5,
		wheelInertia = 1.2, engineInertia = 0, substepSeconds = 0.002, handbrakeTorque = 0, handbrakeGripCut = 1, flickRearGripMultiplier = 1, launchGripUse = 1,
		slideRelief = 0, leverRelief = 0,
	}
	local r = 0.33
	local fMax = 4000

	-- A free-rolling wheel sideways matches the legacy tyre exactly.
	local v = 30
	local vLat = v * math.tan(math.rad(12))
	local rolling = Wheel.force(cfg, axle, v, vLat, v / r, r, fMax)
	t.near(rolling.slipRatio, 0, 1e-9, "rolling wheel has no slip ratio")
	t.near(math.abs(rolling.fy), fMax * Tire.gripCurve(12, axle), 1e-6, "pure slip angle is the legacy grip curve")
	t.near(rolling.fx, 0, 1e-6, "and no longitudinal force")
	t.ok(rolling.fy < 0, "lateral force opposes the sideways motion")

	-- Wheelspin in a slide: force swings forward, the tail's hold drops.
	local spinning = Wheel.force(cfg, axle, v, vLat, v * 1.3 / r, r, fMax)
	t.ok(spinning.fx > 0, "a spinning wheel pushes forward")
	t.ok(math.abs(spinning.fy) < math.abs(rolling.fy), "and holds less sideways, so the tail hangs out")

	-- Locked: drags backward and lets go sideways.
	local locked = Wheel.force(cfg, axle, v, vLat, 0, r, fMax)
	t.ok(locked.fx < 0, "a locked wheel drags")
	t.ok(math.abs(locked.fy) < math.abs(rolling.fy) * 0.5, "and gives up most of its lateral grip")

	-- Load sensitivity.
	t.near(Wheel.loadFactor(cfg, 4000, 4000), 1, 1e-9, "static load is full grip")
	t.near(Wheel.loadFactor(cfg, 8000, 4000), 0.9, 1e-9, "twice the load grips 10% less per newton")
	t.near(Wheel.loadFactor(cfg, 0, 4000), 1.1, 1e-9, "a light tyre grips a little more per newton")

	-- Implicit step: a spinning wheel on the road comes back to rolling, at
	-- a 60 Hz frame with no drive, without overshooting through it.
	local omega = v * 1.5 / r
	for _ = 1, 30 do
		omega = Wheel.step(cfg, axle, omega, v, 0, r, fMax, 1.2, 0, 0, 1 / 60).omega
	end
	t.near(omega * r, v, 0.3, "spin decays to rolling speed")
	-- Even at a 14 fps frame (an unfocused Studio window).
	omega = v * 1.5 / r
	for _ = 1, 10 do
		local step = Wheel.step(cfg, axle, omega, v, 0, r, fMax, 1.2, 0, 0, 1 / 14)
		t.ok(step.omega == step.omega and math.abs(step.omega) < 1000, "stays finite at 14 fps")
		omega = step.omega
	end
	t.near(omega * r, v, 0.5, "and still settles to rolling")

	-- Drive torque past what the tyre can react spins the wheel up.
	local driven = Wheel.step(cfg, axle, v / r, v, 0, r, fMax, 1.2, fMax * 1.5 * r * 2, 0, 0.5)
	t.ok(driven.omega * r > v * 1.05, "excess drive spins the wheel")
	t.ok(driven.fx > 0, "and still pushes forward")

	-- Brakes stop the wheel, never reverse it.
	local braked = Wheel.step(cfg, axle, 5, 0, 0, r, 0, 1.2, 0, 1e5, 1 / 60)
	t.near(braked.omega, 0, 1e-9, "a brake stops the wheel at zero")

	-- longScale (the launch grip) multiplies the drive grip, nothing sideways
	local driving = Wheel.force(cfg, axle, v, 0, v * 1.05 / r, r, fMax)
	local boosted = Wheel.force(cfg, axle, v, 0, v * 1.05 / r, r, fMax, 1.4)
	t.near(boosted.fx, driving.fx * 1.4, 1e-6, "longScale 1.4: 1.4 times the drive force")
	local side = Wheel.force(cfg, axle, v, vLat, v / r, r, fMax, 1.4)
	t.near(side.fy, rolling.fy, 1e-6, "and the same sideways force")
	-- a launch with the boost pulls harder through the step
	local plainStep = Wheel.step(cfg, axle, 10 * 1.05 / r, 10, 0, r, fMax, 1.2, 600, 0, 1 / 60)
	local boostStep = Wheel.step(cfg, axle, 10 * 1.05 / r, 10, 0, r, fMax, 1.2, 600, 0, 1 / 60, 1.4)
	t.ok(boostStep.fx > plainStep.fx, "the step passes longScale through")
	-- ...and only on the drive: a braking wheel grips as it always did
	-- (speed-feel review: it shortened braking on the driven axle)
	local braking = Wheel.force(cfg, axle, v, 0, v * 0.95 / r, r, fMax)
	local brakingBoost = Wheel.force(cfg, axle, v, 0, v * 0.95 / r, r, fMax, 1.4)
	t.near(brakingBoost.fx, braking.fx, 1e-6, "longScale leaves a braking wheel alone")
	local reversing = Wheel.force(cfg, axle, -v, 0, -v * 1.05 / r, r, fMax)
	local reversingBoost = Wheel.force(cfg, axle, -v, 0, -v * 1.05 / r, r, fMax, 1.4)
	t.near(reversingBoost.fx, reversing.fx * 1.4, 1e-6, "driving backwards is drive too")
end
