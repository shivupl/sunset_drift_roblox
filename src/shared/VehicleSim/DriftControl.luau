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
--     throwThrottleHoldFromDeg x gasHoldFromScale. With powerOverThrow above
--     0, the gas and the wheel past powerOverSteer at powerOverMinKmh or more
--     throw the car (permission powerOverThrow, the rear's grip times
--     powerOverRearGrip) until it is sideways enough for the gas hold. The
--     tyres alone never spin up: the rear's drive grip (1.9) is set for the
--     launch, and with traction control aside full lock and gas at 50 km/h
--     still peaked at 1.5 degrees (Play, 2026-10-05).
--
-- None of it acts while the lever is in: the lever's 360, hold and catch
-- are the same on every style. A lift with the lever in drops the gas hold at
-- once, as before the feather, and the lever stops a lift throw it meets
-- (final review, 2026-10-05: a bail-out letting go of the lever and the gas
-- together held the angle for the feather first).
--
-- A lift is the throttle falling under liftTo within liftWindowSeconds of
-- having been at liftFrom or more (liftStep): a gamepad trigger let go by
-- hand passes through the middle over two or three frames, and a one-step
-- edge missed it.
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
	liftFrom: number,
	liftTo: number,
	liftWindowSeconds: number,
	powerOverSteer: number,
	powerOverMinKmh: number,
	powerOverThrow: number,
	powerOverRearGrip: number,
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

-- When the throttle was last up, for spotting a lift (liftStep).
export type Lift = {
	highAge: number, -- seconds since the throttle was at liftFrom or more; huge once a lift has fired
}

export type State = {
	holdOn: boolean, -- the gas is holding a slide
	straight: number, -- seconds under the keep gate with the wheel centred
	feather: number, -- seconds into a feather, -1 for none
	kick: number, -- seconds of kick left
	liftTimer: number, -- seconds of lift throw left
	lift: Lift,
}

export type Input = {
	throttle: number,
	steer: number,
	driftAngleDeg: number,
	speedKmh: number,
	lever: number, -- the handbrake's level, 0..1 (last step's: it arms the gas hold, as it always has)
	leverNow: boolean?, -- the handbrake pressed this step (gates the feather and the lift throw)
	twoWheel: boolean,
}

export type Output = {
	gasHold: boolean,
	feathering: boolean,
	angleRateDeg: number, -- + toward straight; 0 under the lever
	throw: number, -- 0..1 permission from a lift or power throw
	rearGrip: number, -- rear grip multiplier from a lift or power throw, 1 for none
	tractionAside: boolean,
}

function DriftControl.newLift(): Lift
	return { highAge = math.huge }
end

-- Whether this step is a lift: the throttle under `to` within `window`
-- seconds of having been at `from` or more. Fires once per lift. EngineAudio
-- reads its lift bursts and the drift flutter through this too, so the two
-- never disagree on what a lift is.
function DriftControl.liftStep(l: Lift, throttle: number, from: number, to: number, window: number, dt: number): boolean
	if throttle >= from then
		l.highAge = 0
		return false
	end
	l.highAge += dt
	if throttle < to and l.highAge <= window + 1e-9 then
		l.highAge = math.huge
		return true
	end
	return false
end

function DriftControl.new(): State
	return { holdOn = false, straight = 0, feather = -1, kick = 0, liftTimer = 0, lift = DriftControl.newLift() }
end

function DriftControl.reset(s: State)
	s.holdOn = false
	s.straight = 0
	s.feather = -1
	s.kick = 0
	s.liftTimer = 0
	s.lift = DriftControl.newLift()
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

	-- The lever in, now or last step: nothing of a lift acts.
	local leverIn = inp.lever > 0 or inp.leverNow == true

	-- The lift throw, read off the lift before the hold logic.
	local lifted = DriftControl.liftStep(s.lift, inp.throttle, cfg.liftFrom, cfg.liftTo, cfg.liftWindowSeconds, dt)
	if
		cfg.liftThrow > 0
		and lifted
		and not inp.twoWheel
		and not leverIn
		and inp.speedKmh >= cfg.liftThrowMinKmh
		and math.abs(inp.steer) >= cfg.liftThrowSteer
		and not sidewaysNow
	then
		s.liftTimer = cfg.liftThrowSeconds
	end
	if leverIn then
		s.liftTimer = 0
		s.kick = 0
		s.feather = -1
	end

	if not gasOn then
		-- A lift. Inside featherSeconds of a held slide, lever out, it is a
		-- feather.
		if s.holdOn and not inp.twoWheel and not leverIn then
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
		if s.feather >= 0 and s.holdOn and not leverIn then
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
	if s.holdOn and not leverIn then
		if feathering then
			rate += cfg.featherDegPerSec
		end
		if s.kick > 0 and cfg.kickSeconds > 0 then
			rate -= cfg.kickDeg / cfg.kickSeconds
		end
		rate += cfg.holdDecayDegPerSec
		-- Under the band it grows, even swinging through straight in a
		-- transition (a held chain in a high-angle style otherwise dropped
		-- its hold at the straight moment, 2026-10-05); dead straight has no
		-- side to grow on.
		if a >= 1 and a < cfg.holdMinDeg then
			rate = math.min(rate, -cfg.holdEaseDegPerSec)
		elseif a > cfg.holdMaxDeg then
			rate = math.max(rate, cfg.holdEaseDegPerSec)
		end
	end
	s.kick = math.max(0, s.kick - dt)

	local lifting = s.liftTimer > 0
	s.liftTimer = math.max(0, s.liftTimer - dt)
	local powering = cfg.powerOverThrow > 0
		and gasOn
		and inp.lever <= 0
		and not s.holdOn
		and math.abs(inp.steer) >= cfg.powerOverSteer
		and inp.speedKmh >= cfg.powerOverMinKmh
	return {
		gasHold = s.holdOn,
		feathering = feathering,
		angleRateDeg = rate,
		throw = math.max(if lifting then cfg.liftThrow else 0, if powering then cfg.powerOverThrow else 0),
		rearGrip = (if lifting then cfg.liftThrowRearGrip else 1) * (if powering then cfg.powerOverRearGrip else 1),
		tractionAside = math.abs(inp.steer) >= cfg.powerOverSteer,
	}
end

return DriftControl
