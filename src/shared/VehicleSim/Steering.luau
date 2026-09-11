--!strict
-- Speed-sensitive steering lock. Pure: no Roblox instances.
--
-- A heavy sedan at highway speed does not need, and cannot use, the lock it
-- needs to park. Handing the player full lock at 150 km/h means a flick of
-- the wheel pitches the car sideways on its own, which reads as the car
-- drifting without being asked. The curve tapers the available lock with
-- speed instead of gating drift behind the handbrake.
--
-- The taper has one exception. Steering toward the direction the car is
-- already travelling is a correction, not a request for more angle, so the
-- taper lifts as the slip angle grows. Without that exception a car tapered
-- to a third of its lock could not physically catch a big slide, and
-- holding a drift would stop working at exactly the speeds it matters.
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
}

-- Fraction of maxSteerDeg available right now, 0..1.
-- slipAngleDeg is the car's own slip: + = velocity to the right of the nose,
-- so a correction is steer input of the same sign.
function Steering.lockFactor(cfg: Config, speedKmh: number, steerInput: number, slipAngleDeg: number): number
	local base = math.clamp(Curve.lookup(cfg.speedLockCurve, speedKmh), 0, 1)
	if base >= 1 or cfg.counterSteerReliefDeg <= 0 then
		return base
	end
	if steerInput * slipAngleDeg > 0 then
		local relief = math.clamp(math.abs(slipAngleDeg) / cfg.counterSteerReliefDeg, 0, 1) * cfg.counterSteerRelief
		return base + (1 - base) * math.clamp(relief, 0, 1)
	end
	return base
end

return Steering
