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
--   * Part throttle (the drift overhaul, 2026-10-05). A trigger held over
--     keepThrottle keeps an armed hold, tightening it toward straight by up
--     to partialDegPerSec the further it is off full gas: more gas, more
--     angle, the way a real slide is balanced on the throttle (Hindiyeh and
--     Gerdes). A key is 0 or 1, so this is the gamepad's; the keyboard's
--     throttle is the feather and the kick. Arming still takes the gate.
--   * The kick's drive. The stab after a feather pushes the driven wheels
--     kickDriveScale times as hard for kickSeconds: the clutch dumped, a
--     burst of wheelspin, revs and smoke under the kick's angle.
--   * The clutch-kick entry (kickThrow): on the gas with the wheel turned,
--     before the car is sideways, a lift and the gas back inside
--     featherSeconds throws it, with the drive surging.
--   * The brake entry (brakeThrow): the brake pressed with the wheel turned
--     at speed, before the car is sideways, throws it once per press: the
--     braking drift's weight transfer, and front drive's left-foot brake.
--   * The pivot (brakeGrowDegPerSec): brake and gas together in a held
--     slide grow the angle, the rears dragging while the fronts pull
--     (left-foot braking).
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
	keepThrottle: number,
	partialDegPerSec: number,
	kickDriveScale: number,
	kickThrow: number,
	kickThrowSeconds: number,
	kickThrowMinKmh: number,
	kickThrowSteer: number,
	kickThrowRearGrip: number,
	brakeThrow: number,
	brakeThrowSeconds: number,
	brakeThrowMinKmh: number,
	brakeThrowSteer: number,
	brakeThrowRearGrip: number,
	brakeThrowFrom: number,
	brakeGrowDegPerSec: number,
	brakeGrowBrakeScale: number,
	powerOverMaxKmh: number,
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
	gasWasOn: boolean, -- last step's gas, for spotting the stab
	offAge: number, -- seconds the gas has been off after being on, -1 when it never was
	kickTimer: number, -- seconds of clutch-kick throw left
	brakeWas: boolean, -- last step's brake, past brakeThrowFrom
	brakeTimer: number, -- seconds of brake throw left
}

export type Input = {
	throttle: number,
	steer: number,
	driftAngleDeg: number,
	speedKmh: number,
	lever: number, -- the handbrake's level, 0..1 (last step's: it arms the gas hold, as it always has)
	leverNow: boolean?, -- the handbrake pressed this step (gates the feather and the lift throw)
	twoWheel: boolean,
	brake: number?, -- the brake pedal, 0..1; nil is 0
}

export type Output = {
	gasHold: boolean,
	feathering: boolean,
	angleRateDeg: number, -- + toward straight; 0 under the lever
	throw: number, -- 0..1 permission from a lift or power throw
	rearGrip: number, -- rear grip multiplier from a lift or power throw, 1 for none
	tractionAside: boolean,
	driveScale: number, -- the driven wheels' drive multiplier (the kick's surge), 1 for none
	brakeScale: number, -- the brake pedal's multiplier (a pivot's light foot), 1 for none
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
	return {
		holdOn = false,
		straight = 0,
		feather = -1,
		kick = 0,
		liftTimer = 0,
		lift = DriftControl.newLift(),
		gasWasOn = false,
		offAge = -1,
		kickTimer = 0,
		brakeWas = false,
		brakeTimer = 0,
	}
end

function DriftControl.reset(s: State)
	s.holdOn = false
	s.straight = 0
	s.feather = -1
	s.kick = 0
	s.liftTimer = 0
	s.lift = DriftControl.newLift()
	s.gasWasOn = false
	s.offAge = -1
	s.kickTimer = 0
	s.brakeWas = false
	s.brakeTimer = 0
end

