--!strict
local Steering = require(script.Parent.Parent.VehicleSim.Steering)
local Tests = require(script.Parent)
type T = Tests.T

return function(t: T)
	local cfg = {
		maxSteerDeg = 38,
		steerSpeedDegPerSec = 180,
		steerReturnDegPerSec = 360,
		driftAssist = 0.15,
		speedLockCurve = { { 0, 1 }, { 40, 1 }, { 90, 0.6 }, { 150, 0.35 }, { 260, 0.35 } },
		counterSteerReliefDeg = 25,
		counterSteerRelief = 1,
		throwRelief = 1,
		flickFromLock = 0.5,
		flickWindowSeconds = 0.45,
		flickRelief = 1,
		flickRearGripMultiplier = 0.45,
		flickGripSeconds = 0.35,
		throwYawRateDegPerSec = 150,
		throwYawGain = 250,
		throwYawMaxTorque = 16000,
		throwPathFilterSeconds = 0.05,
		throwHoldGain = 3,
		throwHoldMaxTorque = 32000,
		throwHoldSettleDegPerSec = 25,
		throwMinSpeedKmh = 30,
		throwFullSpeedKmh = 70,
		slideYawDamping = 130,
	}

	-- Straight-line driving: full lock up to 40 km/h, then tapering
	t.near(Steering.lockFactor(cfg, 0, 1, 0, 0), 1, 1e-9, "full lock at rest")
	t.near(Steering.lockFactor(cfg, 40, 1, 0, 0), 1, 1e-9, "full lock at 40")
	t.near(Steering.lockFactor(cfg, 65, 1, 0, 0), 0.8, 1e-9, "tapering by 65")
	t.near(Steering.lockFactor(cfg, 90, 1, 0, 0), 0.6, 1e-9, "0.6 at 90")
	t.near(Steering.lockFactor(cfg, 150, 1, 0, 0), 0.35, 1e-9, "0.35 at 150")
	t.near(Steering.lockFactor(cfg, 300, 1, 0, 0), 0.35, 1e-9, "clamps past the last knot")

	-- Turning into a corner at speed stays tapered
	t.near(Steering.lockFactor(cfg, 150, 1, -5, 0), 0.35, 1e-9, "steering away from the slide stays tapered")
	t.near(Steering.lockFactor(cfg, 150, -1, 0, 0), 0.35, 1e-9, "no slip, no relief")

	-- Catching a slide lifts the taper in proportion to the slip angle
	local half = Steering.lockFactor(cfg, 150, 1, 12.5, 0)
	t.near(half, 0.35 + 0.65 * 0.5, 1e-6, "half relief at half the relief angle")
	t.near(Steering.lockFactor(cfg, 150, 1, 25, 0), 1, 1e-9, "full wheel back at the relief angle")
	t.near(Steering.lockFactor(cfg, 150, 1, 80, 0), 1, 1e-9, "and beyond it")
	t.near(Steering.lockFactor(cfg, 150, -1, -40, 0), 1, 1e-9, "symmetric the other way")

	-- Relief is opt-out
	local noRelief = table.clone(cfg)
	noRelief.counterSteerRelief = 0
	t.near(Steering.lockFactor(noRelief, 150, 1, 40, 0), 0.35, 1e-9, "relief 0 disables the lift")
	local offRelief = table.clone(cfg)
	offRelief.counterSteerReliefDeg = 0
	t.near(Steering.lockFactor(offRelief, 150, 1, 40, 0), 0.35, 1e-9, "relief angle 0 disables the lift")

	-- A throw (the handbrake) lifts the taper regardless of direction
	t.near(Steering.lockFactor(cfg, 150, 1, 0, 1), 1, 1e-9, "full throw gives the whole wheel")
	t.near(Steering.lockFactor(cfg, 150, -1, 5, 0.5), 0.35 + 0.65 * 0.5, 1e-6, "half throw lifts half the taper")
	local noThrow = table.clone(cfg)
	noThrow.throwRelief = 0
	t.near(Steering.lockFactor(noThrow, 150, 1, 0, 1), 0.35, 1e-9, "throwRelief 0 keeps the taper")

	-- Below the taper the relief is irrelevant
	t.near(Steering.lockFactor(cfg, 10, 1, 60, 0), 1, 1e-9, "already full lock at low speed")
end
