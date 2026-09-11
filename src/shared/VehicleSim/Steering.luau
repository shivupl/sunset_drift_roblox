--!strict
-- Speed-sensitive steering lock. Pure: no Roblox instances.
--
-- A heavy sedan at highway speed does not need, and cannot use, the lock it
-- needs to park. Handing the player full lock at 150 km/h means a flick of
-- the wheel pitches the car sideways on its own, which reads as the car
-- drifting without being asked. The curve tapers the available lock with
-- speed instead of gating drift behind the handbrake.
--
-- The taper has two exceptions. Steering toward the direction the car is
-- already travelling is a correction, not a request for more angle, so the
-- taper lifts as the slip angle grows. Without that exception a car tapered
-- to a third of its lock could not physically catch a big slide. And a
-- handbrake pull is an explicit throw, so the taper lifts
-- for that window too: a Ta'geed at 160 km/h needs the wheel the driver
-- actually turned, not a third of it.
local Curve = require(script.Parent.Parent.Curve)

local Steering = {}

export type Config = {
	maxSteerDeg: number,
	steerSpeedDegPerSec: number,
	steerReturnDegPerSec: number,
	driftAssist: number,
	speedLockCurve: Curve.Points,
	counterSteerReliefDeg: number,
	counterSteerRelief: number,
	throwRelief: number,
	flickFromLock: number,
	flickWindowSeconds: number,
	flickRelief: number,
	flickRearGripMultiplier: number,
	flickGripSeconds: number,
	throwYawRateDegPerSec: number,
	throwYawGain: number,
	throwYawMaxTorque: number,
	throwPathFilterSeconds: number,
	throwHoldGain: number,
	throwHoldMaxTorque: number,
	throwHoldSettleDegPerSec: number,
	throwMinSpeedKmh: number,
	throwFullSpeedKmh: number,
	throwFinishAuthority: number,
	throwFinishFromDeg: number,
	throwFinishCarryDeg: number,
	throwThrottleHold: number,
	throwThrottleHoldFromDeg: number,
	throwThrottleHoldGraceSeconds: number,
	throwThrottleHoldKeepDeg: number,
	slideYawDamping: number,
}

-- Fraction of maxSteerDeg available right now, 0..1.
-- slipAngleDeg is the car's own slip: + = velocity to the right of the nose,
-- so a correction is steer input of the same sign. throw is 0..1: how much
-- the driver is deliberately throwing the car (handbrake level).
function Steering.lockFactor(cfg: Config, speedKmh: number, steerInput: number, slipAngleDeg: number, throw: number): number
	local base = math.clamp(Curve.lookup(cfg.speedLockCurve, speedKmh), 0, 1)
	if base >= 1 then
		return base
	end
	local relief = 0
	if cfg.counterSteerReliefDeg > 0 and steerInput * slipAngleDeg > 0 then
		relief = math.clamp(math.abs(slipAngleDeg) / cfg.counterSteerReliefDeg, 0, 1) * cfg.counterSteerRelief
	end
	relief = math.max(relief, math.clamp(throw, 0, 1) * cfg.throwRelief)
	return base + (1 - base) * math.clamp(relief, 0, 1)
end

return Steering
