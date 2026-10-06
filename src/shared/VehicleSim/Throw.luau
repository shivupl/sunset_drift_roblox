--!strict
-- The throw controller. Pure: no Roblox instances.
--
-- The tyre model on its own cannot do a hajwala 360: the fronts have to
-- build slip before they push, both axles lose their yaw stiffness once they
-- slide, and past 90 degrees the steered fronts fight the rotation, so a
-- held lever from 110 km/h stalled at 180 going backwards. A real Ta'geed
-- gets its rotation from the locked rears scrubbing and the driver's
-- throttle, neither of which the friction circle produces. So while the
-- driver has a permission in (the lever, the gas once sideways, or the flick
-- window) the rate the drift angle changes is steered toward a target: the
-- wheel's direction times throwYawRateDegPerSec, scaled by how far the wheel
-- is turned, on top of the rate the path itself is turning. Full lock comes
-- round for a 360, centred holds whatever angle the car has, counter-steered
-- brings it back. A rate target cannot run away, which is what keeps this
-- off ice. With no permission the output is plain yaw damping, standing in
-- for the rear's self-aligning.
--
-- Two exceptions past an angle. With a permission in, past 90 degrees the
-- speed fade is lifted to throwFinishAuthority so a spin that has run out of
-- speed finishes instead of stalling backwards. Hands off (no permission,
-- wheel centred) past throwFinishFromDeg the same authority brings the car
-- back the short way, or on round if it is past throwFinishCarryDeg and
-- still rotating.
--
-- Sign convention: yaw + = turning right (clockwise from above). Drift + =
-- velocity to the right of the nose, so yawing right takes the drift angle
-- down. The returned torque is in the yaw-right sense; the caller applies
-- it as `totalTorque -= up * torque`.
local Steering = require(script.Parent.Steering)

local Throw = {}

export type Config = Steering.Config

export type State = {
	holdAngleDeg: number, -- drift angle held with the wheel centred
	holdLatched: boolean, -- that angle is fixed (the turn-in's momentum has settled)
}

export type Input = {
	steer: number, -- -1..1
	permission: number, -- 0..1: the lever's level, or 1 for the gas hold
	flick: boolean, -- inside the flick window
	driftAngleDeg: number,
	yawRateDeg: number,
	pathRateDeg: number, -- rate the velocity direction is turning, same sign
	speedKmh: number,
	-- Moves the held angle (DriftControl: the feather, the kick, a style's
	-- decay and band), deg/s, + toward straight on either side. With the
	-- wheel turned it adds to the rate target instead. Optional; nil is 0.
	angleRateDeg: number?,
	dt: number?, -- the step, for moving the held angle
	-- Steering into the slide adds no angle past this (fading in over the
	-- last 10 degrees); counter-steer and angleRateDeg are untouched. The
	-- ceiling (drift.dialMaxDeg) on any slide without the lever or a flick:
	-- one steered into goes wider up to it and is aimed by the line from
	-- there, where it used to spin (the owner, 2026-10-05: drifting kept
	-- "within the highway boundries"). nil: no ceiling, as under the lever.
	intoMaxDeg: number?,
	-- Steering into the slide turns the angle at this share of the rate;
	-- counter-steer keeps the whole of it, so a transition swings through at
	-- full speed (countersteer faster than steer-in, art of rally; research
	-- 2026-10-05). nil is 1.
	intoScale: number?,
}

function Throw.new(): State
	return { holdAngleDeg = 0, holdLatched = false }
end

-- Fraction of authority at this speed, before the finish rule.
function Throw.speedFactor(cfg: Config, speedKmh: number): number
	return math.clamp((speedKmh - cfg.throwMinSpeedKmh) / math.max(cfg.throwFullSpeedKmh - cfg.throwMinSpeedKmh, 1), 0, 1)
end

function Throw.step(state: State, cfg: Config, inp: Input): number
	local handsOff = inp.permission <= 0 and math.abs(inp.steer) <= 0.05
	local finishFrom = if handsOff then cfg.throwFinishFromDeg else 90
	local finishing = math.abs(inp.driftAngleDeg) > finishFrom and inp.speedKmh > cfg.throwMinSpeedKmh
	local level = math.max(inp.permission, if inp.flick or finishing then 1 else 0)
	if level <= 0 then
		state.holdLatched = false
		return -cfg.slideYawDamping * inp.yawRateDeg
	end

	local speedFactor = Throw.speedFactor(cfg, inp.speedKmh)
	if finishing then
		speedFactor = math.max(speedFactor, cfg.throwFinishAuthority)
	end
	local driftRateNow = inp.yawRateDeg - inp.pathRateDeg
	local driftRate = 0
	local cap = cfg.throwYawMaxTorque
	if finishing and handsOff then
		-- Short way back, unless nearly backwards and still rotating.
		-- Keeping the rotation below that carried a 60-degree bail the long
		-- way through 180.
		local s = math.sign(inp.driftAngleDeg)
		if math.abs(inp.driftAngleDeg) > cfg.throwFinishCarryDeg and math.abs(inp.yawRateDeg) > cfg.throwHoldSettleDegPerSec then
			s = math.sign(inp.yawRateDeg)
		end
		driftRate = s * cfg.throwYawRateDegPerSec * cfg.throwFinishAuthority
		state.holdLatched = false
	elseif math.abs(inp.steer) > 0.05 then
		local dial = inp.steer * cfg.throwYawRateDegPerSec
		if inp.steer * inp.driftAngleDeg < 0 then
			dial *= inp.intoScale or 1
			if inp.intoMaxDeg then
				dial *= math.clamp((inp.intoMaxDeg - math.abs(inp.driftAngleDeg)) / 10, 0, 1)
			end
		end
		driftRate = dial + math.sign(inp.driftAngleDeg) * (inp.angleRateDeg or 0)
		state.holdLatched = false
	else
		-- Wheel centred: hold the angle. The hold tracks the drift until
		-- the turn-in's momentum has settled, then latches; from there a
		-- rate proportional to the error keeps it. A rate target alone let
		-- the angle creep at 13 deg/s from the tyres' own moment. The catch
		-- gets a higher cap than the onset so that momentum is absorbed in
		-- a couple of tenths.
		cap = cfg.throwHoldMaxTorque
		if not state.holdLatched then
			state.holdAngleDeg = inp.driftAngleDeg
			if math.abs(driftRateNow) < cfg.throwHoldSettleDegPerSec then
				state.holdLatched = true
			end
		else
			-- The pedals move the held angle (DriftControl), never through
			-- straight and never past 179.
			local rate = inp.angleRateDeg or 0
			local h = state.holdAngleDeg
			if rate ~= 0 and h ~= 0 then
				local mag = math.max(0, math.abs(h) - rate * (inp.dt or 0))
				state.holdAngleDeg = math.sign(h) * math.min(mag, 179)
			end
			local err = state.holdAngleDeg - inp.driftAngleDeg
			if err > 180 then
				err -= 360
			elseif err < -180 then
				err += 360
			end
			-- A positive error (want more drift) needs negative yaw.
			driftRate = math.clamp(-cfg.throwHoldGain * err, -cfg.throwYawRateDegPerSec, cfg.throwYawRateDegPerSec)
		end
	end
	local target = inp.pathRateDeg + driftRate
	local torque = math.clamp(cfg.throwYawGain * (target - inp.yawRateDeg), -cap, cap)
	return torque * level * speedFactor
end

return Throw