function DriftControl.step(s: State, cfg: Config, g: SteeringGates, inp: Input, dt: number): Output
	local a = math.abs(inp.driftAngleDeg)
	local gasOn = not inp.twoWheel and inp.throttle >= g.throwThrottleHold
	-- An armed hold stays on part throttle over keepThrottle (a trigger).
	local keep = math.min(cfg.keepThrottle, g.throwThrottleHold)
	local gasKeeps = not inp.twoWheel and inp.throttle >= keep
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
	-- The clutch-kick entry: the gas back on inside featherSeconds of a
	-- lift, with the wheel turned at speed, before the car is sideways.
	local stabbed = gasOn and not s.gasWasOn and s.offAge >= 0 and s.offAge <= cfg.featherSeconds
	if
		cfg.kickThrow > 0
		and stabbed
		and not s.holdOn
		and not leverIn
		and inp.speedKmh >= cfg.kickThrowMinKmh
		and math.abs(inp.steer) >= cfg.kickThrowSteer
		and not sidewaysNow
	then
		s.kickTimer = cfg.kickThrowSeconds
		s.kick = cfg.kickSeconds -- the surge rides with it
	end
	if gasOn then
		s.offAge = -1
	elseif s.gasWasOn then
		s.offAge = 0
	elseif s.offAge >= 0 then
		s.offAge += dt
	end
	s.gasWasOn = gasOn

	-- The brake entry: the brake's press with the wheel turned at speed.
	local braking = (inp.brake or 0) >= cfg.brakeThrowFrom
	if
		cfg.brakeThrow > 0
		and braking
		and not s.brakeWas
		and not inp.twoWheel
		and not leverIn
		and inp.speedKmh >= cfg.brakeThrowMinKmh
		and math.abs(inp.steer) >= cfg.brakeThrowSteer
		and not sidewaysNow
	then
		s.brakeTimer = cfg.brakeThrowSeconds
	end
	s.brakeWas = braking

	if leverIn then
		s.liftTimer = 0
		s.kick = 0
		s.feather = -1
		s.kickTimer = 0
		s.brakeTimer = 0
	end

	if s.holdOn and gasKeeps and not gasOn and not leverIn then
		-- Part throttle over keepThrottle: still held, no feather.
		s.feather = -1
	elseif not gasOn then
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

	-- The pivot: brake and gas together on a held slide.
	local pivoting = cfg.brakeGrowDegPerSec > 0 and braking and gasOn and s.holdOn and not leverIn

	local rate = 0
	if s.holdOn and not leverIn then
		if feathering then
			rate += cfg.featherDegPerSec
		elseif not gasOn and cfg.partialDegPerSec ~= 0 then
			-- Part throttle: tighter the further off full gas.
			rate += cfg.partialDegPerSec * math.clamp((1 - inp.throttle) / math.max(1 - keep, 1e-3), 0, 1)
		end
		if s.kick > 0 and cfg.kickSeconds > 0 then
			rate -= cfg.kickDeg / cfg.kickSeconds
		end
		rate += cfg.holdDecayDegPerSec
		if pivoting then
			rate -= cfg.brakeGrowDegPerSec
		end
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
	local surging = s.kick > 0
	s.kick = math.max(0, s.kick - dt)

	local lifting = s.liftTimer > 0
	s.liftTimer = math.max(0, s.liftTimer - dt)
	local kicking = s.kickTimer > 0
	s.kickTimer = math.max(0, s.kickTimer - dt)
	local brakeThrowing = s.brakeTimer > 0
	s.brakeTimer = math.max(0, s.brakeTimer - dt)
	local powering = cfg.powerOverThrow > 0
		and gasOn
		and inp.lever <= 0
		and not s.holdOn
		and math.abs(inp.steer) >= cfg.powerOverSteer
		and inp.speedKmh >= cfg.powerOverMinKmh
		and inp.speedKmh <= cfg.powerOverMaxKmh
	return {
		gasHold = s.holdOn,
		feathering = feathering,
		angleRateDeg = rate,
		throw = math.max(
			if lifting then cfg.liftThrow else 0,
			if powering then cfg.powerOverThrow else 0,
			if kicking then cfg.kickThrow else 0,
			if brakeThrowing then cfg.brakeThrow else 0
		),
		rearGrip = (if lifting then cfg.liftThrowRearGrip else 1)
			* (if powering then cfg.powerOverRearGrip else 1)
			* (if kicking then cfg.kickThrowRearGrip else 1)
			* (if brakeThrowing then cfg.brakeThrowRearGrip else 1),
		tractionAside = math.abs(inp.steer) >= cfg.powerOverSteer,
		driveScale = if surging then cfg.kickDriveScale else 1,
		brakeScale = if pivoting then cfg.brakeGrowBrakeScale else 1,
	}
end

return DriftControl
